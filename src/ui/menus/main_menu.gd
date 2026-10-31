extends Control

const GAME_SCENE_PATH := "res://src/levels/world.tscn"
const HOW_TO_PLAY_SCENE := preload("res://src/ui/menus/how_to_play_menu.tscn")
const OPTIONS_SCENE := preload("res://src/ui/menus/settings_menu.tscn")
const CREDITS_SCENE := preload("res://src/ui/menus/credits_menu.tscn")


func _ready() -> void:
	if OS.has_feature("web"):
		%Quit.hide()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_how_to_play_pressed() -> void:
	add_child(HOW_TO_PLAY_SCENE.instantiate())


func _on_options_pressed() -> void:
	add_child(OPTIONS_SCENE.instantiate())


func _on_credits_pressed() -> void:
	add_child(CREDITS_SCENE.instantiate())


func _on_quit_pressed() -> void:
	get_tree().quit()
