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
var next_expand := 0.0
var last_threat := -INF
var build_costs := {}
var scout: Node2D
var worker_scout: Node2D
var next_worker_scout := 0.0
var explored: Array[Vector2] = []
var known: Array = []
var outposts: Array = []


func _enter_tree() -> void:
	Global.economy(TEAM).apply_difficulty(difficulty)


func _ready() -> void:
	wave_size = difficulty.wave_size
	next_raid = difficulty.first_attack_delay
	next_wave = difficulty.first_attack_delay
	next_expand = difficulty.expand_interval
	next_worker_scout = difficulty.worker_scout_interval


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
	if scout and not alive(scout):
		scout = null
	outposts = outposts.filter(func(outpost): return is_instance_valid(outpost.tower))
	for outpost in outposts:
		outpost.guards = outpost.guards.filter(alive)
	look_around()
	var threats := threats_near(home)
	if not threats.is_empty():
		last_threat = elapsed
	manage_workers(home, threats)
	train(home)
	if not build(home):
		upgrade_buildings()
	expand(home)
	if Global.can_evolve(TEAM):
		Global.evolve_townhall(TEAM)
	send_wounded_home(home)
	explore()
	scout_with_worker(home)
	if not threats.is_empty():
		defend(threats)
	elif aggressive():
		attack(home)
		raid(home)
	guard_outposts()


func alive(node) -> bool:
	return is_instance_valid(node) and not node.dying


func world() -> Node:
	return get_parent()


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


func is_guard(unit) -> bool:
	return outposts.any(func(outpost): return outpost.guards.has(unit))


func idle_army() -> Array:
	return army().filter(func(unit): return unit != scout and not attackers.has(unit) and not raiders.has(unit) and not gathering.has(unit) and not is_guard(unit) and not unit.moving and unit.get_node("Attacker").target == null and not is_wounded(unit))


func home_spot(home: Townhall) -> Vector2:
	return home.global_position + Vector2(randf_range(-150.0, 150.0), 220.0)


func in_player_base(pos: Vector2) -> bool:
	var player_home := find_townhall("player")
	return player_home != null and pos.distance_to(player_home.global_position) < difficulty.safe_radius


func aggressive() -> bool:
	return own("buildings").any(func(building): return building.has_node("Trainer") and not building is Townhall and building.level >= difficulty.aggressive_level)


func scout_with_worker(home: Townhall) -> void:
	if worker_scout and not alive(worker_scout):
		worker_scout = null
	if worker_scout:
		if not worker_scout.moving:
			worker_scout.move_to(home_spot(home))
			worker_scout = null
		return
	if elapsed < next_worker_scout or workers().size() < 3:
		return
	next_worker_scout = elapsed + difficulty.worker_scout_interval
	var unexplored: Array = world().cluster_centers.filter(func(center): return not explored.has(center))
	if unexplored.is_empty():
		return
	worker_scout = closest(workers(), home.global_position)
	worker_scout.move_to(unexplored.pick_random())


func look_around() -> void:
	known = known.filter(func(building): return is_instance_valid(building) and building.is_in_group("buildings"))
	var eyes := own("unit") + own("buildings")
	for center in world().cluster_centers:
		if not explored.has(center) and eyes.any(func(eye): return eye.global_position.distance_to(center) < 500.0):
			explored.append(center)
	for building in get_tree().get_nodes_in_group("buildings"):
		if building.team != "player" or building.get("preview") or known.has(building):
			continue
		if eyes.any(func(eye): return eye.global_position.distance_to(building.global_position) < difficulty.spot_range):
			known.append(building)


func explore() -> void:
	if elapsed < difficulty.scout_after:
		return
	if scout == null:
		var idle := idle_army()
		if idle.is_empty():
			return
		idle.sort_custom(func(a, b): return a.Speed > b.Speed)
		scout = idle[0]
	if scout.moving or scout.get_node("Attacker").target != null:
		return
	var unexplored: Array = world().cluster_centers.filter(func(center): return not explored.has(center) and not in_player_base(center))
	if unexplored.is_empty():
		explored.clear()
		return
	var next: Vector2 = unexplored[0]
	for center in unexplored:
		if scout.global_position.distance_to(center) < scout.global_position.distance_to(next):
			next = center
	scout.move_to(next)


func expand(home: Townhall) -> void:
	if elapsed < next_expand:
		return
	var limit: int = Global.economy(TEAM).townhall_level * difficulty.outposts_per_level
	if outposts.size() >= limit:
		return
	var cost := cost_of(difficulty.tower_scene)
	if not Global.can_afford(cost, TEAM):
		return
	var best := Vector2.INF
	for center in explored:
		if in_player_base(center) or center.distance_to(home.global_position) < 900.0:
			continue
		if outposts.any(func(outpost): return outpost.center.distance_to(center) < difficulty.outpost_radius):
			continue
		if known.any(func(building): return building.global_position.distance_to(center) < difficulty.outpost_radius):
			continue
		if best == Vector2.INF or center.distance_to(home.global_position) < best.distance_to(home.global_position):
			best = center
	if best == Vector2.INF:
		return
	var tower := place(difficulty.tower_scene, best, 200.0, 380.0)
	if tower:
		outposts.append({"center": best, "tower": tower, "guards": []})
		next_expand = elapsed + difficulty.expand_interval


func guard_outposts() -> void:
	for outpost in outposts:
		while outpost.guards.size() < difficulty.outpost_guards:
			var idle := idle_army()
			if idle.is_empty():
				return
			var guard = closest(idle, outpost.center)
			outpost.guards.append(guard)
			guard.move_to(outpost.center + Vector2(randf_range(-150.0, 150.0), randf_range(-150.0, 150.0)))
		for guard in outpost.guards:
			if not guard.moving and guard.get_node("Attacker").target == null and guard.global_position.distance_to(outpost.center) > 350.0:
				guard.move_to(outpost.center + Vector2(randf_range(-150.0, 150.0), randf_range(-150.0, 150.0)))


func threats_near(home: Townhall) -> Array:
	return player_units().filter(func(unit): return in_territory(unit.global_position, home))


func in_territory(pos: Vector2, home: Townhall) -> bool:
	if pos.distance_to(home.global_position) <= difficulty.defend_radius:
		return true
	return outposts.any(func(outpost): return pos.distance_to(outpost.center) <= difficulty.outpost_radius)


func defend(threats: Array) -> void:
	var defenders := army().filter(func(unit): return unit != scout and not attackers.has(unit) and not raiders.has(unit) and not is_wounded(unit))
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
			for outpost in outposts:
				outpost.guards.erase(unit)
			if unit == scout:
				scout = null
			unit.move_to(home_spot(home))


func retreat(units: Array, home: Townhall) -> void:
	for unit in units:
		unit.move_to(home_spot(home))


func manage_workers(home: Townhall, threats: Array) -> void:
	for worker in workers():
		if worker == worker_scout:
			continue
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
		if in_player_base(resource.global_position):
			continue
		var distance: float = worker.global_position.distance_to(resource.global_position)
		if resource.resource_name == wanted:
			distance *= 0.5
		if outposts.any(func(outpost): return outpost.center.distance_to(resource.global_position) < difficulty.outpost_radius):
			distance *= 0.7
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


func build(home: Townhall) -> bool:
	var scene := next_building()
	if scene:
		place(scene, home.global_position, 350.0, 750.0)
	return scene != null


func upgrade_buildings() -> void:
	var options := own("buildings").filter(func(building): return building.has_method("can_upgrade") and building.can_upgrade())
	if options.is_empty():
		return
	options.sort_custom(func(a, b): return upgrade_priority(a) < upgrade_priority(b))
	options[0].upgrade()


func upgrade_priority(building) -> int:
	var priority: int = building.level * 10
	if building.has_node("Trainer"):
		priority -= 5
	elif building.stats.product:
		priority -= 3
	return priority


func place(scene: PackedScene, around: Vector2, near: float, far: float) -> Node2D:
	var cost := cost_of(scene)
	if not Global.can_afford(cost, TEAM):
		return null
	for attempt in 20:
		var spot := around + Vector2.from_angle(randf() * TAU) * randf_range(near, far)
		if world().can_place_at(spot) and Global.spend(cost, TEAM):
			var building = scene.instantiate()
			building.team = TEAM
			building.position = spot
			world().get_node("Objects").add_child(building)
			Global.add_xp(Global.XP_PER_BUILD, TEAM)
			return building
	return null


func next_building() -> PackedScene:
	var economy := Global.economy(TEAM)
	var level := economy.townhall_level
	if economy.populus + Global.queued_troops(TEAM) >= economy.maxPopulus - 1 and Global.can_build(stats_of(difficulty.house_scene), TEAM):
		return difficulty.house_scene
	if economy.food < 10 and count(difficulty.farm_scene) < level + 1:
		return difficulty.farm_scene
	for scene in difficulty.military_scenes.slice(0, level + 1):
		if count(scene) == 0:
			return scene
	if (not aggressive() or elapsed - last_threat < 60.0) and count(difficulty.tower_scene) - outposts.size() < level:
		return difficulty.tower_scene
	if count(difficulty.farm_scene) < level + 1:
		return difficulty.farm_scene
	return null


func count(scene: PackedScene) -> int:
	return own("buildings").filter(func(building): return building.scene_file_path == scene.resource_path).size()


func cost_of(scene: PackedScene) -> Dictionary:
	return stats_of(scene).cost


func stats_of(scene: PackedScene) -> BuildingStats:
	if not build_costs.has(scene):
		var probe = scene.instantiate()
		build_costs[scene] = probe.stats
		probe.free()
	return build_costs[scene]


func attack(home: Townhall) -> void:
	var middle: Vector2 = world().map_size / 2.0
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
					send(unit, pick_target(unit.global_position, false), middle)
	var rally := home.global_position + home.global_position.direction_to(middle) * difficulty.rally_distance
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
			send(unit, pick_target(unit.global_position, false), middle)
		attackers += gathering
		wave_launch_size = gathering.size()
		wave_size += difficulty.wave_growth
		next_wave = elapsed + difficulty.wave_cooldown
		gathering = []


func send(unit, target: Node2D, fallback: Vector2) -> void:
	if target:
		unit.moving = false
		unit.get_node("Attacker").target = target
	elif unit.global_position.distance_to(fallback) > 400.0:
		unit.move_to(fallback + Vector2(randf_range(-200.0, 200.0), randf_range(-200.0, 200.0)))


func raid(home: Townhall) -> void:
	if raiders.any(func(raider): return outnumbered(raider)):
		retreat(raiders, home)
		raiders.clear()
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


func outnumbered(raider) -> bool:
	var fighters := player_units().filter(func(unit): return not unit.stats.can_gather and unit.global_position.distance_to(raider.global_position) < 450.0)
	return fighters.size() > raiders.size()


func pick_target(from: Vector2, economy_only: bool) -> Node2D:
	var siege := aggressive()
	var best: Node2D = null
	var best_score := INF
	for group in ["unit", "buildings"]:
		for other in get_tree().get_nodes_in_group(group):
			if other.team != "player" or other.get("preview") or other.get("dying"):
				continue
			if group == "buildings" and not known.has(other):
				continue
			if not siege and not economy_only and in_player_base(other.global_position):
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
