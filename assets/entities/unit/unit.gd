extends CharacterBody2D

@export var selected:bool = false
@onready var box: Panel = $Box

var target: Vector2 = Vector2.ZERO
var follow_cursor = false
var Speed = 550

func _ready() -> void:
	set_selected(selected)
	
func set_selected(value):
	selected = value
	box.visible = value

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("RightClick"):
		follow_cursor = true
	if event.is_action_released("RightClick"):
		follow_cursor = false

func _physics_process(delta: float) -> void:
	if follow_cursor and selected:
		target = get_global_mouse_position()
		velocity = global_position.direction_to(target) * Speed
		if global_position.distance_to(target) > 15:
			move_and_slide()
			#play walk anim
		else:
			velocity = Vector2.ZERO
			#anim stop
	else:
		velocity = Vector2.ZERO
