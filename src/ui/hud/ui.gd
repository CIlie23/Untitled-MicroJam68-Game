extends Node

const TROOP_SLOT := preload("res://src/ui/hud/portrait/troopSlot/troopSlot.tscn")

@onready var label: Label = $Label
@onready var label_wood: Label = $VBoxContainer/Wood/Label2
@onready var label_mineral: Label = $VBoxContainer/Mineral/Label2
@onready var label_populus: Label = $VBoxContainer/Populus/Label2
@onready var label_food: Label = $VBoxContainer/Food/Label2
@onready var portrait: CanvasLayer = $UnitPortrait
@onready var multiple: CanvasLayer = $MultipleSelected
@onready var slot_grid: GridContainer = $MultipleSelected/Panel/MarginContainer/GridContainer

var _shown: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


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

func _selected_units() -> Array:
	var selected := []
	for unit in get_tree().get_nodes_in_group("unit"):
		if unit.get("selected"):
			selected.append(unit)
	return selected

# One troopSlot per selected troop.
func _fill_slots(units: Array) -> void:
	for slot in slot_grid.get_children():
		slot_grid.remove_child(slot)
		slot.queue_free()
	for unit in units:
		slot_grid.add_child(TROOP_SLOT.instantiate())
