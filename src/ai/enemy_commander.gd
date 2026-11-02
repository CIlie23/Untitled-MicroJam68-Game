class_name EnemyCommander
extends Node

const TEAM := "enemy"

@export var difficulty: AIDifficulty
@export var difficulties: Array[AIDifficulty] = []

var elapsed := 0.0
var think_in := 0.0
var wave_launch_size := 0
var attackers: Array = []
var gathering: Array = []
var gather_started := 0.0
var raiders: Array = []
var next_raid := 0.0
var next_wave := 0.0
var next_expand := 0.0
var last_threat := -INF
var threat_point := Vector2.ZERO
var build_costs := {}
var scout: Node2D
var worker_scout: Node2D
var next_worker_scout := 0.0
var explored: Array[Vector2] = []
var known: Array = []
var outposts: Array = []


func _ready() -> void:
	if difficulties.size() > Settings.ai_difficulty:
		difficulty = difficulties[Settings.ai_difficulty]
	Global.economy(TEAM).apply_difficulty(difficulty)
	Global.economy(TEAM).food += difficulty.starting_food
	next_raid = difficulty.first_raid_delay
	next_wave = difficulty.first_attack_delay
	next_expand = difficulty.expand_interval
	next_worker_scout = difficulty.worker_scout_interval


func _process(delta: float) -> void:
	elapsed += delta
	think_in -= delta
	if think_in > 0.0:
		return
	think_in = difficulty.think_interval * (0.5 if under_pressure() and difficulty.emergency_builds else 1.0)
	var home := townhall()
	if home == null:
		return
	attackers = attackers.filter(alive)
	gathering = gathering.filter(alive)
	raiders = raiders.filter(alive)
	if scout and not alive(scout):
		scout = null
	outposts = outposts.filter(func(outpost): return not known.any(func(building): return is_instance_valid(building) and building.global_position.distance_to(outpost.center) < difficulty.outpost_radius * 0.5))
	for outpost in outposts:
		outpost.guards = outpost.guards.filter(alive)
		if not is_instance_valid(outpost.tower):
			outpost.tower = null
	look_around()
	var threats := threats_near(home)
	var siege := under_siege(home, threats)
	if not threats.is_empty():
		last_threat = elapsed
		threat_point = closest(threats, home.global_position).global_position
	manage_workers(home, threats, siege and outmatched(threats))
	train(home)
	if not build(home):
		upgrade_buildings()
	expand(home)
	if Global.can_evolve(TEAM):
		Global.evolve_townhall(TEAM)
	send_wounded_home(home)
	explore()
	scout_with_worker(home)
	call_off_chases(home)
	if not threats.is_empty():
		defend(threats, home, siege)
	else:
		raid(home)
		if Global.economy(TEAM).townhall_level >= difficulty.wave_level:
			attack(home)
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
	return level() >= difficulty.aggressive_level


func wave_size() -> int:
	return difficulty.wave_size + difficulty.wave_growth * maxi(level() - difficulty.wave_level, 0)


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
	var player_home := find_townhall("player")
	if player_home and not known.has(player_home):
		known.append(player_home)
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
	if level() >= difficulty.wave_level:
		scout = null
		return
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
	for outpost in outposts:
		if outpost.tower == null:
			var rebuilt := place(difficulty.tower_scene, outpost.center, 200.0, 380.0)
			if rebuilt:
				outpost.tower = rebuilt
			return
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
	var eyes := own("buildings").filter(func(building): return building.has_node("Vision"))
	return player_units().filter(func(unit): return in_territory(unit.global_position, home) or seen_by(eyes, unit.global_position))


func seen_by(eyes: Array, pos: Vector2) -> bool:
	return eyes.any(func(eye): return eye.global_position.distance_to(pos) <= eye.get_node("Vision").radius)


func under_siege(home: Townhall, threats: Array) -> bool:
	var sight: float = home.get_node("Vision").radius
	return threats.any(func(threat): return threat.global_position.distance_to(home.global_position) <= sight)


func under_pressure() -> bool:
	return elapsed - last_threat < 30.0


func outmatched(threats: Array) -> bool:
	return army().filter(func(unit): return not is_wounded(unit)).size() < threats.size()


func in_territory(pos: Vector2, home: Townhall, margin := 0.0) -> bool:
	if pos.distance_to(home.global_position) <= difficulty.defend_radius + margin:
		return true
	return outposts.any(func(outpost): return pos.distance_to(outpost.center) <= difficulty.outpost_radius + margin)


func call_off_chases(home: Townhall) -> void:
	for unit in army():
		if unit == scout or attackers.has(unit) or raiders.has(unit) or gathering.has(unit):
			continue
		var foe = unit.get_node("Attacker").target
		if foe and not in_territory(foe.global_position, home, difficulty.pursuit_range):
			unit.move_to(home_spot(home))


func defend(threats: Array, home: Townhall, siege: bool) -> void:
	var defenders := army().filter(func(unit): return not is_wounded(unit) and (siege or (unit != scout and not attackers.has(unit) and not raiders.has(unit))))
	if siege:
		attackers.clear()
		raiders.clear()
		scout = null
		for outpost in outposts:
			outpost.guards.clear()
		if difficulty.workers_defend and outmatched(threats):
			var sight: float = home.get_node("Vision").radius
			defenders += workers().filter(func(worker): return worker != worker_scout and worker.global_position.distance_to(home.global_position) <= sight)
	gathering.clear()
	for unit in defenders:
		unit.moving = false
		unit.get_node("Attacker").target = closest(threats, unit.global_position)


func send_wounded_home(home: Townhall) -> void:
	if not difficulty.retreats:
		return
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


func manage_workers(home: Townhall, threats: Array, militia: bool) -> void:
	for worker in workers():
		if worker == worker_scout:
			continue
		if militia and worker.get_node("Attacker").target != null:
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
			worker.move_to(job.global_position)


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
		if army().size() + Global.queued_troops(TEAM) < army_cap():
			trainer.train()


func build(home: Townhall) -> bool:
	var wanted := false
	for attempt in difficulty.builds_per_think:
		var scene := next_building()
		if scene == null:
			break
		wanted = true
		var placed: Node2D
		if scene == difficulty.tower_scene and under_pressure():
			placed = place(scene, home.global_position.move_toward(threat_point, 450.0), 0.0, 250.0)
		else:
			placed = place(scene, home.global_position, 350.0, 800.0)
		if placed == null:
			break
	return wanted


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
			return building
	return null


func next_building() -> PackedScene:
	var economy := Global.economy(TEAM)
	var level := economy.townhall_level
	var house := stats_of(difficulty.house_scene)
	if under_pressure() and difficulty.emergency_builds:
		for scene in difficulty.military_scenes.slice(0, level + 1):
			if count(scene) == 0:
				return scene
		if home_towers() < level + 1:
			return difficulty.tower_scene
	if economy.populus + Global.queued_troops(TEAM) >= economy.maxPopulus - 1 and not constructing(difficulty.house_scene) and Global.can_build(house, TEAM):
		return difficulty.house_scene
	if economy.food < 15 and count(difficulty.farm_scene) < level + 2:
		return difficulty.farm_scene
	for scene in difficulty.military_scenes.slice(0, level + 1):
		if count(scene) == 0:
			return scene
	if home_towers() < level + 1:
		return difficulty.tower_scene
	if Global.can_build(house, TEAM):
		return difficulty.house_scene
	if count(difficulty.farm_scene) < level + 2:
		return difficulty.farm_scene
	return null


func constructing(scene: PackedScene) -> bool:
	return own("buildings").any(func(building): return building.scene_file_path == scene.resource_path and not building.get("built"))


func home_towers() -> int:
	return count(difficulty.tower_scene) - outposts.filter(func(outpost): return outpost.tower != null).size()


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
	var enemy_home := find_townhall("player")
	if enemy_home == null:
		return
	if not attackers.is_empty():
		var center := Vector2.ZERO
		for unit in attackers:
			center += unit.global_position
		center /= attackers.size()
		var defenders := player_units().filter(func(unit): return unit.global_position.distance_to(center) < 700.0)
		if difficulty.retreats and (defenders.size() > attackers.size() * 1.5 or attackers.size() <= maxi(1, roundi(wave_launch_size * 0.3))):
			retreat(attackers, home)
			attackers.clear()
		else:
			for unit in attackers:
				var target = unit.get_node("Attacker").target
				var tower := shooter_near(unit.global_position) if difficulty.targets_towers else null
				if tower and (target == null or target == enemy_home):
					send(unit, tower)
				elif not unit.moving and target == null:
					send(unit, enemy_home)
	var rally := home.global_position + home.global_position.direction_to(enemy_home.global_position) * difficulty.rally_distance
	if gathering.is_empty():
		if elapsed < next_wave:
			return
		var idle := idle_army()
		if idle.size() < wave_size():
			return
		idle.sort_custom(func(a, b): return a.global_position.distance_to(rally) < b.global_position.distance_to(rally))
		gathering = idle.slice(0, wave_size())
		gather_started = elapsed
		if not difficulty.uses_rally:
			gather_started = -INF
			return
		for unit in gathering:
			unit.move_to(rally + Vector2(randf_range(-120.0, 120.0), randf_range(-120.0, 120.0)))
		return
	var arrived := gathering.filter(func(unit): return unit.global_position.distance_to(rally) < 300.0)
	if arrived.size() >= gathering.size() * 0.8 or elapsed - gather_started > 20.0:
		for unit in gathering:
			send(unit, enemy_home)
		attackers += gathering
		wave_launch_size = gathering.size()
		next_wave = elapsed + difficulty.wave_cooldown
		gathering = []


func send(unit, target: Node2D) -> void:
	unit.moving = false
	unit.get_node("Attacker").target = target


func shooter_near(pos: Vector2) -> Node2D:
	var towers := get_tree().get_nodes_in_group("buildings").filter(func(building): return building.team == "player" and not building.get("preview") and not building is Townhall and building.has_node("Attacker") and not building.has_node("Trainer"))
	var tower := closest(towers, pos)
	return tower if tower and tower.global_position.distance_to(pos) < 500.0 else null


func raid(home: Townhall) -> void:
	if difficulty.retreats and raiders.any(func(raider): return outnumbered(raider)):
		retreat(raiders, home)
		raiders.clear()
	var enemy_home := find_townhall("player")
	for unit in raiders.duplicate():
		var current = unit.get_node("Attacker").target
		if current != null and not current is Townhall:
			continue
		var target := raid_target(unit.global_position)
		if target:
			send(unit, target)
		elif enemy_home and unit.global_position.distance_to(enemy_home.global_position) < 700.0:
			raiders.erase(unit)
			unit.move_to(home_spot(home))
		elif enemy_home and not unit.moving:
			unit.move_to(enemy_home.global_position.move_toward(home.global_position, 500.0))
	if level() > difficulty.raid_until_level or elapsed < next_raid or enemy_home == null:
		return
	next_raid = elapsed + difficulty.raid_interval
	var party := raid_size()
	var idle := idle_army()
	if idle.size() < party:
		return
	idle.sort_custom(func(a, b): return a.Speed > b.Speed)
	for unit in idle.slice(0, party):
		raiders.append(unit)
		var target := raid_target(unit.global_position)
		if target:
			send(unit, target)
		else:
			unit.move_to(enemy_home.global_position.move_toward(home.global_position, 500.0))


func raid_target(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	for other in get_tree().get_nodes_in_group("unit"):
		if other.team == "player" and other.stats.can_gather and not other.dying:
			var score := from.distance_to(other.global_position) * 0.7
			if score < best_score:
				best = other
				best_score = score
	for other in known:
		if other is Townhall or other.get("preview"):
			continue
		var score := from.distance_to(other.global_position) * sabotage_weight(other)
		if score < best_score:
			best = other
			best_score = score
	return best


func sabotage_weight(building) -> float:
	if not building.get("built"):
		return 0.4
	if building.stats.product:
		return 0.6
	if building.stats.population:
		return 0.7
	if building.has_node("Trainer"):
		return 0.8
	return 2.0


func level() -> int:
	return Global.economy(TEAM).townhall_level


func army_cap() -> int:
	return difficulty.army_cap + difficulty.army_cap_per_level * (level() - 1)


func raid_size() -> int:
	return difficulty.raid_size + difficulty.raid_growth_per_level * (level() - 1)


func outnumbered(raider) -> bool:
	var fighters := player_units().filter(func(unit): return not unit.stats.can_gather and unit.global_position.distance_to(raider.global_position) < 450.0)
	return fighters.size() > raiders.size()
