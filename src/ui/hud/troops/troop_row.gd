extends Button

var unit


func _ready() -> void:
	%Icon.texture = unit.sprite.texture
	%Icon.modulate = unit.stats.tint


func refresh() -> void:
	if not is_instance_valid(unit):
		return
	%Name.text = "%s  Lv %d" % [unit.stats.display_name, unit.level]
	%Health.max_value = unit.max_health()
	%Health.value = unit.health
	flat = not unit.selected


func _on_pressed() -> void:
	for other in get_tree().get_nodes_in_group("unit"):
		other.set_selected(other == unit)
	get_viewport().get_camera_2d().pan_to(unit.global_position)
