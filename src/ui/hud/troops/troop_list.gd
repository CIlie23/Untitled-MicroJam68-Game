extends Panel

const ROW := preload("res://src/ui/hud/troops/troop_row.tscn")
const ICON := preload("res://src/ui/hud/troops/troop_icon.tscn")

var shown_units: Array = []
var picked: TroopStats


func _process(_delta: float) -> void:
	var units := get_tree().get_nodes_in_group("unit").filter(func(unit): return unit.team == "player")
	if units != shown_units:
		shown_units = units
		rebuild()
	for row in %Rows.get_children():
		row.refresh()
	for icon in %PickerGrid.get_children():
		icon.refresh()


func groups() -> Dictionary:
	var result := {}
	for unit in shown_units:
		if not result.has(unit.stats):
			result[unit.stats] = []
		result[unit.stats].append(unit)
	return result


func rebuild() -> void:
	clear(%Rows)
	var by_troop := groups()
	var troops := by_troop.keys()
	troops.sort_custom(func(a, b): return a.can_gather if a.can_gather != b.can_gather else a.display_name < b.display_name)
	for troop in troops:
		var row = ROW.instantiate()
		row.units = by_troop[troop]
		row.picked.connect(open_picker)
		%Rows.add_child(row)
	if picked:
		if by_troop.has(picked):
			fill_picker(by_troop[picked])
		else:
			close_picker()


func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func open_picker(troop: TroopStats) -> void:
	if picked == troop and %Picker.visible:
		close_picker()
		return
	picked = troop
	fill_picker(groups()[troop])
	%Picker.show()


func fill_picker(units: Array) -> void:
	clear(%PickerGrid)
	%PickerTitle.text = "%s  x%d" % [picked.display_name, units.size()]
	for unit in units:
		var icon = ICON.instantiate()
		icon.unit = unit
		%PickerGrid.add_child(icon)


func close_picker() -> void:
	picked = null
	clear(%PickerGrid)
	%Picker.hide()


func _on_select_all_pressed() -> void:
	for unit in get_tree().get_nodes_in_group("unit"):
		unit.set_selected(unit.team == "player" and unit.stats == picked)


func _on_close_pressed() -> void:
	close_picker()
