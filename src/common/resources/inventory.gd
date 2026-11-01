class_name Inventory
extends Resource

@export var slot_count := 6
@export var max_per_slot := 16

var slots: Array[ItemStack] = []


func get_slots() -> Array[ItemStack]:
	if slots.size() != slot_count:
		slots.resize(slot_count)
	return slots


func add(item: Item, amount: int) -> int:
	get_slots()
	for stack in slots:
		if amount > 0 and stack and stack.item == item and stack.count < max_per_slot:
			var taken := mini(amount, max_per_slot - stack.count)
			stack.count += taken
			amount -= taken
	for i in slots.size():
		if amount > 0 and slots[i] == null:
			var stack := ItemStack.new()
			stack.item = item
			stack.count = mini(amount, max_per_slot)
			slots[i] = stack
			amount -= stack.count
	emit_changed()
	return amount


func remove(item: Item, amount: int) -> int:
	get_slots()
	var removed := 0
	for i in range(slots.size() - 1, -1, -1):
		var stack := slots[i]
		if removed < amount and stack and stack.item == item:
			var taken := mini(amount - removed, stack.count)
			stack.count -= taken
			removed += taken
			if stack.count == 0:
				slots[i] = null
	emit_changed()
	return removed


func count(item: Item) -> int:
	var total := 0
	for stack in get_slots():
		if stack and stack.item == item:
			total += stack.count
	return total


func space_for(item: Item) -> int:
	var space := 0
	for stack in get_slots():
		if stack == null:
			space += max_per_slot
		elif stack.item == item:
			space += max_per_slot - stack.count
	return space


func take_all() -> Array[ItemStack]:
	var taken: Array[ItemStack] = []
	for stack in get_slots():
		if stack:
			taken.append(stack)
	slots.clear()
	emit_changed()
	return taken


func is_full() -> bool:
	return get_slots().all(func(stack): return stack != null and stack.count >= max_per_slot)
