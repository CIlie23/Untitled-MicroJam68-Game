extends Node
# her name was lola she was a showgirl with yellow feathers in her hair, she would merengue and do the cha-cha, and while she tried to be a star, she was just a fool who fell in love with the wrong man 
const MUSIC := preload("res://assets/audio/music/test_loop.mp3")
const CLICK := preload("res://assets/audio/sfx/click.wav")
const SELECT_VOICES := preload("res://assets/audio/sfx/sounds/select_voices.tres")
const WALK_VOICES := preload("res://assets/audio/sfx/sounds/walk_voices.tres")
const ATTACK_VOICES := preload("res://assets/audio/sfx/sounds/attack_voices.tres")
const VOICE_GAP_MS := 300

var music_player := AudioStreamPlayer.new()
var click_player := AudioStreamPlayer.new()
var voice_player := AudioStreamPlayer.new()
var last_voice_ms := -VOICE_GAP_MS


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

	voice_player.bus = &"SFX"
	add_child(voice_player)

	get_tree().node_added.connect(_on_node_added)

	music_player.play()


func play_click() -> void:
	click_player.play()


func say(voices: AudioStream) -> void:
	var now := Time.get_ticks_msec()
	if now - last_voice_ms < VOICE_GAP_MS:
		return
	last_voice_ms = now
	voice_player.stream = voices
	voice_player.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play_click)
