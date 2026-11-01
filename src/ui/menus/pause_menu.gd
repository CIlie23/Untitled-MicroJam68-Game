extends CanvasLayer

const MAIN_MENU_PATH := "res://src/ui/menus/main_menu.tscn"
const OPTIONS_SCENE := preload("res://src/ui/menus/settings_menu.tscn")


func _ready() -> void:
	%Menu.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if get_tree().paused:
			resume()
		else:
			pause()


func pause() -> void:
	get_tree().paused = true
	%Menu.show()


func resume() -> void:
	get_tree().paused = false
	%Menu.hide()


func _on_resume_button_pressed() -> void:
	resume()


func _on_try_again_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_options_button_pressed() -> void:
	add_child(OPTIONS_SCENE.instantiate())


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
