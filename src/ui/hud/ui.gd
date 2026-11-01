extends Node

const TROOP_SLOT := preload("res://src/ui/hud/portrait/troopSlot/troopSlot.tscn")
const STORAGE_HOUSE := preload("res://assets/terrain/storage/storage_house.tscn")
const HOVER_OFFSET := Vector2(16, 16)

@onready var label: Label = $Label
@onready var label_wood: Label = $VBoxContainer/Wood/Label2
@onready var label_mineral: Label = $VBoxContainer/Mineral/Label2
@onready var label_populus: Label = $VBoxContainer/Populus/Label2
@onready var label_food: Label = $VBoxContainer/Food/Label2
@onready var portrait: CanvasLayer = $UnitPortrait
@onready var multiple: CanvasLayer = $MultipleSelected
@onready var slot_grid: GridContainer = $MultipleSelected/Panel/MarginContainer/ScrollContainer/GridContainer
@onready var th_hud: CanvasLayer = $ThHud
@onready var hover_stats: Control = $HoverLayer/HoverOverStats
@onready var hover_building: Control = $HoverLayer/HoverOverBuilding
@onready var train_grid: GridContainer = $ThHud/TabContainer/Troops/Panel/MarginContainer/ScrollContainer/GridContainer

var _shown: Array = []
var _hover: Control
var _queue_bars: Array = []

func _ready() -> void:
	_ignore_mouse(hover_stats)
	_ignore_mouse(hover_building)
	Global.queue_changed.connect(_rebuild_queue)
	_rebuild_queue()
	# By name, not by path: the thHud buttons live in a TabContainer that gets shuffled.
	for troop_button in _buttons_named("btnTroop"):
		_hook_hover(troop_button, hover_stats)
		troop_button.pressed.connect(_buy_troop)
	for build_button in _buttons_named("btnBuild"):
		_hook_hover(build_button, hover_building)
	# Only btnBuild1 places anything yet.
	for build_button in _buttons_named("btnBuild1"):
		build_button.pressed.connect(_place_storage)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	label_wood.text = str(Global.Wood) + " wood"
	label_mineral.text = str(Global.Minerals) + " ore"
	label_populus.text = str(Global.populus) + " / " + str(Global.maxPopulus) + " population"
	label_food.text = str(Global.coin) + " food"

	var selected := _selected_units()
	portrait.visible = selected.size() == 1
	multiple.visible = selected.size() > 1
	# Rebuild only when the selection itself changed, not every frame.
	if selected != _shown:
		_shown = selected
		_fill_slots(selected)

	# Stay up while placing, since the first placement click deselects the townhall.
	th_hud.visible = _selected_building() != null or _placing()
	if not th_hud.visible:
		_clear_hover()
	_follow_mouse()

	# Front slot shows the troop being trained, the rest have not started.
	# Guarded because a slot with no troopHealth child contributes a null, and the
	# list is indexed in step with the queue rather than compacted.
	var fraction := Global.trainFraction()
	for i in _queue_bars.size():
		if _queue_bars[i]:
			_queue_bars[i].value = fraction if i == 0 else 0.0

func _selected_units() -> Array:
	var selected := []
	for unit in get_tree().get_nodes_in_group("unit"):
		if unit.get("selected"):
			selected.append(unit)
	return selected

func _selected_building():
	for building in get_tree().get_nodes_in_group("buildings"):
		if building.get("Selected"):
			return building
	return null

# One troopSlot per selected troop.
func _fill_slots(units: Array) -> void:
	for slot in slot_grid.get_children():
		slot_grid.remove_child(slot)
		slot.queue_free()
	for unit in units:
		slot_grid.add_child(TROOP_SLOT.instantiate())

func _buy_troop() -> void:
	var building = _selected_building()
	if building:
		Global.queueTroop(building.global_position)

func _place_storage() -> void:
	var world = get_tree().get_root().get_node_or_null("World")
	if world:
		world.begin_placement(STORAGE_HOUSE)

func _placing() -> bool:
	var world = get_tree().get_root().get_node_or_null("World")
	return world != null and world.is_placing()

# One troopSlot per queued troop, rebuilt only when the queue changes.
func _rebuild_queue() -> void:
	for slot in train_grid.get_children():
		train_grid.remove_child(slot)
		slot.queue_free()
	_queue_bars.clear()
	for i in Global.train_queue.size():
		var slot = TROOP_SLOT.instantiate()
		train_grid.add_child(slot)
		var bar = slot.find_child("troopHealth", true, false)
		if bar:
			bar.max_value = 1.0
			bar.value = 0.0
		_queue_bars.append(bar)

func _buttons_named(prefix: String) -> Array:
	var found := []
	for button in th_hud.find_children("*", "Button", true, false):
		if button.name.begins_with(prefix):
			found.append(button)
	return found

func _hook_hover(button: Button, panel: Control) -> void:
	button.mouse_entered.connect(_show_hover.bind(panel))
	button.mouse_exited.connect(_hide_hover.bind(panel))

func _show_hover(panel: Control) -> void:
	_clear_hover()
	_hover = panel
	_hover.visible = true
	_follow_mouse()

func _hide_hover(panel: Control) -> void:
	# Only the panel currently shown may hide itself.
	if _hover == panel:
		_clear_hover()

func _clear_hover() -> void:
	if _hover:
		_hover.visible = false
		_hover = null

# Top-right of the cursor: the panel's bottom-left corner sits HOVER_OFFSET
# right of and above the pointer.
func _follow_mouse() -> void:
	if not _hover:
		return
	var mouse := get_viewport().get_mouse_position()
	_hover.position = Vector2(mouse.x + HOVER_OFFSET.x, mouse.y - HOVER_OFFSET.y - _hover_height())

# The hover-over root has no size of its own; its Panel child holds the 353x106 rect.
func _hover_height() -> float:
	for child in _hover.get_children():
		var control := child as Control
		if control:
			return control.size.y
	return 0.0

# A hover-over sits under the cursor, so it must never catch the mouse itself,
# or it would steal the hover from the button and flicker.
func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)
