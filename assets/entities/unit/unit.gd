extends CharacterBody2D

@export var selected:bool = false
@export var team := "player"
@export var hit_radius := 45.0
@export var stats: TroopStats
@export var inventory: Inventory
@export var level := 1
@export var speed_multiplier := 1.0
@onready var box: Panel = $Box
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var agent: NavigationAgent2D = $Agent

var target: Vector2
var moving := false
var stuck_time := 0.0
var steering := false
var mining_until := 0
var mining_at := Vector2.ZERO
var dying := false
var Speed = Global.UNIT_SPEED
var health: int:
	get:
		return $Health.current

func _ready() -> void:
	$Health.setup(max_health(), defense())
	Speed = stats.speed * speed_multiplier
	agent.max_speed = Speed
	var looks := frames_for_team()
	var enemy_frames: bool = team == "enemy" and looks.enemy
	if looks.frames:
		sprite.sprite_frames = looks.frames
	sprite.modulate = stats.tint * (Global.ENEMY_TINT if team == "enemy" and not enemy_frames else Color.WHITE)
	sprite.play(&"idle")
	apply_size(stats.size)
	$Attacker.attack_range = stats.attack_range
	$Attacker.cooldown = stats.attack_cooldown
	$Attacker.ranged = stats.ranged
	$Attacker.damage = damage()
	$Attacker.sight = stats.attack_range + 60.0 if stats.can_gather else maxf(stats.attack_range + 250.0, 350.0)
	$Vision.radius = maxf($Vision.radius, stats.attack_range + 100.0)
	set_selected(selected)

func _process(_delta: float) -> void:
	if dying or (sprite.animation in [&"attack", &"hurt"] and sprite.is_playing()):
		return
	if is_mining():
		sprite.flip_h = mining_at.x < global_position.x
		sprite.play(&"attack")
		return
	var animation := &"walk" if velocity.length() > 1.0 else &"idle"
	if sprite.animation != animation:
		sprite.play(animation)
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0

func mine(at: Vector2) -> void:
	mining_at = at
	mining_until = Time.get_ticks_msec() + 200

func is_mining() -> bool:
	return not moving and Time.get_ticks_msec() < mining_until and $Attacker.target == null

func apply_size(size: float) -> void:
	sprite.scale *= size
	agent.radius *= size
	$CollisionShape2D.scale *= size
	$CollisionShape2D.position *= size
	hit_radius *= size
	for control: Control in [box, $Health]:
		control.offset_left *= size
		control.offset_top *= size
		control.offset_right *= size
		control.offset_bottom *= size

func frames_for_team() -> Dictionary:
	var by_level := stats.enemy_level_frames if team == "enemy" else stats.level_frames
	if not by_level.is_empty():
		return {"frames": by_level[clampi(level - 1, 0, by_level.size() - 1)], "enemy": team == "enemy"}
	if team == "enemy" and stats.enemy_frames:
		return {"frames": stats.enemy_frames, "enemy": true}
	return {"frames": stats.frames, "enemy": false}

func level_multiplier() -> float:
	return (1.0 + Global.TROOP_BONUS_PER_LEVEL * (level - 1)) * Global.economy(team).stat_multiplier

func gather_rate() -> float:
	return Global.economy(team).gather_multiplier()

func portrait_texture() -> Texture2D:
	return sprite.sprite_frames.get_frame_texture(&"idle", 0)

func move_to(pos: Vector2) -> void:
	$Attacker.target = null
	target = pos
	agent.target_position = pos
	moving = true
	stuck_time = 0.0

func max_health() -> int:
	return roundi(stats.max_health * level_multiplier())

func damage() -> int:
	return roundi(stats.damage * level_multiplier())

func defense() -> int:
	return roundi(stats.defense * level_multiplier())

func set_selected(value):
	if value and not selected and team == "player":
		Audio.say(Audio.SELECT_VOICES)
	selected = value
	box.visible = value

# One right-click sets the destination. No need to hold.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("RightClick") and selected:
		var enemy = get_tree().current_scene.enemy_at(get_global_mouse_position(), team)
		if enemy and $Attacker.active():
			$Attacker.target = enemy
			moving = false
			Audio.say(Audio.ATTACK_VOICES)
		else:
			var squad := get_tree().get_nodes_in_group("unit").filter(func(unit): return unit.selected)
			move_to(get_global_mouse_position() + formation_slot(squad.find(self), squad.size()))
			Audio.say(Audio.WALK_VOICES)

func _physics_process(delta: float) -> void:
	watch_idle()
	if not moving:
		var foe = $Attacker.target
		if is_instance_valid(foe) and not $Attacker.in_reach(foe):
			if agent.target_position.distance_to(foe.global_position) > 40.0:
				agent.target_position = foe.global_position
			steer()
		else:
			velocity = Vector2.ZERO
		return
	if global_position.distance_to(target) <= 15 or agent.is_navigation_finished():
		velocity = Vector2.ZERO
		moving = false
		#anim stop
		return
	steer()
	stuck_time = stuck_time + delta if get_real_velocity().length() < Speed * 0.1 else 0.0
	if stuck_time > 1.5:
		moving = false
	#play walk anim

func steer() -> void:
	var next := agent.target_position if agent.is_navigation_finished() else agent.get_next_path_position()
	steering = true
	agent.velocity = global_position.direction_to(next) * Speed

func _on_agent_velocity_computed(safe_velocity: Vector2) -> void:
	if not steering or dying:
		return
	steering = false
	velocity = safe_velocity
	move_and_slide()

static func formation_slot(index: int, count: int, spacing := 95.0) -> Vector2:
	var columns := ceili(sqrt(count))
	var rows := ceili(float(count) / columns)
	var cell := Vector2(index % columns, floori(float(index) / columns))
	return (cell - Vector2(columns - 1, rows - 1) / 2.0) * spacing

func _on_attacker_attacked(foe: Node2D) -> void:
	if dying:
		return
	sprite.flip_h = foe.global_position.x < global_position.x
	sprite.play(&"attack")

func _on_health_damaged(_amount: int) -> void:
	if not dying and sprite.animation != &"attack":
		sprite.play(&"hurt")

func _on_health_died(killer_team: String) -> void:
	Global.credit_kill(killer_team)
	Global.economy(team).populus -= 1
	dying = true
	set_selected(false)
	remove_from_group("unit")
	set_physics_process(false)
	$Attacker.set_process(false)
	$Health.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.play(&"death")
	$DeathVoice.play()
	get_tree().current_scene.get_units()

func watch_idle() -> void:
	var idle: bool = stats.can_gather and not moving and $Attacker.target == null
	if not idle:
		$IdleTimer.stop()
	elif $IdleTimer.is_stopped():
		$IdleTimer.start()

func _on_idle_timer_timeout() -> void:
	for resource in get_tree().get_nodes_in_group("resources"):
		if resource.active_gatherers().has(self):
			return
	for building in get_tree().get_nodes_in_group("buildings"):
		if building is Townhall and building.team == team and global_position.distance_to(building.global_position) > 300.0:
			move_to(building.global_position + Vector2(randf_range(-80.0, 80.0), 200.0))

func _on_sprite_animation_finished() -> void:
	if sprite.animation == &"death":
		if $DeathVoice.playing:
			await $DeathVoice.finished
		queue_free()
	elif is_mining():
		sprite.play(&"attack")
	else:
		sprite.play(&"idle")
