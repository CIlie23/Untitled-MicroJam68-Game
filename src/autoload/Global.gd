extends Node

@onready var spawn = preload("res://src/ui/dialogue/spawn_unit.tscn")

var CAMERA_SPEED := 400.0

var UNIT_SPEED := 550.0

var RESOURCES := {
	"Wood": {"gather_time": 3, "amount": [1, 2, 3]},
	"Minerals": {"gather_time": 6, "amount": [1]},
}

var Wood = 0
var Minerals = 0
var coin = 0

func reset():
	Wood = 0
	Minerals = 0

func spawnUnit(pos):
	var path = get_tree().get_root().get_node("World/Units")
	var hasSpawn = false
	for i in path.get_child_count():
		if "SpawnUnit" in path.get_child(i).name:
			hasSpawn = true
	if hasSpawn == false:
		var spawnUnit = spawn.instantiate()
		spawnUnit.housePos = pos
		path.add_child(spawnUnit)
