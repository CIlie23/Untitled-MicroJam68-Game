extends Label


@onready var animation: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	animation.play("pop")

func lbl_delete_self():
	self.queue_free()

func show_value(value):
	text = "+ " + str(value) + "g"
