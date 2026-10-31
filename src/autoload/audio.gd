extends Node
# her name was lola she was a showgirl with yellow feathers in her hair, she would merengue and do the cha-cha, and while she tried to be a star, she was just a fool who fell in love with the wrong man 
const MUSIC := preload("res://assets/audio/music/test_loop.mp3")
const CLICK := preload("res://assets/audio/sfx/click.wav")

var music_player := AudioStreamPlayer.new()
var click_player := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	music_player.stream = MUSIC
	music_player.bus = &"Music"
	music_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	music_player.finished.connect(music_player.play)
	add_child(music_player)

	click_player.stream = CLICK
	click_player.bus = &"SFX"
	click_player.max_polyphony = 4
	add_child(click_player)

	get_tree().node_added.connect(_on_node_added)

	music_player.play()


func play_click() -> void:
	click_player.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play_click)
