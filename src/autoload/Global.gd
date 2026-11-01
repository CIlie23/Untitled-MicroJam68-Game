extends Node

const UNIT_SCENE := preload("res://assets/entities/unit/unit.tscn")

var CAMERA_SPEED := 400.0

var UNIT_SPEED := 550.0

var TRAIN_TIME := 3.0

var RESOURCES := {
	"Wood": {"gather_time": 3, "amount": [1, 2, 3]},
	"Minerals": {"gather_time": 6, "amount": [1]},
}

var Wood = 0
var Minerals = 0
var coin = 0
var populus = 0
var maxPopulus = 5

# Troops waiting to train, front first. Each entry is the position to spawn at.
var train_queue: Array = []
var train_progress := 0.0

signal queue_changed

func reset():
	Wood = 0
	Minerals = 0
	coin = 0
	populus = 0
	train_queue.clear()
	train_progress = 0.0
	queue_changed.emit()

# Queued troops count toward the cap, so you cannot queue past maxPopulus.
func queueTroop(pos: Vector2) -> void:
	if populus + train_queue.size() >= maxPopulus:
		return
	train_queue.append(pos)
	queue_changed.emit()

# How far along the front troop is, 0 to 1.
func trainFraction() -> float:
	if train_queue.is_empty():
		return 0.0
	return train_progress / TRAIN_TIME

func _process(delta: float) -> void:
	if train_queue.is_empty():
		train_progress = 0.0
		return
	train_progress += delta
	while train_progress >= TRAIN_TIME and not train_queue.is_empty():
		train_progress -= TRAIN_TIME
		spawnUnit(train_queue.pop_front())
		queue_changed.emit()
	if train_queue.is_empty():
		train_progress = 0.0

func spawnUnit(pos: Vector2) -> void:
	var path = get_tree().get_root().get_node("World/Units")
	var unit = UNIT_SCENE.instantiate()
	unit.position = pos + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	path.add_child(unit)
	populus += 1
	get_tree().get_root().get_node("World").get_units()
