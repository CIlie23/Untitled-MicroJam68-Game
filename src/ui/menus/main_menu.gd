extends Control

const DIFFICULTY_SCENE := preload("res://src/ui/menus/difficulty_menu.tscn")
const HOW_TO_PLAY_SCENE := preload("res://src/ui/menus/how_to_play_menu.tscn")
const OPTIONS_SCENE := preload("res://src/ui/menus/settings_menu.tscn")
const CREDITS_SCENE := preload("res://src/ui/menus/credits_menu.tscn")
@onready var soup: AnimatedSprite2D = $AnimatedSprite2D
@onready var title: AnimatedSprite2D = $Center/AnimatedSprite2D


func _ready() -> void:
	soup.play("default")
	title.play("default")
	if OS.has_feature("web"):
		%Quit.hide()


func _on_play_pressed() -> void:
	add_child(DIFFICULTY_SCENE.instantiate())


func _on_how_to_play_pressed() -> void:
	add_child(HOW_TO_PLAY_SCENE.instantiate())


func _on_options_pressed() -> void:
	add_child(OPTIONS_SCENE.instantiate())


func _on_credits_pressed() -> void:
	add_child(CREDITS_SCENE.instantiate())


func _on_quit_pressed() -> void:
	get_tree().quit()
