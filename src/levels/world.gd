extends Node2D

const TREE_SCENE := preload("res://assets/terrain/tree/tree.tscn")
const MINERAL_SCENE := preload("res://assets/terrain/mineral/mineral.tscn")

const TILESET := preload("res://assets/textures/tiles/tileset.png")
const TILE_PX := 32
const SHEET_TILES := Vector2i(10, 5)
const LIGHT_COLOR := Color(34 / 255.0, 32 / 255.0, 52 / 255.0)
const DARK_PLAIN := Vector2i(7, 2)
const DARK_SPECKS := Vector2i(6, 3)
const WORLD_EDGE_BLOCK := Vector2i(5, 0)
const LIGHT_PLAIN: Array[Vector2i] = [Vector2i(2, 3), Vector2i(3, 3)]
const LIGHT_DECOR: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(1, 3),
]
const SIDE_LIPS := {
	Vector2i.RIGHT: [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)],
	Vector2i.LEFT: [Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)],
	Vector2i.DOWN: [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
	Vector2i.UP: [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)],
}
const CORNER_LIPS := {
	Vector2i(1, 1): Vector2i(0, 0),
	Vector2i(-1, 1): Vector2i(4, 0),
	Vector2i(1, -1): Vector2i(0, 4),
	Vector2i(-1, -1): Vector2i(4, 4),
}

@export var map_tiles := Vector2i(36, 20)
@export var ground_scale := 4.0
@export var cluster_radius := 160.0
@export var member_spacing := 90.0
@export var townhall_clearing := 300.0
@export var edge_margin := 64.0

#how trees spawn
@export_group("Trees")
@export var tree_clusters := 40
@export var tree_cluster_sizes: Array[int] = [1, 1, 1, 2, 2, 3, 5]
@export var tree_cluster_spacing := 450.0

#edit here to adjust the size of diff patches
@export_group("Ground Patches")
@export var blob_frequency := 0.08
@export var light_amount := 0.05
@export var puddle_chance := 0.04
@export var town_radius := 3.0
@export var decor_chance := 0.3
@export var specks_chance := 0.05

#how mineralz spawn, same as trees but different values
@export_group("Minerals")
@export var mineral_clusters := 8
@export var mineral_cluster_sizes: Array[int] = [1, 1, 2, 3]
@export var mineral_cluster_spacing := 900.0
@export_group("")

var map_size: Vector2
var light := {}
var sheet: Image
var lip_images := {}
var units = []
var cluster_centers: Array[Vector2] = []

func _ready() -> void:
	Global.reset()
	generate_map()
	get_units()

func generate_map():
	var tile_size := TILE_PX * ground_scale
	map_size = Vector2(map_tiles) * tile_size

	var center := map_size / 2

	$Ground.scale = Vector2.ONE * ground_scale
	generate_light()
	paint_ground()

	$Camera.limit_left = int(-tile_size)
	$Camera.limit_top = int(-tile_size)
	$Camera.limit_right = int(map_size.x + tile_size)
	$Camera.limit_bottom = int(map_size.y + tile_size)
	$Camera.position = center

	$Houses/Townhall.position = center
	for unit in $Units.get_children():
		unit.position = center + Vector2(randf_range(-150, 150), 150)

	cluster_centers.clear()
	scatter_resource(MINERAL_SCENE, mineral_clusters, mineral_cluster_sizes, mineral_cluster_spacing, center)
	scatter_resource(TREE_SCENE, tree_clusters, tree_cluster_sizes, tree_cluster_spacing, center)

func generate_light():
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = blob_frequency
	var middle := Vector2(map_tiles) / 2
	light.clear()
	for x in map_tiles.x:
		for y in map_tiles.y:
			var cell := Vector2i(x, y)
			var inside := x > 0 and y > 0 and x < map_tiles.x - 1 and y < map_tiles.y - 1
			var near_town := (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(middle) < town_radius
			light[cell] = near_town or (inside and noise.get_noise_2dv(Vector2(cell)) > -light_amount)

	var puddles: Array[Vector2i] = []
	for cell in light:
		if randf() < puddle_chance and surrounded_by_light(cell):
			puddles.append(cell)
	for cell in puddles:
		light[cell] = false

func surrounded_by_light(cell: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if not is_light(cell + Vector2i(dx, dy)):
				return false
	return true

func is_light(cell: Vector2i) -> bool:
	return light.get(cell, false)

func paint_ground():
	sheet = TILESET.get_image()
	sheet.convert(Image.FORMAT_RGBA8)

	var dark_tiles := {}
	var dark_cells := {}
	for cell in light:
		if not light[cell]:
			var layers := dark_layers(cell)
			var key := str(layers)
			if not dark_tiles.has(key):
				dark_tiles[key] = compose(layers)
			dark_cells[cell] = key

	var keys := dark_tiles.keys()
	var columns := 16
	var rows := maxi(1, ceili(keys.size() / float(columns)))
	var atlas := Image.create_empty(columns * TILE_PX, rows * TILE_PX, false, Image.FORMAT_RGBA8)
	var atlas_coords := {}
	for i in keys.size():
		@warning_ignore("integer_division")
		var coords := Vector2i(i % columns, i / columns)
		atlas.blit_rect(dark_tiles[keys[i]], Rect2i(0, 0, TILE_PX, TILE_PX), coords * TILE_PX)
		atlas_coords[keys[i]] = coords

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_PX, TILE_PX)
	tile_set.add_source(make_source(TILESET, SHEET_TILES), 0)
	tile_set.add_source(make_source(ImageTexture.create_from_image(atlas), Vector2i(columns, rows)), 1)
	$Ground.tile_set = tile_set

	$Ground.clear()
	for cell in light:
		if light[cell]:
			var tile: Vector2i = LIGHT_DECOR.pick_random() if randf() < decor_chance else LIGHT_PLAIN.pick_random()
			$Ground.set_cell(cell, 0, tile)
		else:
			$Ground.set_cell(cell, 1, atlas_coords[dark_cells[cell]])
	paint_frame(Rect2i(Vector2i.ZERO, map_tiles), WORLD_EDGE_BLOCK)

func dark_layers(cell: Vector2i) -> Array[Vector2i]:
	var layers: Array[Vector2i] = [DARK_SPECKS if randf() < specks_chance else DARK_PLAIN]
	for side in SIDE_LIPS:
		if is_light(cell + side):
			layers.append(SIDE_LIPS[side].pick_random())
	for corner in CORNER_LIPS:
		if is_light(cell + corner) and not is_light(cell + Vector2i(corner.x, 0)) and not is_light(cell + Vector2i(0, corner.y)):
			layers.append(CORNER_LIPS[corner])
	return layers

func compose(layers: Array[Vector2i]) -> Image:
	var image := sheet.get_region(Rect2i(layers[0] * TILE_PX, Vector2i(TILE_PX, TILE_PX)))
	for i in range(1, layers.size()):
		image.blend_rect(lip_image(layers[i]), Rect2i(0, 0, TILE_PX, TILE_PX), Vector2i.ZERO)
	return image

func lip_image(coords: Vector2i) -> Image:
	if not lip_images.has(coords):
		var lip := Image.create_empty(TILE_PX, TILE_PX, false, Image.FORMAT_RGBA8)
		for x in TILE_PX:
			for y in TILE_PX:
				var color := sheet.get_pixel(coords.x * TILE_PX + x, coords.y * TILE_PX + y)
				if color.is_equal_approx(LIGHT_COLOR):
					lip.set_pixel(x, y, color)
		lip_images[coords] = lip
	return lip_images[coords]

func make_source(texture: Texture2D, tile_count: Vector2i) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	for x in tile_count.x:
		for y in tile_count.y:
			source.create_tile(Vector2i(x, y))
	return source

func paint_frame(core: Rect2i, block: Vector2i):
	var left := core.position.x - 1
	var top := core.position.y - 1
	var right := core.end.x
	var bottom := core.end.y
	for x in range(core.position.x, right):
		var col := edge_tile(x - core.position.x, core.size.x)
		$Ground.set_cell(Vector2i(x, top), 0, block + Vector2i(col, 0))
		$Ground.set_cell(Vector2i(x, bottom), 0, block + Vector2i(col, 4))
	for y in range(core.position.y, bottom):
		var row := edge_tile(y - core.position.y, core.size.y)
		$Ground.set_cell(Vector2i(left, y), 0, block + Vector2i(0, row))
		$Ground.set_cell(Vector2i(right, y), 0, block + Vector2i(4, row))
	$Ground.set_cell(Vector2i(left, top), 0, block + Vector2i(0, 0))
	$Ground.set_cell(Vector2i(right, top), 0, block + Vector2i(4, 0))
	$Ground.set_cell(Vector2i(left, bottom), 0, block + Vector2i(0, 4))
	$Ground.set_cell(Vector2i(right, bottom), 0, block + Vector2i(4, 4))

func edge_tile(i: int, length: int) -> int:
	if i == 0:
		return 1
	if i == length - 1:
		return 3
	return randi_range(1, 3)


# resources - scatter them around and spawns them by cluster or not
func scatter_resource(scene: PackedScene, count: int, sizes: Array[int], spacing: float, center: Vector2):
	var margin := edge_margin + cluster_radius
	var placed := 0
	for attempt in count * 30:
		if placed == count:
			return
		var pos := Vector2(randf_range(margin, map_size.x - margin), randf_range(margin, map_size.y - margin))
		if pos.distance_to(center) < townhall_clearing + cluster_radius:
			continue
		if cluster_centers.any(func(c): return c.distance_to(pos) < spacing):
			continue
		cluster_centers.append(pos)
		spawn_cluster(scene, pos, sizes.pick_random())
		placed += 1

func spawn_cluster(scene: PackedScene, cluster_center: Vector2, size: int):
	spawn(scene, cluster_center)
	var start_angle := randf() * TAU
	for i in size - 1:
		var angle := start_angle + i * TAU / (size - 1)
		spawn(scene, cluster_center + Vector2.from_angle(angle) * randf_range(member_spacing, cluster_radius))

func spawn(scene: PackedScene, pos: Vector2):
	var node := scene.instantiate()
	node.position = pos
	$Objects.add_child(node)

func get_units():
	units = null
	units = get_tree().get_nodes_in_group("unit")
	
func _on_camera_area_selected(object) -> void:
	var start = object.start
	var end = object.end
	var area = []
	area.append(Vector2(min(start.x, end.x), min (start.y, end.y)))
	area.append(Vector2(max(start.x, end.x), max(start.y, end.y)))
	var ut = get_units_in_area(area)
	for u in units:
		u.set_selected(false)
	for u in ut:
		u.set_selected(!u.selected)

func get_units_in_area(area):
	var u = []
	for unit in units:
		if (unit.position.x > area[0].x) and (unit.position.x < area[1].x):
			if (unit.position.y > area[0].y) and (unit.position.y < area[1].y):
				u.append(unit)
	return u
