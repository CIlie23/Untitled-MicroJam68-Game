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
		sliders[bus].set_value_no_signal(Settings.volumes[bus])
		value_labels[bus].text = str(int(Settings.volumes[bus]))

	%MuteCheck.set_pressed_no_signal(Settings.muted)
	_set_sliders_enabled(not Settings.muted)

	if OS.has_feature("web"):
		%WindowSizeRow.hide()
	else:
		for window_size in Settings.WINDOW_SIZES:
			%WindowSize.add_item("%d x %d" % [window_size.x, window_size.y])
		%WindowSize.select(Settings.window_size_index)
		%WindowSize.disabled = Settings.is_fullscreen()

	%FullscreenCheck.set_pressed_no_signal(Settings.is_fullscreen())

	%CameraSpeedSlider.set_value_no_signal(Settings.camera_speed)
	%CameraSpeedValue.text = "%d%%" % Settings.camera_speed
	%InfiniteResourcesCheck.set_pressed_no_signal(Settings.infinite_resources)

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


func _input(event: InputEvent) -> void:
	if rebinding_action.is_empty() or event is not InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.physical_keycode != KEY_ESCAPE:
		Settings.set_key(rebinding_action, event.physical_keycode)
	rebinding_action = &""
	_refresh_key_labels()


func _on_back_button_pressed() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _on_master_slider_value_changed(value: float) -> void:
	_set_volume(&"Master", value)


func _on_music_slider_value_changed(value: float) -> void:
	_set_volume(&"Music", value)


func _on_sfx_slider_value_changed(value: float) -> void:
	_set_volume(&"SFX", value)


func _set_volume(bus: StringName, value: float) -> void:
	Settings.set_volume(bus, value)
	value_labels[bus].text = str(int(value))


func _on_mute_check_toggled(muted: bool) -> void:
	Settings.set_muted(muted)
	_set_sliders_enabled(not muted)


func _set_sliders_enabled(enabled: bool) -> void:
	for slider in sliders.values():
		slider.editable = enabled


func _on_window_size_item_selected(index: int) -> void:
	Settings.set_window_size(index)


func _on_fullscreen_check_toggled(fullscreen: bool) -> void:
	Settings.set_fullscreen(fullscreen)
	%WindowSize.disabled = fullscreen


func _start_rebind(action: StringName) -> void:
	rebinding_action = action
	_refresh_key_labels()
	key_buttons[action].text = "Press a key..."


func _on_camera_speed_slider_value_changed(value: float) -> void:
	Settings.camera_speed = value
	%CameraSpeedValue.text = "%d%%" % value


func _on_infinite_resources_check_toggled(enabled: bool) -> void:
	Settings.infinite_resources = enabled


func _on_key_layout_button_pressed() -> void:
	Settings.apply_key_layout("WASD" if Settings.current_key_layout() == "Arrows" else "Arrows")
	rebinding_action = &""
	_refresh_key_labels()


func _refresh_key_labels() -> void:
	for action in key_buttons:
		key_buttons[action].text = Settings.key_label(action)
	%KeyLayoutButton.text = Settings.current_key_layout()
