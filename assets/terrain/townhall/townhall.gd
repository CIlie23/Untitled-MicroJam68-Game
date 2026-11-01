class_name Townhall
extends Building

@export var heal_radius := 500.0
@export var heal_per_second := 0.05

var heal_in := 1.0

var health: int:
	get:
		return $Health.current


func _ready() -> void:
	Selected = false
	apply_team_tint()
	$Sprite2D.frame = Global.economy(team).townhall_level - 1
	setup_health()
	Global.townhall_evolved.connect(_on_townhall_evolved)


func _process(delta: float) -> void:
	heal_in -= delta
	if heal_in > 0.0:
		return
	heal_in = 1.0
	for unit in get_tree().get_nodes_in_group("unit"):
		if unit.team == team and unit.global_position.distance_to(global_position) <= heal_radius:
			unit.get_node("Health").heal(ceili(unit.max_health() * heal_per_second))


func _on_townhall_evolved(evolved_team: String, stage: int) -> void:
	if evolved_team == team:
		$Sprite2D.frame = mini(stage, $Sprite2D.hframes - 1)
		setup_health()


func setup_health() -> void:
	var stats := Global.townhall_stats(team)
	$Health.setup(stats.health, stats.defense)


func _on_deposit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("unit") and body.team == team:
		for stack in body.inventory.take_all():
			Global.economy(team).add(stack.item.stock_name, stack.count)


func _on_health_died(killer_team: String) -> void:
	Global.credit_kill(killer_team)
	Global.townhall_destroyed.emit(team)
	remove_from_group("buildings")
	queue_free()
