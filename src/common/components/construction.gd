class_name Construction
extends ProgressBar

signal started
signal finished

var duration := 0.0
var elapsed := 0.0


func _ready() -> void:
	set_process(false)


func start(seconds: float) -> void:
	duration = seconds
	elapsed = 0.0
	max_value = seconds
	value = 0.0
	show()
	set_process(true)
	started.emit()


func busy() -> bool:
	return is_processing()


func remaining() -> int:
	return ceili(maxf(duration - elapsed, 0.0))


func _process(delta: float) -> void:
	elapsed += delta
	value = elapsed
	if elapsed >= duration:
		hide()
		set_process(false)
		finished.emit()
