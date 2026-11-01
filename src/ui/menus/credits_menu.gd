extends Control

const ENTRIES: Array[Dictionary] = [
	{"role": "Programming", "names": ["Mihaila Nicolae-Octavian & MaskMajor"]},
	{"role": "Art & UI", "names": ["Mask Major"]},
	{"role": "Music & Sound", "names": ["Majora's Mask"]},
	{"role": "Made for", "names": ["Micro Jam - 2026 "]},
]

const ROLE_COLOR := Color(1, 1, 1, 0.55)


func _ready() -> void:
	for entry in ENTRIES:
		var group := VBoxContainer.new()
		group.add_theme_constant_override("separation", 2)
		group.add_child(_make_label(entry.role, 14, ROLE_COLOR))
		for credit_name in entry.names:
			group.add_child(_make_label(credit_name, 20))
		%Entries.add_child(group)



func _on_back_button_pressed() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _make_label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
