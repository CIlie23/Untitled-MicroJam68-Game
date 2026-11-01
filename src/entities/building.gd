class_name Building
extends StaticBody2D

# shared type for buildings like townhall, placeholder
@export var team := "player"
@export var enemy_texture: Texture2D
@export var hit_radius := 70.0

var level := 1
var mouseEntered := false
var Selected := false:
	set(value):
		Selected = value
		if has_node("Selected"):
			$Selected.visible = value


func _enter_tree() -> void:
	add_to_group(&"buildings")


func apply_team_tint() -> void:
	if team != "enemy":
		return
	if enemy_texture:
		$Sprite2D.texture = enemy_texture
	else:
		$Sprite2D.modulate *= Global.ENEMY_TINT


# Unhandled, not _input: clicks on the thHud buttons must not also toggle the building.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("LeftClick"):
		Selected = team == "player" and mouseEntered and not Selected


func _on_mouse_entered() -> void:
	mouseEntered = true


func _on_mouse_exited() -> void:
	mouseEntered = false
