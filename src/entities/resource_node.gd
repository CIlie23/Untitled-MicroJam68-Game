class_name ResourceNode
extends StaticBody2D

# this exists because we need a common 
# file to store shared scripts, particular
#  logic will be stored in respective gd files
@export var resource_name := "Wood"

var totalTime
var yieldAmount
var currTime
var units = 0

@onready var timer: Timer = $Timer
@onready var bar: ProgressBar = $ProgressBar


func _enter_tree() -> void:
	add_to_group(&"resources")

func _ready() -> void:
	totalTime = Global.RESOURCES[resource_name].gather_time
	yieldAmount = Global.RESOURCES[resource_name].amount.pick_random()
	currTime = totalTime
	bar.max_value = totalTime

func _process(delta: float) -> void:
	bar.value = currTime
	if currTime <= 0:
		depleted()


func _on_gather_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("unit"):
		units += 1
		startGathering()

func _on_gather_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("unit"):
		units -= 1
		if units <= 0:
			timer.stop()


func _on_timer_timeout() -> void:
	var gatherSpeed = 1 * units #more units around it, faster it goes
	currTime -= gatherSpeed
	var tween = get_tree().create_tween()
	tween.tween_property(bar, "value", currTime, 0.5).set_trans(Tween.TRANS_LINEAR)

func startGathering():
	if timer.is_stopped():
		timer.start()

func depleted():
	Global.set(resource_name, Global.get(resource_name) + yieldAmount)
	queue_free()
