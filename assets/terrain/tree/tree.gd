extends StaticBody2D

var totalTime = 5
var currTime
var units = 0

@onready var timer: Timer = $Timer
@onready var bar: ProgressBar = $ProgressBar


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	currTime = totalTime
	bar.max_value = totalTime

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	bar.value = currTime
	if currTime <= 0:
		treeChopped()


func _on_chop_area_body_entered(body: Node2D) -> void:
	if "Unit" in body.name:
		units += 1
		startChopping()

func _on_chop_area_body_exited(body: Node2D) -> void:
	if "Unit" in body.name:
		units -= 1
		if units <= 0:
			timer.stop()


func _on_timer_timeout() -> void:
	var chopSpeed = 1 * units #more units round the tree, faster it goes
	currTime -= chopSpeed
	var tween = get_tree().create_tween()
	tween.tween_property(bar, "value", currTime, 0.5).set_trans(Tween.TRANS_LINEAR)

func startChopping():
	if timer.is_stopped():
		timer.start()
	
func treeChopped():
	Global.Wood += 1
	queue_free()
