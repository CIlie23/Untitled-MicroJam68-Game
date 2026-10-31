extends Node
## Session-only settings. Nothing is written to disk, so everything resets on launch.
## Kept in an autoload so values survive scene changes (e.g. pause menu -> main menu).

const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1152, 648), # Godot's default window size
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

## Slider values (0-100), keyed by audio bus name.
var volumes := {&"Master": 100.0, &"Music": 100.0, &"SFX": 100.0}
var muted := false
var window_size_index := 0


func set_volume(bus: StringName, value: float) -> void:
	volumes[bus] = value
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus), value / 100.0)


## Mutes the Master bus, which silences every other bus routed through it.
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


## Read from the window instead of stored, since on web the browser can exit fullscreen on its own.
func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func set_fullscreen(value: bool) -> void:
	if value:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		set_window_size(window_size_index)
