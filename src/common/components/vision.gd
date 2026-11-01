class_name Vision
extends Node

@export var radius := 350.0


func _enter_tree() -> void:
	add_to_group(&"vision")
