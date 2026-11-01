extends Panel

const ROW := preload("res://src/ui/hud/troops/troop_row.tscn")

var shown_units: Array = []


func _process(_delta: float) -> void:
	var units := get_tree().get_nodes_in_group("unit")
	if units != shown_units:
		shown_units = units
		rebuild()
	for row in %Rows.get_children():
		row.refresh()


func rebuild() -> void:
	for row in %Rows.get_children():
		%Rows.remove_child(row)
		row.queue_free()
	for unit in shown_units:
		var row = ROW.instantiate()
		row.unit = unit
		%Rows.add_child(row)
