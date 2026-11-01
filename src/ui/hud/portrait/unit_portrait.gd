extends CanvasLayer


func _process(_delta: float) -> void:
	if not visible:
		return
	var selected := get_tree().get_nodes_in_group("unit").filter(func(unit): return unit.selected)
	if selected.size() == 1:
		show_unit(selected[0])


func show_unit(unit) -> void:
	%NameLabel.text = "%s  Lv %d" % [unit.stats.display_name, unit.level]
	%Picture.texture = unit.sprite.texture
	%HealthBar.max_value = unit.max_health()
	%HealthBar.value = unit.health
	%HealthValue.text = "%d / %d" % [unit.health, unit.max_health()]
	%AttackValue.text = str(unit.damage())
	%SpeedValue.text = str(int(unit.stats.speed))
	%DefenseValue.text = str(unit.defense())
	%Inventory.visible = unit.stats.can_gather
	var stacks: Array[ItemStack] = unit.inventory.get_slots()
	var slots := %Inventory.find_children("*", "", true, false).filter(func(node): return node.has_method("show_stack"))
	for i in slots.size():
		slots[i].show_stack(stacks[i] if i < stacks.size() else null, unit.inventory.max_per_slot)
