extends Node2D

const TILESET := preload("res://assets/textures/tiles/tileset.png")
const TEST_ENEMY := preload("res://data/stats/troops/swordsman.tres")
const TILE_PX := 32
const DARK := 0
const MEDIUM := 1
const LIGHT := 2
const SHADE_ROW := {DARK: 8, MEDIUM: 4, LIGHT: 0}
const PLAIN: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
const DECOR: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(0, 3), Vector2i(1, 3),
]
const WATER_PUDDLES: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)]
const LAKE_WATER := Vector2i(5, 1)
const LAKE_BLOCK := Vector2i(4, 0)
const POND_ORIGIN := Vector2i(14, 0)
const POND_SIZE := Vector2i(5, 5)
const POND_GAPS: Array[Vector2i] = [Vector2i(0, 4), Vector2i(4, 4)]
const EDGE_BLOCK := {MEDIUM: Vector2i(8, 0), DARK: Vector2i(8, 6)}
const SHADE_COLOR := {
	LIGHT: Color(34 / 255.0, 32 / 255.0, 52 / 255.0),
	MEDIUM: Color(31 / 255.0, 29 / 255.0, 48 / 255.0),
	DARK: Color(29 / 255.0, 27 / 255.0, 46 / 255.0),
}
const WATER_COLOR := Color(34 / 255.0, 47 / 255.0, 129 / 255.0)
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
const LAKE_SIDE_LIPS := {
	Vector2i.RIGHT: Vector2i(0, 1),
	Vector2i.LEFT: Vector2i(2, 1),
	Vector2i.DOWN: Vector2i(1, 0),
	Vector2i.UP: Vector2i(1, 2),
}
const LAKE_CORNER_LIPS := {
	Vector2i(1, 1): Vector2i(0, 0),
	Vector2i(-1, 1): Vector2i(2, 0),
	Vector2i(1, -1): Vector2i(0, 2),
	Vector2i(-1, -1): Vector2i(2, 2),
}

@export var map_tiles := Vector2i(72, 40)
@export var ground_scale := 4.0
@export var cluster_radius := 160.0
@export var member_spacing := 90.0
@export var townhall_clearing := 300.0
@export var edge_margin := 64.0

#how trees spawn
@export_group("Trees")
@export var tree_scenes: Array[PackedScene] = []
@export var tree_clusters := 160
@export var tree_cluster_sizes: Array[int] = [1, 1, 1, 2, 2, 3, 5]
@export var tree_cluster_spacing := 450.0

#edit here to adjust the size of diff patches
@export_group("Ground Patches")
@export var blob_frequency := 0.08
@export var medium_amount := 0.3
@export var light_amount := 0.05
@export var mud_puddle_chance := 0.04
@export var water_puddle_chance := 0.03
@export var lake_count := 5
@export var lake_max_size := 8.0
@export var pond_chance := 0.4
@export var firefly_scene: PackedScene
@export var town_radius := 3.0
@export var decor_chance := 0.3

#how mineralz spawn, same as trees but different values
@export_group("Minerals")
@export var mineral_scenes: Array[PackedScene] = []
@export var mineral_clusters := 32
@export var mineral_cluster_sizes: Array[int] = [1, 1, 2, 3]
@export var mineral_cluster_spacing := 900.0

@export_group("Bases")
@export var player_base := Vector2(0.18, 0.72)
@export var enemy_base := Vector2(0.82, 0.28)
@export var pocket_tree_clusters := 4
@export var pocket_mineral_clusters := 2
@export var pocket_min_distance := 450.0
@export var pocket_max_distance := 850.0

@export_group("Middle")
@export var middle_radius := 900.0
@export var middle_tree_clusters := 10
@export var middle_mineral_clusters := 6
@export_group("")

var map_size: Vector2
var bases := {}
var level := {}
var lake_cells := {}
var pond_cells := {}
var lakes: Array = []
var water_cells := {}
var sheet: Image
var lip_images := {}
var units = []
var cluster_centers: Array[Vector2] = []

# Roughly the unit's 139x143 collision box, so a click on the sprite counts as a hit.
const CLICK_PICK_RADIUS := 80.0

# The ghost's green/red panel spans x -20..20, y -31..9, so its centre sits 11px up.
const PLACE_FOOTPRINT := Vector2(150, 150)
const PLACE_FOOTPRINT_OFFSET := Vector2(0, 0)

var placing_scene: PackedScene
# Untyped on purpose: this is a scene instance carrying set_preview_valid().
var ghost

func _enter_tree() -> void:
	Global.reset()

func _ready() -> void:
	generate_map()
	get_units()
	Global.populus = units.size()
	Global.economy("enemy").populus = get_tree().get_nodes_in_group("unit").filter(func(unit): return unit.team == "enemy").size()

func generate_map():
	var tile_size := TILE_PX * ground_scale
	map_size = Vector2(map_tiles) * tile_size
	bases = {"player": Vector2(map_tiles) * player_base, "enemy": Vector2(map_tiles) * enemy_base}

	$Ground.scale = Vector2.ONE * ground_scale
	$Fog.size = map_size
	generate_levels()
	place_lakes()
	paint_ground()

	$Camera.limit_left = 0
	$Camera.limit_top = 0
	$Camera.limit_right = int(map_size.x)
	$Camera.limit_bottom = int(map_size.y)
	$Camera.position = base_position("player")

	for building in $Houses.get_children():
		building.position = base_position(building.team)
	for unit in $Units.get_children():
		unit.position = base_position(unit.team) + Vector2(randf_range(-150, 150), 220)

	add_lake_fireflies()

	cluster_centers.clear()
	for team in bases:
		place_clusters_near(tree_scenes, tree_cluster_sizes, pocket_tree_clusters, base_position(team), pocket_min_distance, pocket_max_distance)
		place_clusters_near(mineral_scenes, mineral_cluster_sizes, pocket_mineral_clusters, base_position(team), pocket_min_distance, pocket_max_distance)
	place_clusters_near(tree_scenes, tree_cluster_sizes, middle_tree_clusters, map_size / 2, 0.0, middle_radius)
	place_clusters_near(mineral_scenes, mineral_cluster_sizes, middle_mineral_clusters, map_size / 2, 0.0, middle_radius)
	scatter_resource(mineral_scenes, mineral_clusters, mineral_cluster_sizes, mineral_cluster_spacing)
	scatter_resource(tree_scenes, tree_clusters, tree_cluster_sizes, tree_cluster_spacing)

func generate_levels():
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = blob_frequency
	level.clear()
	for x in map_tiles.x:
		for y in map_tiles.y:
			var cell := Vector2i(x, y)
			var value := noise.get_noise_2dv(Vector2(cell))
			var height := LIGHT if value > -light_amount else (MEDIUM if value > -medium_amount else DARK)
			var town_distance := base_distance(cell_center(cell))
			if town_distance < town_radius:
				height = LIGHT
			elif town_distance < town_radius + 1.5:
				height = maxi(height, MEDIUM)
			if x == 0 or y == 0 or x == map_tiles.x - 1 or y == map_tiles.y - 1:
				height = DARK
			level[cell] = height

	for cell in level:
		if level[cell] == LIGHT and neighbors(cell).any(func(n): return height_at(n) == DARK):
			level[cell] = MEDIUM

	var puddles: Array[Vector2i] = []
	for cell in level:
		var height: int = level[cell]
		if height == DARK or randf() >= mud_puddle_chance or base_distance(cell_center(cell)) < town_radius:
			continue
		if neighbors(cell).all(func(n): return height_at(n) == height):
			puddles.append(cell)
	for cell in puddles:
		level[cell] -= 1

func place_lakes():
	lake_cells.clear()
	pond_cells.clear()
	lakes.clear()
	var placed := 0
	for attempt in lake_count * 200:
		if placed == lake_count:
			return
		if randf() < pond_chance:
			if place_pond():
				placed += 1
			continue
		var diameter := lake_max_size * randf_range(0.6, 1.0)
		var center := Vector2(randf_range(diameter, map_tiles.x - diameter), randf_range(diameter, map_tiles.y - diameter))
		var lake := grow_lake(center, diameter)
		if lake.all(func(cell): return fits_lake(cell)):
			for cell in lake:
				lake_cells[cell] = true
			lakes.append(lake)
			placed += 1

func place_pond() -> bool:
	var corner := Vector2i(randi_range(3, map_tiles.x - POND_SIZE.x - 3), randi_range(3, map_tiles.y - POND_SIZE.y - 3))
	var pond: Array[Vector2i] = []
	for x in POND_SIZE.x:
		for y in POND_SIZE.y:
			if not POND_GAPS.has(Vector2i(x, y)):
				pond.append(corner + Vector2i(x, y))
	if not pond.all(func(cell): return fits_lake(cell)):
		return false
	var area := Rect2i(corner, POND_SIZE)
	for x in range(area.position.x - 2, area.end.x + 2):
		for y in range(area.position.y - 2, area.end.y + 2):
			var cell := Vector2i(x, y)
			level[cell] = LIGHT if area.grow(1).has_point(cell) else maxi(level[cell], MEDIUM)
	for cell in pond:
		pond_cells[cell] = POND_ORIGIN + cell - corner
	lakes.append(pond)
	return true

func add_lake_fireflies():
	var tile_size := TILE_PX * ground_scale
	for lake in lakes:
		var bounds := Rect2(Vector2(lake[0]), Vector2.ONE)
		for cell in lake:
			bounds = bounds.expand(Vector2(cell)).expand(Vector2(cell) + Vector2.ONE)
		var fireflies := firefly_scene.instantiate() as CPUParticles2D
		fireflies.position = bounds.get_center() * tile_size
		fireflies.emission_rect_extents = bounds.size * tile_size / 2
		fireflies.amount = clampi(lake.size(), 8, 24)
		$Effects.add_child(fireflies)

func grow_lake(center: Vector2, diameter: float) -> Array[Vector2i]:
	var lake: Array[Vector2i] = []
	var main := Vector2(diameter - 1, (diameter - 1) * randf_range(0.7, 1.0)) / 2
	if randf() < 0.5:
		main = Vector2(main.y, main.x)
	add_ellipse(lake, center, main)
	for lobe in randi_range(1, 3):
		var direction := Vector2.from_angle(randf() * TAU)
		add_ellipse(lake, center + direction * main * randf_range(0.6, 0.9), main * randf_range(0.4, 0.6))

	var sides := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var knobs := lake.filter(func(cell): return sides.filter(func(d): return lake.has(cell + d)).size() <= 1)
	for knob in knobs:
		lake.erase(knob)
	for cell in lake.duplicate():
		for side in sides:
			var gap: Vector2i = cell + side
			if not lake.has(gap) and sides.filter(func(d): return lake.has(gap + d)).size() >= 3:
				lake.append(gap)
	return lake

func add_ellipse(lake: Array[Vector2i], center: Vector2, radius: Vector2):
	for x in range(floori(center.x - radius.x) - 1, ceili(center.x + radius.x) + 1):
		for y in range(floori(center.y - radius.y) - 1, ceili(center.y + radius.y) + 1):
			var cell := Vector2i(x, y)
			if ((cell_center(cell) - center) / radius).length_squared() <= 1.0 and not lake.has(cell):
				lake.append(cell)

func fits_lake(cell: Vector2i) -> bool:
	if base_distance(cell_center(cell)) < town_radius + 3:
		return false
	if cell.x < 2 or cell.y < 2 or cell.x > map_tiles.x - 3 or cell.y > map_tiles.y - 3:
		return false
	for n in neighbors(cell) + [cell]:
		if lake_cells.has(n) or pond_cells.has(n):
			return false
	return true

func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				result.append(cell + Vector2i(dx, dy))
	return result

func height_at(cell: Vector2i) -> int:
	return level.get(cell, DARK)

func land_height_at(cell: Vector2i) -> int:
	return DARK if lake_cells.has(cell) else height_at(cell)

func base_position(team: String) -> Vector2:
	return bases[team] * TILE_PX * ground_scale

func base_distance(tile: Vector2) -> float:
	var nearest := INF
	for team in bases:
		nearest = minf(nearest, tile.distance_to(bases[team]))
	return nearest

func near_base(pos: Vector2) -> bool:
	for team in bases:
		if pos.distance_to(base_position(team)) < townhall_clearing + cluster_radius:
			return true
	return false

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)

func paint_ground():
	sheet = TILESET.get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	water_cells.clear()

	var sheet_cells := {}
	var composed := {}
	var composed_cells := {}
	for cell in level:
		if pond_cells.has(cell):
			sheet_cells[cell] = pond_cells[cell]
			continue
		if lake_cells.has(cell):
			sheet_cells[cell] = LAKE_WATER
			continue
		var height: int = level[cell]
		var row: int = SHADE_ROW[height]
		var base: Vector2i
		if randf() < water_puddle_chance:
			base = WATER_PUDDLES.pick_random()
			water_cells[cell] = true
		elif randf() < decor_chance:
			base = DECOR.pick_random()
		else:
			base = PLAIN.pick_random()
		base += Vector2i(0, row)
		var edge_lips := edge_lips_for(cell)
		var lake_lips := lake_lips_for(cell)
		if edge_lips.is_empty() and lake_lips.is_empty():
			sheet_cells[cell] = base
			continue
		var key := str([base, edge_lips, lake_lips])
		if not composed.has(key):
			composed[key] = compose(base, edge_lips, lake_lips, height)
		composed_cells[cell] = key

	var keys := composed.keys()
	var columns := 16
	var rows := maxi(1, ceili(keys.size() / float(columns)))
	var atlas := Image.create_empty(columns * TILE_PX, rows * TILE_PX, false, Image.FORMAT_RGBA8)
	var atlas_coords := {}
	for i in keys.size():
		@warning_ignore("integer_division")
		var coords := Vector2i(i % columns, i / columns)
		atlas.blit_rect(composed[keys[i]], Rect2i(0, 0, TILE_PX, TILE_PX), coords * TILE_PX)
		atlas_coords[keys[i]] = coords

	var tile_set: TileSet = $Ground.tile_set
	if tile_set.has_source(1):
		tile_set.remove_source(1)
	tile_set.add_source(make_source(ImageTexture.create_from_image(atlas), Vector2i(columns, rows)), 1)

	$Ground.clear()
	for cell in sheet_cells:
		$Ground.set_cell(cell, 0, sheet_cells[cell])
	for cell in composed_cells:
		$Ground.set_cell(cell, 1, atlas_coords[composed_cells[cell]])

func edge_lips_for(cell: Vector2i) -> Array[Vector2i]:
	var lips: Array[Vector2i] = []
	var height: int = level[cell]
	if not EDGE_BLOCK.has(height):
		return lips
	var block: Vector2i = EDGE_BLOCK[height]
	for side in SIDE_LIPS:
		if land_height_at(cell + side) > height:
			lips.append(block + SIDE_LIPS[side].pick_random())
	for corner in CORNER_LIPS:
		if land_height_at(cell + corner) > height and land_height_at(cell + Vector2i(corner.x, 0)) <= height and land_height_at(cell + Vector2i(0, corner.y)) <= height:
			lips.append(block + CORNER_LIPS[corner])
	return lips

func lake_lips_for(cell: Vector2i) -> Array[Vector2i]:
	var lips: Array[Vector2i] = []
	var block := LAKE_BLOCK + Vector2i(0, SHADE_ROW[level[cell]])
	for side in LAKE_SIDE_LIPS:
		if lake_cells.has(cell + side):
			lips.append(block + LAKE_SIDE_LIPS[side])
	for corner in LAKE_CORNER_LIPS:
		if lake_cells.has(cell + corner) and not lake_cells.has(cell + Vector2i(corner.x, 0)) and not lake_cells.has(cell + Vector2i(0, corner.y)):
			lips.append(block + LAKE_CORNER_LIPS[corner])
	return lips

func compose(base: Vector2i, edge_lips: Array[Vector2i], lake_lips: Array[Vector2i], height: int) -> Image:
	var image := sheet.get_region(Rect2i(base * TILE_PX, Vector2i(TILE_PX, TILE_PX)))
	var whole := Rect2i(0, 0, TILE_PX, TILE_PX)
	for coords in edge_lips:
		image.blend_rect(lip_image(coords, SHADE_COLOR[height + 1], true), whole, Vector2i.ZERO)
	for coords in lake_lips:
		image.blend_rect(lip_image(coords, SHADE_COLOR[height], false), whole, Vector2i.ZERO)
	for coords in lake_lips:
		image.blend_rect(lip_image(coords, WATER_COLOR, true), whole, Vector2i.ZERO)
	return image

func lip_image(coords: Vector2i, color: Color, matching: bool) -> Image:
	var key := str([coords, color, matching])
	if not lip_images.has(key):
		var lip := Image.create_empty(TILE_PX, TILE_PX, false, Image.FORMAT_RGBA8)
		for x in TILE_PX:
			for y in TILE_PX:
				var pixel := sheet.get_pixel(coords.x * TILE_PX + x, coords.y * TILE_PX + y)
				if pixel.is_equal_approx(color) == matching:
					lip.set_pixel(x, y, pixel)
		lip_images[key] = lip
	return lip_images[key]

func make_source(texture: Texture2D, tile_count: Vector2i) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	for x in tile_count.x:
		for y in tile_count.y:
			source.create_tile(Vector2i(x, y))
	return source

func is_water(pos: Vector2) -> bool:
	var cell := Vector2i((pos / (TILE_PX * ground_scale)).floor())
	for n in neighbors(cell) + [cell]:
		if lake_cells.has(n) or pond_cells.has(n):
			return true
	return water_cells.has(cell)


# resources - scatter them around and spawns them by cluster or not
func place_clusters_near(scenes: Array[PackedScene], sizes: Array[int], count: int, origin: Vector2, min_distance: float, max_distance: float):
	var margin := edge_margin + cluster_radius
	var placed := 0
	for attempt in count * 30:
		if placed == count:
			return
		var pos := origin + Vector2.from_angle(randf() * TAU) * randf_range(min_distance, max_distance)
		if pos.x < margin or pos.y < margin or pos.x > map_size.x - margin or pos.y > map_size.y - margin:
			continue
		if near_base(pos) or is_water(pos) or cluster_centers.any(func(c): return c.distance_to(pos) < cluster_radius * 2):
			continue
		cluster_centers.append(pos)
		spawn_cluster(scenes, pos, sizes.pick_random())
		placed += 1

func scatter_resource(scenes: Array[PackedScene], count: int, sizes: Array[int], spacing: float):
	var margin := edge_margin + cluster_radius
	var placed := 0
	for attempt in count * 30:
		if placed == count:
			return
		var pos := Vector2(randf_range(margin, map_size.x - margin), randf_range(margin, map_size.y - margin))
		if near_base(pos) or is_water(pos):
			continue
		if cluster_centers.any(func(c): return c.distance_to(pos) < spacing):
			continue
		cluster_centers.append(pos)
		spawn_cluster(scenes, pos, sizes.pick_random())
		placed += 1

func spawn_cluster(scenes: Array[PackedScene], cluster_center: Vector2, size: int):
	spawn(scenes, cluster_center)
	var start_angle := randf() * TAU
	for i in size - 1:
		var angle := start_angle + i * TAU / (size - 1)
		spawn(scenes, cluster_center + Vector2.from_angle(angle) * randf_range(member_spacing, cluster_radius))

func spawn(scenes: Array[PackedScene], pos: Vector2):
	if is_water(pos):
		return
	var node := scenes.pick_random().instantiate() as Node2D
	node.position = pos
	$Objects.add_child(node)

func get_units():
	units = null
	units = get_tree().get_nodes_in_group("unit").filter(func(unit): return unit.team == "player")


# placement - ghost the building under the cursor, green where it fits, red where it does not
func is_placing() -> bool:
	return ghost != null

func begin_placement(scene: PackedScene) -> void:
	cancel_placement()
	if scene == null:
		return
	placing_scene = scene
	ghost = scene.instantiate()
	# preview must be set before add_child, because _ready reads it.
	ghost.preview = true
	# Layer 0 so it neither blocks anything nor shows up in its own placement check.
	ghost.collision_layer = 0
	ghost.collision_mask = 0
	ghost.input_pickable = false
	$Objects.add_child(ghost)
	_update_ghost()

func cancel_placement() -> void:
	if ghost:
		ghost.queue_free()
	ghost = null
	placing_scene = null

func can_place_at(pos: Vector2) -> bool:
	if is_water(pos):
		return false
	# Real shapes, so scaled and offset foliage blocks correctly.
	var shape := RectangleShape2D.new()
	shape.size = PLACE_FOOTPRINT
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, pos + PLACE_FOOTPRINT_OFFSET)
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body = hit.collider
		# Anything static blocks: foliage, the townhall, and already-placed storage
		# houses. Units are CharacterBody2D, so a passing troop does not flicker it.
		if body is StaticBody2D:
			return false
	return true

func place_ghost() -> void:
	if not can_place_at(ghost.global_position) or not Global.can_build(ghost.stats) or not Global.spend(ghost.stats.cost):
		return
	var building := placing_scene.instantiate() as Node2D
	building.position = ghost.global_position
	$Objects.add_child(building)
	Global.add_xp(Global.XP_PER_BUILD)
	# One placement per pick: drop the ghost so nothing stays in hand.
	cancel_placement()

func _update_ghost() -> void:
	ghost.global_position = get_global_mouse_position()
	ghost.set_preview_valid(can_place_at(ghost.global_position) and Global.can_afford(ghost.stats.cost))

# Polled rather than an _unhandled_input branch: both the GUI and physics picking
# mark a mouse click handled before unhandled input runs, so a click over a unit or
# over the HUD would never arrive. Polling cannot be swallowed.
func _try_place() -> void:
	if not Input.is_action_just_pressed("LeftClick"):
		return
	# Clicking a widget is HUD interaction, not map interaction: drop the building.
	if _pointing_at_widget():
		cancel_placement()
		return
	place_ghost()

# Only real widgets veto a click. Testing for any hovered Control instead refuses
# placement over every decorative Panel and layout rectangle that overlaps the map,
# which reads as "green but it will not place".
func _pointing_at_widget() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	if hovered is BaseButton or hovered is ScrollContainer:
		return true
	if hovered is TabBar or hovered is TabContainer or hovered is SubViewportContainer:
		return true
	return false

func _process(delta: float) -> void:
	if not ghost:
		return
	_update_ghost()
	_try_place()

func _unhandled_input(event: InputEvent) -> void:
	if Settings.infinite_resources and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_K:
		test_damage()
	if Settings.infinite_resources and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		Global.spawn_unit(TEST_ENEMY, get_global_mouse_position() - Vector2(0, 160), 1.0, "enemy")
	if not is_placing():
		return
	if event.is_action_pressed("ui_cancel"):
		cancel_placement()
		# Consume it so the pause menu does not also act on the same Esc.
		get_viewport().set_input_as_handled()
	
func enemy_at(point: Vector2, team: String) -> Node2D:
	for group in ["unit", "buildings"]:
		for other in get_tree().get_nodes_in_group(group):
			if other.team != team and other.visible and not other.get("preview") and other.global_position.distance_to(point) <= other.hit_radius:
				return other
	return null

func test_damage() -> void:
	for unit in units.filter(func(unit): return unit.selected):
		unit.get_node("Health").take_damage(30, "enemy")
	for building in get_tree().get_nodes_in_group("buildings").filter(func(building): return building.Selected):
		building.get_node("Health").take_damage(60, "enemy")

func _on_camera_area_selected(object) -> void:
	if _pointing_at_widget():
		return
	var start = object.start
	var end = object.end
	if start.is_equal_approx(end):
		# A click, not a drag: pick one unit instead of scanning an area.
		select_unit_at(start)
		return
	var area = []
	area.append(Vector2(min(start.x, end.x), min (start.y, end.y)))
	area.append(Vector2(max(start.x, end.x), max(start.y, end.y)))
	var ut = get_units_in_area(area)
	for u in units:
		u.set_selected(false)
	for u in ut:
		u.set_selected(!u.selected)

# Nearest unit within CLICK_PICK_RADIUS of the click, or nothing if the click missed.
func select_unit_at(point: Vector2) -> void:
	var picked = null
	var best := CLICK_PICK_RADIUS
	for unit in units:
		var distance = unit.position.distance_to(point)
		if distance <= best:
			best = distance
			picked = unit
	for unit in units:
		unit.set_selected(unit == picked)

func get_units_in_area(area):
	var u = []
	for unit in units:
		if (unit.position.x > area[0].x) and (unit.position.x < area[1].x):
			if (unit.position.y > area[0].y) and (unit.position.y < area[1].y):
				u.append(unit)
	return u
