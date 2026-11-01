extends CanvasLayer

const MAIN_MENU_PATH := "res://src/ui/menus/main_menu.tscn"
const OPTIONS_SCENE := preload("res://src/ui/menus/settings_menu.tscn")


func _ready() -> void:
	%Menu.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Placement mode claims Esc first. Without this, Esc would both cancel the
	# placement and open this menu, because this node is notified before World.
	var world = get_tree().current_scene
	if world and world.has_method("is_placing") and world.call("is_placing"):
		return
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
