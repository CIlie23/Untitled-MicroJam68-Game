extends Control
## Options overlay. Opened on top of the main menu or the pause menu; Back/Esc just removes it.
## Nodes are looked up by unique name (%), so the layout can be rearranged freely.

@onready var sliders: Dictionary[StringName, HSlider] = {
	&"Master": %MasterSlider,
	&"Music": %MusicSlider,
	&"SFX": %SFXSlider,
}
@onready var value_labels: Dictionary[StringName, Label] = {
	&"Master": %MasterValue,
	&"Music": %MusicValue,
	&"SFX": %SFXValue,
}


func _ready() -> void:
	for bus in sliders:
		sliders[bus].value = Settings.volumes[bus]
		value_labels[bus].text = str(int(Settings.volumes[bus]))
		sliders[bus].value_changed.connect(_on_volume_changed.bind(bus))

	%MuteCheck.button_pressed = Settings.muted
	_set_sliders_enabled(not Settings.muted)
	%MuteCheck.toggled.connect(_on_mute_toggled)

	# Browsers control the page size, so a window size picker means nothing on web.
	if OS.has_feature("web"):
		%WindowSizeRow.hide()
	else:
		for window_size in Settings.WINDOW_SIZES:
			%WindowSize.add_item("%d x %d" % [window_size.x, window_size.y])
		%WindowSize.select(Settings.window_size_index)
		%WindowSize.disabled = Settings.is_fullscreen()
		%WindowSize.item_selected.connect(Settings.set_window_size)

	%FullscreenCheck.button_pressed = Settings.is_fullscreen()
	%FullscreenCheck.toggled.connect(_on_fullscreen_toggled)

	%BackButton.pressed.connect(queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _on_volume_changed(value: float, bus: StringName) -> void:
	Settings.set_volume(bus, value)
	value_labels[bus].text = str(int(value))


func _on_mute_toggled(muted: bool) -> void:
	Settings.set_muted(muted)
	_set_sliders_enabled(not muted)


func _set_sliders_enabled(enabled: bool) -> void:
	for slider in sliders.values():
		slider.editable = enabled


func _on_fullscreen_toggled(fullscreen: bool) -> void:
	Settings.set_fullscreen(fullscreen)
	%WindowSize.disabled = fullscreen

