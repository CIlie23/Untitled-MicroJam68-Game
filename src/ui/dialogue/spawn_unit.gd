extends CanvasLayer

@onready var unit = preload("uid://h8vpc05mtwi0")
var housePos = Vector2(300, 300)

func _on_yes_pressed() -> void:
	if Global.populus >= Global.maxPopulus:
		return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var randomPosX = rng.randi_range(-50, 50)
	var randomPosY = rng.randi_range(-50, 50)
	
	var unitPath = get_tree().get_root().get_node("World/Units")
	var worldPath = get_tree().get_root().get_node("World")
	var unit1 = unit.instantiate()
	
	
	unit1.position = housePos + Vector2(randomPosX, randomPosY)
	unitPath.add_child(unit1)
	Global.populus += 1
	worldPath.get_units()

func _on_no_pressed() -> void:
	var housePath = get_tree().get_root().get_node("World/Houses")
	for i in housePath.get_child_count():
		if housePath.get_child(i).Selected == true:
			housePath.get_child(i).Selected = false
	queue_free()
