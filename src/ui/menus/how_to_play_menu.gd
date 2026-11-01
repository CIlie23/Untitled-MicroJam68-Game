extends Control


func _ready() -> void:
	%Body.text = "\n".join([
		"Destroy the enemy town hall before they destroy yours.",
		"",
		"CONTROLS",
		"- Move camera: %s %s %s %s (change in Options)" % [
			Settings.key_label(&"camera_up"),
			Settings.key_label(&"camera_left"),
			Settings.key_label(&"camera_down"),
			Settings.key_label(&"camera_right"),
		],
		"- Zoom: mouse wheel",
		"- Select: left-click a troop or drag a box; click a building",
		"- Move selected troops: right-click the ground; groups spread out around the spot",
		"- Attack: right-click an enemy with troops selected",
		"- Troops list (top right): click a troop type to see each unit, then click one to select it and jump to it",
		"- Pause: Esc",
		"",
		"ECONOMY",
		"- Workers gather wood from trees and ore from rocks, then walk back to the town hall to store it",
		"- Idle workers head home on their own after a few seconds",
		"- Farms slowly grow food; send a worker to pick it up",
		"- Houses give room for more troops (up to 4 houses)",
		"- Gathering gets faster every time the town hall evolves",
		"",
		"BUILDINGS",
		"- Place buildings from the town hall's Buildings tab; they take a while to construct",
		"- Upgrade a building from its Upgrade tab: more food, more room, faster training and stronger troops",
		"- Buildings can only be upgraded up to the town hall's level",
		"",
		"TROOPS",
		"- The town hall trains workers for free",
		"- Barracks train swordsmen: balanced fighters",
		"- Archery Ranges train archers: long range and quick shots, but fragile",
		"- Shield Halls train tanks: big, tough and hard-hitting, but slow",
		"- Troops come out at the level of the building that trained them, so upgrade it for stronger troops",
		"",
		"COMBAT",
		"- Troops attack enemies in range on their own",
		"- Workers can fight too, but barely scratch",
		"- Towers shoot nearby enemies",
		"- Wounded troops heal near their town hall",
		"- You only see enemy troops near your own troops and buildings",
		"",
		"GROWING",
		"- Earn XP by finishing buildings, upgrading, training troops, delivering resources, clearing trees and rocks, and fighting",
		"- Evolve the town hall with XP to reach a new era: more population, higher building levels",
		"",
		"THE ENEMY",
		"- It scouts the map and claims resources with guard towers",
		"- It defends its land fiercely and chases intruders",
		"- Once it reaches the modern era it starts attacking you",
	])


func _on_back_button_pressed() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
