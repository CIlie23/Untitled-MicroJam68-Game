extends Building

@export var stats: BuildingStats

# Set before add_child by world.gd's placement code. A ghost earns nothing and has
# no progress bar; it only shows whether the current spot is buildable.
var preview := false
var health: int:
	get:
		return $Health.current
var built := false
var upgrading := false
var currTime := 0.0
var stored := 0

@onready var bar = $ProgressBar
@onready var timer = $Timer
const POP = preload("uid://baxf4afl6lm8e")

func _ready() -> void:
	$Sprite2D.frame = level - 1
	Selected = false
	apply_team_tint()
	if preview:
		set_process(false)
		bar.hide()
		set_preview_valid(false)
		return
	# Both panels sit visible in the scene file, so hide them on a real building.
	$panelGreen.hide()
	$panelRed.hide()
	$Health.setup(stats.max_health, stats.defense)
	bar.hide()
	set_process(false)
	$Sprite2D.self_modulate.a = 0.5
	$Construction.start(stats.build_time)

func finish_construction() -> void:
	built = true
	Global.add_xp(Global.XP_PER_BUILD, team)
	$Sprite2D.self_modulate.a = 1.0
	Global.refresh_population_cap(team)
	if stats.product == null:
		return
	bar.show()
	bar.max_value = stats.storage
	restart_cycle()
	timer.start()
	set_process(true)

func _on_construction_finished() -> void:
	if not built:
		finish_construction()
	elif upgrading:
		upgrading = false
		level += 1
		$Sprite2D.frame = mini(level - 1, $Sprite2D.hframes - 1)
		Global.refresh_population_cap(team)
		Global.add_xp(Global.XP_PER_UPGRADE, team)

func set_preview_valid(valid: bool) -> void:
	$panelGreen.visible = valid
	$panelRed.visible = not valid

func _process(delta: float) -> void:
	if currTime <= 0:
		produce()
	hand_out()
	bar.value = stored

func _on_timer_timeout() -> void:
	if stored < stats.storage:
		currTime -= timer.wait_time

func restart_cycle() -> void:
	currTime = stats.production_time

func produce() -> void:
	var amount := mini(production_amount(), stats.storage - stored)
	stored += amount
	restart_cycle()
	if amount > 0:
		var pop = POP.instantiate()
		add_child(pop)
		pop.show_value("%d %s" % [amount, stats.product.display_name.to_lower()])

func hand_out() -> void:
	var area := get_node_or_null("PickupArea") as Area2D
	if area == null or stored == 0:
		return
	for body in area.get_overlapping_bodies():
		if body.is_in_group("unit") and body.team == team and body.stats.can_gather:
			var given := mini(stored, body.inventory.space_for(stats.product))
			if given > 0:
				body.inventory.add(stats.product, given)
				stored -= given

func population_bonus() -> int:
	if preview or not built or stats.population == 0:
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
	return mini(stats.max_level, Global.building_level_cap(team))

func can_upgrade() -> bool:
	return built and not upgrading and level < level_cap() and Global.can_afford(upgrade_cost(), team)

func upgrade() -> void:
	if can_upgrade() and Global.spend(upgrade_cost(), team):
		upgrading = true
		$Construction.start(stats.upgrade_time)

func _on_health_died(killer_team: String) -> void:
	Global.credit_kill(killer_team, Global.XP_PER_BUILDING_KILL)
	remove_from_group("buildings")
	queue_free()
	Global.refresh_population_cap(team)
