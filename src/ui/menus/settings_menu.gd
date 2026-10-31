extends Control

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
var key_buttons: Dictionary[StringName, Button] = {}
var rebinding_action: StringName = &""


func _ready() -> void:
	for bus in sliders:
		sliders[bus].value = Settings.volumes[bus]
		value_labels[bus].text = str(int(Settings.volumes[bus]))
		sliders[bus].value_changed.connect(_on_volume_changed.bind(bus))

	%MuteCheck.button_pressed = Settings.muted
	_set_sliders_enabled(not Settings.muted)
	%MuteCheck.toggled.connect(_on_mute_toggled)

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

	%CameraSpeedSlider.value = Settings.camera_speed
	%CameraSpeedValue.text = "%d%%" % Settings.camera_speed
	%CameraSpeedSlider.value_changed.connect(_on_camera_speed_changed)

	for action in Settings.KEYBIND_NAMES:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = Settings.KEYBIND_NAMES[action]
		label.custom_minimum_size.x = 130
		var button := Button.new()
		button.custom_minimum_size.x = 140
		button.pressed.connect(_start_rebind.bind(action))
		row.add_child(label)
		row.add_child(button)
		%KeybindList.add_child(row)
		key_buttons[action] = button
	_refresh_key_labels()
	%KeyLayoutButton.pressed.connect(_on_key_layout_pressed)

	%BackButton.pressed.connect(queue_free)


func _input(event: InputEvent) -> void:
	if rebinding_action.is_empty() or event is not InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.physical_keycode != KEY_ESCAPE:
		Settings.set_key(rebinding_action, event.physical_keycode)
	rebinding_action = &""
	_refresh_key_labels()


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


func _start_rebind(action: StringName) -> void:
	rebinding_action = action
	_refresh_key_labels()
	key_buttons[action].text = "Press a key..."


func _on_camera_speed_changed(value: float) -> void:
	Settings.camera_speed = value
	%CameraSpeedValue.text = "%d%%" % value


func _on_key_layout_pressed() -> void:
	Settings.apply_key_layout("WASD" if Settings.current_key_layout() == "Arrows" else "Arrows")
	rebinding_action = &""
	_refresh_key_labels()


func _refresh_key_labels() -> void:
	for action in key_buttons:
		key_buttons[action].text = Settings.key_label(action)
	%KeyLayoutButton.text = Settings.current_key_layout()
