class_name Attacker
extends Node

const ARROW := preload("res://src/common/components/arrow.tscn")

signal attacked(target: Node2D)

@export var attack_range := 0.0
@export var cooldown := 1.0
@export var damage := 10
@export var ranged := false
@export var sight := 350.0

var target: Node2D
var ready_in := 0.0
var scan_in := 0.0


func active() -> bool:
	return attack_range > 0.0 and not get_parent().get("preview") and get_parent().get("built") != false


func _process(delta: float) -> void:
	if not active():
		return
	ready_in = maxf(ready_in - delta, 0.0)
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		target = null
	scan_in -= delta
	if scan_in <= 0.0 and not get_parent().get("moving"):
		scan_in = 0.25
		if target == null:
			target = nearest_enemy()
		elif target is Building:
			var defender := nearest_enemy(true)
			if defender:
				target = defender
	if target and in_reach(target) and ready_in == 0.0:
		strike()


func in_reach(other: Node2D) -> bool:
	return get_parent().global_position.distance_to(other.global_position) <= attack_range + other.hit_radius


func nearest_enemy(units_only := false) -> Node2D:
	var best: Node2D = null
	var best_distance := sight
	for group in (["unit"] if units_only else ["unit", "buildings"]):
		for other in get_tree().get_nodes_in_group(group):
			if other.team == get_parent().team or other.get("preview") or not other.visible:
				continue
			var distance: float = get_parent().global_position.distance_to(other.global_position) - other.hit_radius
			if distance <= best_distance:
				best = other
				best_distance = distance
	return best


func strike() -> void:
	ready_in = cooldown
	attacked.emit(target)
	if ranged:
		var arrow = ARROW.instantiate()
		arrow.position = get_parent().global_position
		arrow.target = target
		arrow.damage = damage
		arrow.team = get_parent().team
		arrow.era = get_parent().level
		get_tree().current_scene.add_child(arrow)
	else:
		target.get_node("Health").take_damage(damage, get_parent().team)
