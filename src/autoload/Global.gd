extends Node

const UNIT_SCENE := preload("res://assets/entities/unit/unit.tscn")

var CAMERA_SPEED := 400.0

var UNIT_SPEED := 550.0

var RESOURCES := {
	"Wood": {"gather_time": 5, "amount": [1, 2, 3]},
	"Minerals": {"gather_time": 10, "amount": [3, 4, 5]},
}

var TOWNHALL_LEVELS := [
	{"health": 500, "defense": 5, "max_population": 5, "xp": 0},
	{"health": 600, "defense": 6, "max_population": 7, "xp": 40},
	{"health": 700, "defense": 7, "max_population": 9, "xp": 60},
	{"health": 850, "defense": 9, "max_population": 11, "xp": 80},
]
var TROOP_BONUS_PER_LEVEL := 0.05
var GATHER_BONUS_PER_LEVEL := 0.25
var EVOLVE_TIME := 15.0
var XP_PER_BUILD := 5
var XP_PER_KILL := 6
var XP_PER_BUILDING_KILL := 15
var XP_PER_UPGRADE := 12
var XP_PER_TRAIN := 2
var XP_PER_NODE := 2
var RESOURCES_PER_XP := 10

const TEAMS := ["player", "enemy"]
const ENEMY_TINT := Color(1, 0.4, 0.4)

var economies := {}

var Wood: int:
	get:
		return economy().Wood
	set(value):
		economy().Wood = value
var Minerals: int:
	get:
		return economy().Minerals
	set(value):
		economy().Minerals = value
var food: int:
	get:
		return economy().food
	set(value):
		economy().food = value
var populus: int:
	get:
		return economy().populus
	set(value):
		economy().populus = value
var maxPopulus: int:
	get:
		return economy().maxPopulus
	set(value):
		economy().maxPopulus = value
var townhall_level: int:
	get:
		return economy().townhall_level
	set(value):
		economy().townhall_level = value
var xp: int:
	get:
		return economy().xp
	set(value):
		economy().xp = value

signal townhall_evolved(team: String, stage: int)
signal townhall_destroyed(team: String)

func _ready() -> void:
	reset()

func economy(team := "player") -> Economy:
	return economies[team]

func reset():
	for team in TEAMS:
		economies[team] = Economy.new(team)

func queued_troops(team := "player") -> int:
	var total := 0
	for trainer in get_tree().get_nodes_in_group("trainers"):
		if trainer.get_parent().team == team:
			total += trainer.queue
	return total

func spawn_unit(troop: TroopStats, pos: Vector2, speed_multiplier := 1.0, team := "player", level := 0) -> void:
	var eco := economy(team)
	var unit = UNIT_SCENE.instantiate()
	unit.stats = troop
	unit.team = team
	unit.level = level if level > 0 else eco.townhall_level
	unit.speed_multiplier = speed_multiplier
	unit.position = pos + Vector2(randf_range(-60, 60), 160)
	get_tree().get_root().get_node("World/Units").add_child(unit)
	eco.populus += 1
	get_tree().get_root().get_node("World").get_units()

func credit_kill(killer_team: String, amount := XP_PER_KILL) -> void:
	if economies.has(killer_team):
		economy(killer_team).xp += amount

func townhall_stats(team := "player") -> Dictionary:
	return economy(team).townhall_stats()

func add_xp(amount: int, team := "player") -> void:
	economy(team).xp += amount

func next_evolve_xp(team := "player") -> int:
	return economy(team).next_evolve_xp()

func can_evolve(team := "player") -> bool:
	return economy(team).can_evolve()

func evolve_townhall(team := "player") -> void:
	var eco := economy(team)
	if not eco.can_evolve():
		return
	for building in get_tree().get_nodes_in_group("buildings"):
		if building is Townhall and building.team == team:
			eco.xp = maxi(eco.xp - eco.next_evolve_xp(), 0)
			eco.evolving = true
			building.begin_evolve(EVOLVE_TIME)
			return

func finish_evolve(team := "player") -> void:
	var eco := economy(team)
	eco.evolving = false
	eco.townhall_level += 1
	refresh_population_cap(team)
	townhall_evolved.emit(team, eco.townhall_level - 1)

func refresh_population_cap(team := "player") -> void:
	var eco := economy(team)
	var cap: int = eco.townhall_stats().max_population
	for building in get_tree().get_nodes_in_group("buildings"):
		if building.team == team and building.has_method("population_bonus"):
			cap += building.population_bonus()
	eco.maxPopulus = cap

func can_afford(cost: Dictionary, team := "player") -> bool:
	return economy(team).can_afford(cost)

func spend(cost: Dictionary, team := "player") -> bool:
	return economy(team).spend(cost)

func building_count(stats: BuildingStats, team := "player") -> int:
	return get_tree().get_nodes_in_group("buildings").filter(func(building): return building.team == team and building.get("stats") == stats and not building.get("preview")).size()

func can_build(stats: BuildingStats, team := "player") -> bool:
	return (stats.max_count == 0 or building_count(stats, team) < stats.max_count) and can_afford(stats.cost, team)

func building_level_cap(team := "player") -> int:
	return economy(team).building_level_cap()
