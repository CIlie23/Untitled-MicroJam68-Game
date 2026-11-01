extends Building

var mouseEntered = false
@onready var select: Panel = $Selected
var Selected = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	select.visible = Selected

# Unhandled, not _input: clicks on the thHud buttons must not also toggle the building.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("LeftClick"):
		if mouseEntered == true:
			Selected = !Selected
		else:
			Selected = false

func _on_mouse_entered() -> void:
	mouseEntered = true


func _on_mouse_exited() -> void:
	mouseEntered = false
