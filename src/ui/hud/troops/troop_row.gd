extends Button

signal picked(troop: TroopStats)

var units: Array = []


func _ready() -> void:
	%Icon.texture = units[0].portrait_texture()
	%Icon.modulate = units[0].stats.tint


func refresh() -> void:
	var alive := units.filter(func(unit): return is_instance_valid(unit))
	if alive.is_empty():
		return
	%Name.text = "%s  x%d" % [alive[0].stats.display_name, alive.size()]
	var health := 0
	var max_health := 0
	for unit in alive:
		health += unit.health
		max_health += unit.max_health()
	%Health.max_value = max_health
	%Health.value = health
	flat = not alive.any(func(unit): return unit.selected)


func _on_pressed() -> void:
	picked.emit(units[0].stats)
