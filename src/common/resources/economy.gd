class_name Economy
extends RefCounted

var Wood := 0
var Minerals := 0
var food := 0
var populus := 0
var maxPopulus := 0
var townhall_level := 1
var xp := 0
var team := "player"
var gather_rate := 1.0
var stat_multiplier := 1.0
var cost_multiplier := 1.0


func _init(team_name := "player") -> void:
	team = team_name
	maxPopulus = townhall_stats().max_population


func is_free() -> bool:
	return team == "player" and Global.FREE_MODE


func apply_difficulty(difficulty: AIDifficulty) -> void:
	gather_rate = difficulty.gather_rate
	stat_multiplier = difficulty.stat_multiplier
	cost_multiplier = difficulty.cost_multiplier


func scaled(cost: Dictionary) -> Dictionary:
	var result := {}
	for stock in cost:
		result[stock] = ceili(cost[stock] * cost_multiplier)
	return result


func townhall_stats() -> Dictionary:
	return Global.TOWNHALL_LEVELS[townhall_level - 1]


func next_evolve_xp() -> int:
	return Global.TOWNHALL_LEVELS[townhall_level].xp if townhall_level < Global.TOWNHALL_LEVELS.size() else 0


func can_evolve() -> bool:
	return townhall_level < Global.TOWNHALL_LEVELS.size() and (is_free() or xp >= next_evolve_xp())


func building_level_cap() -> int:
	return townhall_level


func add(stock: String, amount: int) -> void:
	set(stock, get(stock) + amount)


func can_afford(cost: Dictionary) -> bool:
	if is_free():
		return true
	var real := scaled(cost)
	for stock in real:
		if get(stock) < real[stock]:
			return false
	return true


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	if is_free():
		return true
	var real := scaled(cost)
	for stock in real:
		add(stock, -real[stock])
	return true
