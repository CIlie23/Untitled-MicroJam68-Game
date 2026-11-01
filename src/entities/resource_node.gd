class_name ResourceNode
extends StaticBody2D

# this exists because we need a common
# file to store shared scripts, particular
#  logic will be stored in respective gd files
@export var resource_name := "Wood"
@export var item: Item

var totalTime
var yieldAmount
var currTime
var gatherers: Array = []

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
	var active := active_gatherers()
	bar.visible = not active.is_empty()
	if active.is_empty():
		timer.stop()
	elif timer.is_stopped():
		timer.start()
	bar.value = currTime
	if currTime <= 0:
		depleted()

func active_gatherers() -> Array:
	return gatherers.filter(func(unit): return is_instance_valid(unit) and unit.stats.can_gather and unit.inventory.space_for(item) > 0)


func _on_gather_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("unit"):
		gatherers.append(body)

func _on_gather_area_body_exited(body: Node2D) -> void:
	gatherers.erase(body)


func _on_timer_timeout() -> void:
	var gatherSpeed = 1 * active_gatherers().size() #more units around it, faster it goes
	currTime -= gatherSpeed
	var tween = get_tree().create_tween()
	tween.tween_property(bar, "value", currTime, 0.5).set_trans(Tween.TRANS_LINEAR)

func depleted():
	set_process(false)
	share_yield(active_gatherers())
	var burst := $GatherBurst as CPUParticles2D
	burst.reparent(get_parent())
	burst.emitting = true
	queue_free()

func share_yield(receivers: Array) -> void:
	if receivers.is_empty():
		return
	var leftover := 0
	for i in receivers.size():
		@warning_ignore("integer_division")
		var share: int = yieldAmount / receivers.size() + (1 if i < yieldAmount % receivers.size() else 0)
		leftover += receivers[i].inventory.add(item, share)
	for unit in receivers:
		if leftover > 0:
			leftover = unit.inventory.add(item, leftover)
