extends Node

@onready var label: Label = $Label
@onready var label_wood: Label = $VBoxContainer/Wood/Label2
@onready var label_mineral: Label = $VBoxContainer/Mineral/Label2
@onready var label_populus: Label = $VBoxContainer/Populus/Label2
@onready var label_food: Label = $VBoxContainer/Food/Label2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	label_wood.text = str(Global.Wood) + " wood"
	label_mineral.text = str(Global.Minerals) + " ore"
	label_populus.text = str(Global.populus) + " / " + str(Global.maxPopulus) + " population"
	label_food.text = str(Global.coin) + " food"
