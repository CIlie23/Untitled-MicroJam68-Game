extends CanvasLayer

const MAIN_MENU_PATH := "res://src/ui/menus/main_menu.tscn"


func _ready() -> void:
	hide()
	Global.townhall_destroyed.connect(_on_townhall_destroyed)


func _on_townhall_destroyed(team: String) -> void:
	if visible:
		return
	var won := team != "player"
	%Title.text = "VICTORY" if won else "DEFEAT"
	%Subtitle.text = "The enemy town hall has fallen." if won else "Your town hall has fallen."
	get_tree().paused = true
	show()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _on_try_again_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
