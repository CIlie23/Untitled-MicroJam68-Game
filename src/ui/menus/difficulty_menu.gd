extends Control

const GAME_SCENE_PATH := "res://src/levels/world.tscn"


func _on_difficulty_picked(level: int) -> void:
	Settings.ai_difficulty = level
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_back_button_pressed() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
