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
		"- Move selected troops: right-click",
		"- Troops list (top right): click a troop to select it and jump to it",
		"- Pause: Esc",
		"",
		"ECONOMY",
		"- Workers gather wood from trees and ore from rocks (up to 6 x 16 each)",
		"- Walk them back to the town hall to store what they carry",
		"- Farms make food, houses give room for more troops",
		"",
		"TROOPS",
		"- The town hall trains workers for free",
		"- Barracks, Archery Range and Shield Hall train swordsmen, archers and tanks for food",
		"",
		"COMBAT",
		"- Soldiers attack enemies in range; right-click an enemy to attack it",
		"- Towers shoot enemies near your base; workers never fight",
		"- You only see enemy troops near your own troops and buildings",
		"",
		"GROWING",
		"- Place buildings from the town hall's Buildings tab; each one gives XP",
		"- Evolve the town hall with XP: more population, stronger new troops, higher building levels",
		"- Upgrade a building from its Upgrade tab: more food, more room, faster troops and training",
	])


func _on_back_button_pressed() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
