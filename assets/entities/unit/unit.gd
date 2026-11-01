extends CharacterBody2D

signal stage_changed(stage: int)

@export var selected:bool = false
@export var stats: TroopStats
@export var inventory: Inventory
@export var stage := 0
@export var level := 1
@export var speed_multiplier := 1.0
@onready var box: Panel = $Box
@onready var sprite: Sprite2D = $Sprite2D

var target: Vector2
var moving := false
var Speed = Global.UNIT_SPEED
var health := 0

func _ready() -> void:
	health = max_health()
	Speed = stats.speed * speed_multiplier
	sprite.modulate = stats.tint
	set_stage(stage)
	set_selected(selected)

func level_multiplier() -> float:
	return 1.0 + Global.TROOP_BONUS_PER_LEVEL * (level - 1)

func max_health() -> int:
	return roundi(stats.max_health * level_multiplier())

func damage() -> int:
	return roundi(stats.damage * level_multiplier())

func defense() -> int:
	return roundi(stats.defense * level_multiplier())

func set_stage(value: int) -> void:
	stage = clampi(value, 0, maxi(stats.stage_sprites.size() - 1, 0))
	if stage < stats.stage_sprites.size() and stats.stage_sprites[stage]:
		sprite.texture = stats.stage_sprites[stage]
	stage_changed.emit(stage)

func can_evolve() -> bool:
	return stage < stats.stage_sprites.size() - 1

func evolve() -> void:
	if can_evolve():
		set_stage(stage + 1)
	
func set_selected(value):
	selected = value
	box.visible = value

# One right-click sets the destination. No need to hold.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("RightClick") and selected:
		target = get_global_mouse_position()
		moving = true

func _physics_process(delta: float) -> void:
	if not moving:
		velocity = Vector2.ZERO
		return
	if global_position.distance_to(target) <= 15:
		velocity = Vector2.ZERO
		moving = false
		#anim stop
		return
	velocity = global_position.direction_to(target) * Speed
	move_and_slide()
	#play walk anim
