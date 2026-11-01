class_name Building
extends StaticBody2D

# shared type for buildings like townhall, placeholder
var level := 1
var mouseEntered := false
var Selected := false:
	set(value):
		Selected = value
		if has_node("Selected"):
			$Selected.visible = value


func _enter_tree() -> void:
	add_to_group(&"buildings")


# Unhandled, not _input: clicks on the thHud buttons must not also toggle the building.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("LeftClick"):
		Selected = not Selected if mouseEntered else false


func _on_mouse_entered() -> void:
	mouseEntered = true


func _on_mouse_exited() -> void:
	mouseEntered = false
