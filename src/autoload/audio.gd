extends Node
## Plays background music and UI sounds. Lives in an autoload so music keeps going across
## scene changes, and runs while paused so the pause menu still clicks.

const MUSIC := preload("res://assets/audio/music/test_loop.mp3")
const CLICK := preload("res://assets/audio/sfx/click.wav")

var music_player := AudioStreamPlayer.new()
var click_player := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	music_player.stream = MUSIC
	music_player.bus = &"Music"
	music_player.finished.connect(music_player.play) # loop
	add_child(music_player)

	click_player.stream = CLICK
	click_player.bus = &"SFX"
	click_player.max_polyphony = 4
	add_child(click_player)

	# Every button that enters the tree, in any scene, gets a click sound.
	get_tree().node_added.connect(_on_node_added)

	# On web the browser holds audio back until the first click/keypress, then it starts.
	music_player.play()


func play_click() -> void:
	click_player.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play_click)
