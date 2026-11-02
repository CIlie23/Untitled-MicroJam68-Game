extends Node
# her name was lola she was a showgirl with yellow feathers in her hair, she would merengue and do the cha-cha, and while she tried to be a star, she was just a fool who fell in love with the wrong man 
const START_MUSIC := preload("res://assets/audio/music/caveman.ogg")
const MEDIEVAL_MUSIC := preload("res://assets/audio/music/medieval.ogg")
const CLICK := preload("res://assets/audio/sfx/click.wav")
const SELECT_VOICES := preload("res://assets/audio/sfx/sounds/select_voices.tres")
const WALK_VOICES := preload("res://assets/audio/sfx/sounds/walk_voices.tres")
const ATTACK_VOICES := preload("res://assets/audio/sfx/sounds/attack_voices.tres")
const VOICE_GAP_MS := 300
## Fade length for a track change, and the level the leaving track fades down to.
const CROSSFADE_TIME := 2.5
const SILENT_DB := -60.0

## The two tracks alternate roles: whichever is `music_player` is playing, and the
## other is the empty side waiting for the next crossfade.
var music_player := AudioStreamPlayer.new()
var music_cross_player := AudioStreamPlayer.new()
var click_player := AudioStreamPlayer.new()
var voice_player := AudioStreamPlayer.new()
var last_voice_ms := -VOICE_GAP_MS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_music(music_player)
	_setup_music(music_cross_player)
	music_cross_player.volume_db = SILENT_DB

	click_player.stream = CLICK
	click_player.bus = &"SFX"
	click_player.max_polyphony = 4
	add_child(click_player)

	voice_player.bus = &"SFX"
	add_child(voice_player)

	get_tree().node_added.connect(_on_node_added)
	Global.townhall_evolved.connect(_on_townhall_evolved)

	music_player.stream = START_MUSIC
	music_player.play()


func _setup_music(player: AudioStreamPlayer) -> void:
	player.bus = &"Music"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	# The tracks are imported with loop off, so the repeat is handled here.
	player.finished.connect(player.play)
	add_child(player)


## Crossfades to a new track. Passing the track already playing does nothing, and a
## zero fade time cuts straight over.
func play_music(stream: AudioStream, fade_time := CROSSFADE_TIME) -> void:
	if music_player.stream == stream and music_player.playing:
		return
	var incoming := music_cross_player
	var outgoing := music_player
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	if fade_time <= 0.0:
		# Straight to full volume, otherwise the incoming track would stay at SILENT_DB.
		incoming.volume_db = 0.0
		outgoing.stop()
		outgoing.volume_db = SILENT_DB
	else:
		var tween := create_tween().set_parallel()
		tween.tween_property(incoming, "volume_db", 0.0, fade_time)
		tween.tween_property(outgoing, "volume_db", SILENT_DB, fade_time)
		tween.chain().tween_callback(outgoing.stop)
	# Roles swap so the next change fades the other player, not this one.
	music_player = incoming
	music_cross_player = outgoing


## `stage` is Global.townhall_level - 1, so stage 1 is the second stage.
func _on_townhall_evolved(team: String, stage: int) -> void:
	if team != "player":
		return
	if stage == 1:
		play_music(MEDIEVAL_MUSIC)


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
