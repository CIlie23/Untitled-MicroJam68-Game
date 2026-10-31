extends Control
## How-to-play overlay, opened from the main menu. Back/Esc removes it.
## Drop a screenshot or diagram into the Image node's Texture in the Inspector.


func _ready() -> void:
	%BackButton.pressed.connect(queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
