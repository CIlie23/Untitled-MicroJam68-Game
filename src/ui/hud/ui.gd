extends Node

const TROOP_SLOT := preload("res://src/ui/hud/portrait/troopSlot/troopSlot.tscn")
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

var _shown: Array = []
var _hover: Control
# Indexed in step with _shown, so entry i is the bar for the unit at _shown[i].
# Entries can be null when a slot has no troopHealth child.
var _slot_bars: Array = []

func _ready() -> void:
	_ignore_mouse(hover_stats)
	_ignore_mouse(hover_building)
	# By name, not by path: the thHud buttons live in a TabContainer that gets shuffled.
	for troop_button in _buttons_named("btnTroop"):
		_hook_hover(troop_button, hover_stats)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	label_wood.text = str(Global.Wood) + " wood"
	label_mineral.text = str(Global.Minerals) + " ore"
	label_populus.text = str(Global.populus) + " / " + str(Global.maxPopulus) + " population"
	label_food.text = str(Global.food) + " food"

	var selected := _selected_units()
	portrait.visible = selected.size() == 1
	multiple.visible = selected.size() > 1
	# Rebuild only when the selection itself changed, not every frame.
	if selected != _shown:
		_shown = selected
		_fill_slots(selected)

	# Every frame, not just on rebuild: health changes while the selection stands.
	for i in _slot_bars.size():
		if _slot_bars[i]:
			_slot_bars[i].value = _health_fraction(_shown[i])

	# Stay up while placing, since the first placement click deselects the townhall.
	th_hud.visible = _selected_building() != null or _placing()
	if not th_hud.visible:
		_clear_hover()
	_follow_mouse()

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
	_slot_bars.clear()
	for unit in units:
		var slot = TROOP_SLOT.instantiate()
		slot_grid.add_child(slot)
		var portrait = slot.find_child("itemPortrait", true, false)
		var texture: Texture2D = unit.portrait_texture()
		if portrait and texture:
			portrait.texture = texture
		var bar = slot.find_child("troopHealth", true, false)
		if bar:
			bar.max_value = 1.0
			bar.value = _health_fraction(unit)
		_slot_bars.append(bar)

# Bar range is 0 to 1, matching how the training queue drives the same node.
func _health_fraction(unit) -> float:
	var maximum: int = unit.max_health()
	if maximum <= 0:
		return 0.0
	return clampf(float(unit.health) / float(maximum), 0.0, 1.0)

func _placing() -> bool:
	var world = get_tree().get_root().get_node_or_null("World")
	return world != null and world.is_placing()

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
