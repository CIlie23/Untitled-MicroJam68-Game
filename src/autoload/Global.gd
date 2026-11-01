extends Node

const UNIT_SCENE := preload("res://assets/entities/unit/unit.tscn")

var CAMERA_SPEED := 400.0

var UNIT_SPEED := 550.0

var RESOURCES := {
	"Wood": {"gather_time": 3, "amount": [1, 2, 3]},
	"Minerals": {"gather_time": 6, "amount": [1]},
}

var TOWNHALL_LEVELS := [
	{"health": 500, "defense": 5, "max_population": 5, "xp": 0},
	{"health": 600, "defense": 6, "max_population": 7, "xp": 100},
	{"health": 700, "defense": 7, "max_population": 9, "xp": 150},
	{"health": 850, "defense": 9, "max_population": 11, "xp": 200},
]
var TROOP_BONUS_PER_LEVEL := 0.05
var XP_PER_BUILD := 5
var XP_PER_KILL := 5
var FREE_MODE := true

var Wood = 0
var Minerals = 0
var food = 0
var populus = 0
var maxPopulus = 5
var townhall_level := 1
var townhall_health := 0
var xp := 0

signal townhall_evolved(stage: int)

func reset():
	Wood = 0
	Minerals = 0
	food = 0
	populus = 0
	townhall_level = 1
	xp = 0
	maxPopulus = townhall_stats().max_population
	townhall_health = townhall_stats().health

func queued_troops() -> int:
	var total := 0
	for trainer in get_tree().get_nodes_in_group("trainers"):
		total += trainer.queue
	return total

func spawn_unit(troop: TroopStats, pos: Vector2, speed_multiplier := 1.0) -> void:
	var unit = UNIT_SCENE.instantiate()
	unit.stats = troop
	unit.level = townhall_level
	unit.stage = townhall_level - 1
	unit.speed_multiplier = speed_multiplier
	unit.position = pos + Vector2(randf_range(-60, 60), 160)
	get_tree().get_root().get_node("World/Units").add_child(unit)
	populus += 1
	get_tree().get_root().get_node("World").get_units()

func townhall_stats() -> Dictionary:
	return TOWNHALL_LEVELS[townhall_level - 1]

func add_xp(amount: int) -> void:
	xp += amount

func next_evolve_xp() -> int:
	return TOWNHALL_LEVELS[townhall_level].xp if townhall_level < TOWNHALL_LEVELS.size() else 0

func can_evolve() -> bool:
	return townhall_level < TOWNHALL_LEVELS.size() and (FREE_MODE or xp >= next_evolve_xp())

func evolve_townhall() -> void:
	if not can_evolve():
		return
	xp = maxi(xp - next_evolve_xp(), 0)
	townhall_level += 1
	refresh_population_cap()
	townhall_health = townhall_stats().health
	townhall_evolved.emit(townhall_level - 1)

func refresh_population_cap() -> void:
	var cap: int = townhall_stats().max_population
	for building in get_tree().get_nodes_in_group("buildings"):
		if building.has_method("population_bonus"):
			cap += building.population_bonus()
	maxPopulus = cap

func can_afford(cost: Dictionary) -> bool:
	if FREE_MODE:
		return true
	for stock in cost:
		if get(stock) < cost[stock]:
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	if FREE_MODE:
		return true
	for stock in cost:
		set(stock, get(stock) - cost[stock])
	return true

func building_level_cap() -> int:
	return townhall_level
