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

var target: Vector2
var moving := false
var stuck_time := 0.0
var dying := false
var Speed = Global.UNIT_SPEED
var health: int:
	get:
		return $Health.current

func _ready() -> void:
	$Health.setup(max_health(), defense())
	Speed = stats.speed * speed_multiplier
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
	$Attacker.sight = maxf(stats.attack_range + 250.0, 350.0)
	$Vision.radius = maxf($Vision.radius, stats.attack_range + 100.0)
	set_selected(selected)

func _process(_delta: float) -> void:
	if dying or (sprite.animation in [&"attack", &"hurt"] and sprite.is_playing()):
		return
	var animation := &"walk" if velocity.length() > 1.0 else &"idle"
	if sprite.animation != animation:
		sprite.play(animation)
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0

func apply_size(size: float) -> void:
	sprite.scale *= size
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
	return Global.economy(team).gather_rate

func portrait_texture() -> Texture2D:
	return sprite.sprite_frames.get_frame_texture(&"idle", 0)

func move_to(pos: Vector2) -> void:
	$Attacker.target = null
	target = pos
	moving = true
	stuck_time = 0.0

func max_health() -> int:
	return roundi(stats.max_health * level_multiplier())

func damage() -> int:
	return roundi(stats.damage * level_multiplier())

func defense() -> int:
	return roundi(stats.defense * level_multiplier())

func set_selected(value):
	selected = value
	box.visible = value

# One right-click sets the destination. No need to hold.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("RightClick") and selected:
		var enemy = get_tree().current_scene.enemy_at(get_global_mouse_position(), team)
		if enemy and $Attacker.active():
			$Attacker.target = enemy
			moving = false
		else:
			move_to(get_global_mouse_position())

func _physics_process(delta: float) -> void:
	if not moving:
		var foe = $Attacker.target
		if is_instance_valid(foe) and not $Attacker.in_reach(foe):
			velocity = global_position.direction_to(foe.global_position) * Speed
			move_and_slide()
		else:
			velocity = Vector2.ZERO
		return
	if global_position.distance_to(target) <= 15:
		velocity = Vector2.ZERO
		moving = false
		#anim stop
		return
	velocity = global_position.direction_to(target) * Speed
	move_and_slide()
	stuck_time = stuck_time + delta if get_real_velocity().length() < Speed * 0.1 else 0.0
	if stuck_time > 0.75:
		moving = false
	#play walk anim

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
	get_tree().current_scene.get_units()

func _on_sprite_animation_finished() -> void:
	if sprite.animation == &"death":
		queue_free()
	else:
		sprite.play(&"idle")
