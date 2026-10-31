extends Control


#var game_scene = preload("res://levels/level2.tscn").instantiate()
var settings_scene = preload("res://src/ui/menus/settings_menu.tscn").instantiate()
var credits_scene = preload("res://src/ui/menus/credits_menu.tscn").instantiate()

func _on_play_pressed() -> void:
	pass # Replace with function body.

func _on_options_pressed() -> void:
	#animation.play("Fade-In")
	get_tree().change_scene_to_file("res://src/ui/menus/settings_menu.tscn")

func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/menus/credits_menu.tscn")
	#get_tree().root.add_child(credits_scene)
