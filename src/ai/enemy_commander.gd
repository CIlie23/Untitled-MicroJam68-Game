class_name EnemyCommander
extends Node

const TEAM := "enemy"

@export var difficulty: AIDifficulty

var elapsed := 0.0
var think_in := 0.0
var wave_size := 0
var wave_launch_size := 0
var attackers: Array = []
var gathering: Array = []
var gather_started := 0.0
var raiders: Array = []
var next_raid := 0.0
var next_wave := 0.0
var last_threat := -INF
var build_costs := {}


func _enter_tree() -> void:
	Global.economy(TEAM).apply_difficulty(difficulty)


func _ready() -> void:
	wave_size = difficulty.wave_size
	next_raid = difficulty.first_attack_delay
	next_wave = difficulty.first_attack_delay


func _process(delta: float) -> void:
	elapsed += delta
	think_in -= delta
	if think_in > 0.0:
		return
	think_in = difficulty.think_interval
	var home := townhall()
	if home == null:
		return
	attackers = attackers.filter(alive)
	gathering = gathering.filter(alive)
	raiders = raiders.filter(alive)
	var threats := threats_near(home)
	if not threats.is_empty():
		last_threat = elapsed
	manage_workers(home, threats)
	train(home)
	build(home)
	if Global.can_evolve(TEAM):
		Global.evolve_townhall(TEAM)
	send_wounded_home(home)
	if threats.is_empty():
		attack(home)
		raid(home)
	else:
		defend(threats)


func alive(node) -> bool:
	return is_instance_valid(node) and not node.dying


func townhall() -> Townhall:
	return find_townhall(TEAM)


func find_townhall(team: String) -> Townhall:
	for building in get_tree().get_nodes_in_group("buildings"):
		if building is Townhall and building.team == team:
			return building
	return null


func own(group: String) -> Array:
	return get_tree().get_nodes_in_group(group).filter(func(node): return node.team == TEAM and not node.get("preview"))


func workers() -> Array:
	return own("unit").filter(func(unit): return unit.stats.can_gather)


func army() -> Array:
	return own("unit").filter(func(unit): return not unit.stats.can_gather)


func player_units() -> Array:
	return get_tree().get_nodes_in_group("unit").filter(func(unit): return unit.team == "player")


func closest(nodes: Array, from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in nodes:
		var distance: float = from.distance_to(node.global_position)
		if distance < best_distance:
			best = node
			best_distance = distance
	return best


func is_wounded(unit) -> bool:
	return unit.health < unit.max_health() * difficulty.retreat_health


func idle_army() -> Array:
	return army().filter(func(unit): return not attackers.has(unit) and not raiders.has(unit) and not gathering.has(unit) and not unit.moving and unit.get_node("Attacker").target == null and not is_wounded(unit))


func home_spot(home: Townhall) -> Vector2:
	return home.global_position + Vector2(randf_range(-150.0, 150.0), 220.0)


func threats_near(home: Townhall) -> Array:
	return player_units().filter(func(unit): return unit.global_position.distance_to(home.global_position) <= difficulty.defend_radius)


func defend(threats: Array) -> void:
	var defenders := army().filter(func(unit): return not attackers.has(unit) and not raiders.has(unit) and not is_wounded(unit))
	if threats.size() >= 3:
		defenders += attackers
		attackers.clear()
	gathering.clear()
	for unit in defenders:
		unit.moving = false
		unit.get_node("Attacker").target = closest(threats, unit.global_position)


func send_wounded_home(home: Townhall) -> void:
	for unit in army():
		if is_wounded(unit) and unit.global_position.distance_to(home.global_position) > home.heal_radius:
			attackers.erase(unit)
			raiders.erase(unit)
			gathering.erase(unit)
			unit.move_to(home_spot(home))


func retreat(units: Array, home: Townhall) -> void:
	for unit in units:
		unit.move_to(home_spot(home))


func manage_workers(home: Townhall, threats: Array) -> void:
	for worker in workers():
		if threats.any(func(threat): return threat.global_position.distance_to(worker.global_position) < 450.0):
			worker.move_to(home_spot(home))
			continue
		if worker.moving or is_gathering(worker):
			continue
		var carried := 0
		for stack in worker.inventory.get_slots():
			if stack:
				carried += stack.count
		if carried >= difficulty.carry_before_return or (carried > 0 and worker.inventory.is_full()):
			worker.move_to(home.global_position + Vector2(0, 200))
			continue
		var job := next_job(worker)
		if job:
			worker.move_to(job.global_position + job.global_position.direction_to(worker.global_position) * 90.0)


func is_gathering(worker) -> bool:
	for resource in get_tree().get_nodes_in_group("resources"):
		if resource.active_gatherers().has(worker):
			return true
	return false


func next_job(worker) -> Node2D:
	for farm in own("buildings"):
		if farm.get("stored") and farm.stored >= 8:
			return farm
	var economy := Global.economy(TEAM)
	var wanted := "Wood" if economy.Wood <= economy.Minerals * 3 else "Minerals"
	var best: Node2D = null
	var best_distance := INF
	for resource in get_tree().get_nodes_in_group("resources"):
		var distance: float = worker.global_position.distance_to(resource.global_position)
		if resource.resource_name == wanted:
			distance *= 0.5
		if distance < best_distance:
			best = resource
			best_distance = distance
	return best


func train(home: Townhall) -> void:
	var home_trainer := home.get_node("Trainer") as Trainer
	if workers().size() + home_trainer.queue < difficulty.max_workers:
		home_trainer.train()
	for building in own("buildings"):
		if building == home or not building.has_node("Trainer"):
			continue
		var trainer := building.get_node("Trainer") as Trainer
		if army().size() + Global.queued_troops(TEAM) < difficulty.army_cap:
			trainer.train()


func build(home: Townhall) -> void:
	var scene := next_building()
	if scene == null:
		return
	var cost := cost_of(scene)
	if not Global.can_afford(cost, TEAM):
		return
	var world = get_parent()
	for attempt in 20:
		var spot := home.global_position + Vector2.from_angle(randf() * TAU) * randf_range(350.0, 750.0)
		if world.can_place_at(spot) and Global.spend(cost, TEAM):
			var building = scene.instantiate()
			building.team = TEAM
			building.position = spot
			world.get_node("Objects").add_child(building)
			Global.add_xp(Global.XP_PER_BUILD, TEAM)
			return


func next_building() -> PackedScene:
	var economy := Global.economy(TEAM)
	var level := economy.townhall_level
	if economy.populus + Global.queued_troops(TEAM) >= economy.maxPopulus - 1 and count(difficulty.house_scene) < 6:
		return difficulty.house_scene
	if economy.food < 10 and count(difficulty.farm_scene) < level + 1:
		return difficulty.farm_scene
	for scene in difficulty.military_scenes.slice(0, level + 1):
		if count(scene) == 0:
			return scene
	if elapsed - last_threat < 60.0 and count(difficulty.tower_scene) < level + 1:
		return difficulty.tower_scene
	if count(difficulty.farm_scene) < level + 1:
		return difficulty.farm_scene
	return null


func count(scene: PackedScene) -> int:
	return own("buildings").filter(func(building): return building.scene_file_path == scene.resource_path).size()


func cost_of(scene: PackedScene) -> Dictionary:
	if not build_costs.has(scene):
		var probe = scene.instantiate()
		build_costs[scene] = probe.stats.cost
		probe.free()
	return build_costs[scene]


func attack(home: Townhall) -> void:
	var enemy_home := find_townhall("player")
	if enemy_home == null:
		return
	if not attackers.is_empty():
		var center := Vector2.ZERO
		for unit in attackers:
			center += unit.global_position
		center /= attackers.size()
		var defenders := player_units().filter(func(unit): return unit.global_position.distance_to(center) < 700.0)
		if defenders.size() > attackers.size() * 1.5 or attackers.size() <= maxi(1, roundi(wave_launch_size * 0.3)):
			retreat(attackers, home)
			attackers.clear()
		else:
			for unit in attackers:
				if not unit.moving and unit.get_node("Attacker").target == null:
					unit.get_node("Attacker").target = pick_target(unit.global_position, false)
	var rally := home.global_position + home.global_position.direction_to(enemy_home.global_position) * difficulty.rally_distance
	if gathering.is_empty():
		if elapsed < next_wave:
			return
		var idle := idle_army()
		if idle.size() < wave_size:
			return
		gathering = idle
		gather_started = elapsed
		for unit in gathering:
			unit.move_to(rally + Vector2(randf_range(-120.0, 120.0), randf_range(-120.0, 120.0)))
		return
	var arrived := gathering.filter(func(unit): return unit.global_position.distance_to(rally) < 300.0)
	if arrived.size() >= gathering.size() * 0.8 or elapsed - gather_started > 20.0:
		for unit in gathering:
			unit.moving = false
			unit.get_node("Attacker").target = pick_target(unit.global_position, false)
		attackers += gathering
		wave_launch_size = gathering.size()
		wave_size += difficulty.wave_growth
		next_wave = elapsed + difficulty.wave_cooldown
		gathering = []


func raid(home: Townhall) -> void:
	for unit in raiders.duplicate():
		if not unit.moving and unit.get_node("Attacker").target == null:
			var target := pick_target(unit.global_position, true)
			if target:
				unit.get_node("Attacker").target = target
			else:
				raiders.erase(unit)
				unit.move_to(home_spot(home))
	if elapsed < next_raid:
		return
	next_raid = elapsed + difficulty.raid_interval
	var idle := idle_army()
	if idle.size() <= difficulty.raid_size:
		return
	idle.sort_custom(func(a, b): return a.Speed > b.Speed)
	for unit in idle.slice(0, difficulty.raid_size):
		var target := pick_target(unit.global_position, true)
		if target:
			unit.get_node("Attacker").target = target
			raiders.append(unit)


func pick_target(from: Vector2, economy_only: bool) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for group in ["unit", "buildings"]:
		for other in get_tree().get_nodes_in_group(group):
			if other.team != "player" or other.get("preview") or other.get("dying"):
				continue
			var economic: bool = other.stats.can_gather if group == "unit" else other.get("stats") != null and other.stats.product != null
			if economy_only and not economic:
				continue
			var score := from.distance_to(other.global_position)
			if economic:
				score *= 0.6
			elif other is Townhall:
				score *= 1.3
			var health: Health = other.get_node("Health")
			score *= 0.5 + 0.5 * health.current / health.max_value
			if score < best_score:
				best = other
				best_score = score
	return best
