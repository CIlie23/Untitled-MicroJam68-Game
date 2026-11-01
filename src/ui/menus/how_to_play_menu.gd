extends Control


func _ready() -> void:
	%Body.text = "\n".join([
		"Explain the goal of the game here.",
		"",
		"- Move camera: %s %s %s %s (change in Options)" % [
			Settings.key_label(&"camera_up"),
			Settings.key_label(&"camera_left"),
			Settings.key_label(&"camera_down"),
			Settings.key_label(&"camera_right"),
		],
		"- Zoom: mouse wheel",
		"- Select units: left-click and drag",
		"- Move selected units: hold right-click",
		"- Spawn units: click the townhall",
		"- Gather: move units next to a tree (wood) or rock (minerals)",
		"- Pause: Esc",
	])


func _on_back_button_pressed() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
