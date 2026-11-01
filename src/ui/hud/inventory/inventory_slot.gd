extends Control


func show_stack(stack: ItemStack, max_count: int) -> void:
	$itemPortrait.texture = stack.item.icon if stack else null
	$countLabel.text = "%d/%d" % [stack.count, max_count] if stack else ""
