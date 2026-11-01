extends Node

const UNIT_SCENE := preload("res://assets/entities/unit/unit.tscn")

var CAMERA_SPEED := 400.0

var UNIT_SPEED := 550.0

var RESOURCES := {
	"Wood": {"gather_time": 3, "amount": [1, 2, 3]},
	"Minerals": {"gather_time": 6, "amount": [3, 4, 5]},
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

func spawn_unit(troop: TroopStats, pos: Vector2, speed_multiplier := 1.0, team := "player") -> void:
	var eco := economy(team)
	var unit = UNIT_SCENE.instantiate()
	unit.stats = troop
	unit.team = team
	unit.level = eco.townhall_level
	unit.speed_multiplier = speed_multiplier
	unit.position = pos + Vector2(randf_range(-60, 60), 160)
	get_tree().get_root().get_node("World/Units").add_child(unit)
	eco.populus += 1
	get_tree().get_root().get_node("World").get_units()

func credit_kill(killer_team: String) -> void:
	if economies.has(killer_team):
		economy(killer_team).xp += XP_PER_KILL

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
	eco.xp = maxi(eco.xp - eco.next_evolve_xp(), 0)
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

func building_level_cap(team := "player") -> int:
	return economy(team).building_level_cap()
