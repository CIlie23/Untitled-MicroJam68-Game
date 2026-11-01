extends CharacterBody2D

@export var selected:bool = false
@onready var box: Panel = $Box

var target: Vector2
var moving := false
var Speed = Global.UNIT_SPEED

func _ready() -> void:
	set_selected(selected)
	
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
