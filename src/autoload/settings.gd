extends Node

const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

const DEFAULT_LAYOUT := "WASD"
const KEY_LAYOUTS: Dictionary[String, Dictionary] = {
	"Arrows": {
		&"camera_up": KEY_UP,
		&"camera_down": KEY_DOWN,
		&"camera_left": KEY_LEFT,
		&"camera_right": KEY_RIGHT,
	},
	"WASD": {
		&"camera_up": KEY_W,
		&"camera_down": KEY_S,
		&"camera_left": KEY_A,
		&"camera_right": KEY_D,
	},
}
const KEYBIND_NAMES: Dictionary[StringName, String] = {
	&"camera_up": "Camera Up",
	&"camera_down": "Camera Down",
	&"camera_left": "Camera Left",
	&"camera_right": "Camera Right",
}

var volumes := {&"Master": 100.0, &"Music": 100.0, &"SFX": 100.0}
var muted := false
var window_size_index := 0
var camera_speed := 100.0
var infinite_resources := false


func _ready() -> void:
	for action in KEYBIND_NAMES:
		InputMap.add_action(action)
	apply_key_layout(DEFAULT_LAYOUT)


func get_key(action: StringName) -> Key:
	var events := InputMap.action_get_events(action)
	return events[0].physical_keycode if events else KEY_NONE


func set_key(action: StringName, key: Key) -> void:
	var old_key := get_key(action)
	for other in KEYBIND_NAMES:
		if other != action and get_key(other) == key:
			_bind(other, old_key)
	_bind(action, key)


func apply_key_layout(layout: String) -> void:
	for action in KEY_LAYOUTS[layout]:
		_bind(action, KEY_LAYOUTS[layout][action])


func current_key_layout() -> String:
	for layout in KEY_LAYOUTS:
		if KEY_LAYOUTS[layout].keys().all(func(action): return get_key(action) == KEY_LAYOUTS[layout][action]):
			return layout
	return "Custom"


func key_label(action: StringName) -> String:
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(get_key(action)))


func _bind(action: StringName, key: Key) -> void:
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func set_volume(bus: StringName, value: float) -> void:
	volumes[bus] = value
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), value / 100.0)


func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), value)


func set_window_size(index: int) -> void:
	window_size_index = index
	var size := WINDOW_SIZES[index]
	var screen := DisplayServer.window_get_current_screen()
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(
		DisplayServer.screen_get_position(screen) + (DisplayServer.screen_get_size(screen) - size) / 2
	)


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func set_fullscreen(value: bool) -> void:
	if value:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		set_window_size(window_size_index)
