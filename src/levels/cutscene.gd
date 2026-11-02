extends Node

## Plays the intro timelines over the live map, with the gameplay frozen underneath.

const WELCOME := "res://cutscenes/welcome.dtl"
const TRAIN_TROOP := "res://cutscenes/trainTroop.dtl"
const WORKER := "res://cutscenes/worker.dtl"
const ENDGAME := "res://cutscenes/endgame.dtl"

## Population the endgame beat waits for. Matches max_population of town hall level 1,
## so it fires as soon as the starting cap is full. Growth beyond 5 is not tracked, so
## evolving the town hall does not move the goalpost.
const POPULATION_TARGET := 5

## Frozen for the welcome beat. PROCESS_MODE_DISABLED stops both processing and input,
## which covers camera.gd's polled WASD and marquee lookups, unit.gd's _input orders,
## world.gd's placement and every building's _unhandled_input.
## Deliberately not get_tree().paused: that would also freeze Dialogic, whose autoload
## and layout live under the scene tree root and inherit the pausable mode.
const FULL_FREEZE := [
	"Camera",
	"UI",
	"PauseMenu",
	"Units",
	"Objects",
	"Houses",
	"EnemyCommander",
	"Fog",
]

## Dialogic's default layout is a bare CanvasLayer with no layer set, so it lands on 1
## and ties with the HUD canvases, which win. Slot it above the HUD (1) and the hover
## layer (5) but below the pause menu (10), so pausing still covers the dialog.
const LAYOUT_LAYER := 8

## The trainTroop beat stops the world but not UI, because it tells the player to press
## the training button that UI draws.
const WORLD_FREEZE := [
	"Camera",
	"Units",
	"Objects",
	"Houses",
	"EnemyCommander",
]

## Emit this from a .dtl line as [signal arg="starter_food"] to hand over the food.
const STARTER_FOOD_SIGNAL := "starter_food"

## [signal arg="look_enemy"] pans to the enemy base, [signal arg="look_home"] pans back.
const LOOK_ENEMY_SIGNAL := "look_enemy"
const LOOK_HOME_SIGNAL := "look_home"
const CAMERA_PAN_TIME := 2.5

## Exactly one Worker at the current cost of {"food": 3} in data/stats/troops/troop.tres.
const STARTER_FOOD := 3

@onready var animation: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var fog: ColorRect = get_parent().get_node_or_null("Fog") as ColorRect

# Names for the beat in progress, so freeze() knows what to touch.
var _freeze_list: Array = []
# Node -> the process mode it had before we disabled it. Restoring a blanket INHERIT
# would clobber the modes scenes ship with: PauseMenu is PROCESS_MODE_ALWAYS so its
# buttons keep working while the tree is paused, and GameOver is too.
var _frozen: Dictionary = {}
var _playing := ""
var _welcome_done := false
var _train_troop_done := false
var _worker_done := false
var _worker_pending := false
var _endgame_done := false
var _pan: Tween


func _ready() -> void:
	# Deferred: a child's _ready runs before World's, and World is still busy with
	# generate_map() and bake_navigation().
	start.call_deferred()


func _process(_delta: float) -> void:
	if Dialogic.current_timeline or not _welcome_done:
		return
	if not _train_troop_done:
		# Same lookup the HUD uses to decide which building panel to show.
		for building in get_tree().get_nodes_in_group("buildings"):
			if building is Townhall and building.team == "player" and building.Selected:
				play(TRAIN_TROOP, WORLD_FREEZE)
				return
	# Deferred rather than played straight from the trainer signal, because the first
	# worker can pop out while the trainTroop beat is still on screen.
	if _worker_pending and _train_troop_done:
		_worker_pending = false
		_worker_done = true
		play(WORKER, WORLD_FREEZE)
		return
	# A level condition rather than an event, so no pending flag: while a beat is playing
	# the guard at the top of this function holds it back until the screen is clear.
	if not _endgame_done and Global.populus >= POPULATION_TARGET:
		_endgame_done = true
		play(ENDGAME, WORLD_FREEZE)


func start() -> void:
	watch_trainer()
	play(WELCOME, FULL_FREEZE)


## The town hall in world.tscn brings its own Trainer, so it is there from the first
## frame and never needs polling for. Only its trainer is watched: that one makes
## workers, while the barracks and friends make troops.
func watch_trainer() -> void:
	for building in get_tree().get_nodes_in_group("buildings"):
		if building is Townhall and building.team == "player":
			var trainer = building.get_node_or_null("Trainer")
			if trainer and not trainer.trained.is_connected(_on_worker_trained):
				trainer.trained.connect(_on_worker_trained)
			return


func _on_worker_trained() -> void:
	# Only the first one earns the beat; every later worker is business as usual.
	if not _worker_done:
		_worker_pending = true


func play(timeline: String, freeze_list: Array) -> void:
	_freeze_list = freeze_list
	_playing = timeline
	freeze(true)
	if timeline == WELCOME and animation and animation.has_animation(&"intro"):
		animation.play(&"intro")
	Dialogic.signal_event.connect(_on_signal_event)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	# start() returns the layout node, creating it if there is not one yet.
	var canvas := Dialogic.start(timeline) as CanvasLayer
	if canvas:
		canvas.layer = LAYOUT_LAYER


## Handles every [signal arg="..."] line in a .dtl. The argument doubles as an
## animation name, so one line can both grant something and move the camera.
func _on_signal_event(argument: Variant) -> void:
	var beat := str(argument)
	# Added straight to the stock, not via Economy.deliver(), which would also count it
	# toward the XP that town hall evolution needs.
	if beat == STARTER_FOOD_SIGNAL:
		Global.food += STARTER_FOOD
	elif beat == LOOK_ENEMY_SIGNAL:
		pan_to_base("enemy")
	elif beat == LOOK_HOME_SIGNAL:
		pan_to_base("player")
	if animation and animation.has_animation(beat):
		animation.play(beat)


## Slides the camera to a team's base. world.gd already owns where the bases are and
## uses it to place the camera on load, so ask it rather than hunting for a town hall.
## The tween is created from this node, not the camera: WORLD_FREEZE leaves the camera
## PROCESS_MODE_DISABLED for the whole beat, and a tween follows its creator's mode.
func pan_to_base(team: String) -> void:
	var world := get_parent()
	var camera := world.get_node_or_null("Camera")
	if camera == null or not world.has_method("base_position"):
		return
	# Two signals close together would otherwise leave two tweens fighting over position.
	if _pan and _pan.is_valid():
		_pan.kill()
	_pan = create_tween()
	_pan.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pan.tween_property(camera, "position", world.call("base_position", team), CAMERA_PAN_TIME)


func _on_timeline_ended() -> void:
	Dialogic.signal_event.disconnect(_on_signal_event)
	Dialogic.timeline_ended.disconnect(_on_timeline_ended)
	freeze(false)
	if _playing == WELCOME:
		_welcome_done = true
	elif _playing == TRAIN_TROOP:
		_train_troop_done = true
	_playing = ""
	_freeze_list = []


func freeze(disabled: bool) -> void:
	if disabled:
		for target in _freeze_list:
			var node := get_parent().get_node_or_null(target)
			if node == null:
				continue
			_frozen[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_DISABLED
		cancel_pending_input()
	else:
		for node in _frozen:
			if is_instance_valid(node):
				node.process_mode = _frozen[node]
		_frozen.clear()
	if fog:
		# Fog is a full screen overlay at z_index 10; the welcome beat hides it so the
		# text can point at the map, and every other beat leaves it alone.
		fog.visible = not (disabled and _freeze_list.has("Fog"))


## The trainTroop beat is triggered by a click on the town hall, so the freeze lands on
## the same frame that click starts the camera's selection marquee. Dropping that drag
## here means the camera does not come back with a stuck selection box.
func cancel_pending_input() -> void:
	var camera := get_parent().get_node_or_null("Camera")
	if camera and camera.has_method("cancel_drag"):
		camera.cancel_drag()
