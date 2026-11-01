extends Node2D

@export var speed := 900.0

var target: Node2D
var damage := 0
var team := ""
var aim := Vector2.ZERO
var era := 1


func _ready() -> void:
	aim = target.global_position
	$Sprite2D.frame = clampi(era - 1, 0, $Sprite2D.hframes - 1)


func _process(delta: float) -> void:
	if is_instance_valid(target):
		aim = target.global_position
	var to := aim - global_position
	rotation = to.angle()
	if to.length() <= speed * delta:
		if is_instance_valid(target):
			target.get_node("Health").take_damage(damage, team)
		queue_free()
	else:
		global_position += to.normalized() * speed * delta
