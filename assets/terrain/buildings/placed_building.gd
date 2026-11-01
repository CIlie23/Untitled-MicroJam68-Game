extends Building

@export var stats: BuildingStats

# Set before add_child by world.gd's placement code. A ghost earns nothing and has
# no progress bar; it only shows whether the current spot is buildable.
var preview := false
var health := 0
var currTime := 0.0

@onready var bar = $ProgressBar
@onready var timer = $Timer
const POP = preload("uid://baxf4afl6lm8e")

func _ready() -> void:
	$Sprite2D.frame = level - 1
	Selected = false
	if preview:
		set_process(false)
		bar.hide()
		set_preview_valid(false)
		return
	# Both panels sit visible in the scene file, so hide them on a real building.
	$panelGreen.hide()
	$panelRed.hide()
	health = stats.max_health
	Global.refresh_population_cap()
	if stats.produces.is_empty():
		bar.hide()
		set_process(false)
		return
	restart_cycle()
	timer.start()

func set_preview_valid(valid: bool) -> void:
	$panelGreen.visible = valid
	$panelRed.visible = not valid

func _process(delta: float) -> void:
	if currTime <= 0:
		collect()

func _on_timer_timeout() -> void:
	currTime -= timer.wait_time
	var tween = get_tree().create_tween()
	tween.tween_property(bar, "value", currTime, 0.1).set_trans(Tween.TRANS_LINEAR)

func restart_cycle() -> void:
	currTime = stats.production_time
	bar.max_value = stats.production_time
	bar.value = currTime

func collect() -> void:
	var amount := production_amount()
	Global.set(stats.produces, Global.get(stats.produces) + amount)
	restart_cycle()
	var pop = POP.instantiate()
	add_child(pop)
	pop.show_value("%d %s" % [amount, stats.produces])

func population_bonus() -> int:
	if preview or stats.population == 0:
		return 0
	return stats.population + stats.population_per_level * (level - 1)

func production_amount() -> int:
	return stats.production + stats.production_per_level * (level - 1)

func upgrade_cost() -> Dictionary:
	var cost := {}
	for stock in stats.upgrade_cost:
		cost[stock] = stats.upgrade_cost[stock] * level
	return cost

func level_cap() -> int:
	return mini(stats.max_level, Global.building_level_cap())

func can_upgrade() -> bool:
	return level < level_cap() and Global.can_afford(upgrade_cost())

func upgrade() -> void:
	if level < level_cap() and Global.spend(upgrade_cost()):
		level += 1
		$Sprite2D.frame = mini(level - 1, $Sprite2D.hframes - 1)
		Global.refresh_population_cap()
