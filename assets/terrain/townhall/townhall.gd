class_name Townhall
extends Building

func _ready() -> void:
	Selected = false
	$Sprite2D.frame = Global.townhall_level - 1
	Global.townhall_evolved.connect(_on_townhall_evolved)


func _on_townhall_evolved(stage: int) -> void:
	$Sprite2D.frame = mini(stage, $Sprite2D.hframes - 1)


func _on_deposit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("unit"):
		for stack in body.inventory.take_all():
			Global.set(stack.item.stock_name, Global.get(stack.item.stock_name) + stack.count)
