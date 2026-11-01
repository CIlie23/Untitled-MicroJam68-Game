extends CanvasLayer

const STOCK_LABELS := {"Wood": "wood", "Minerals": "ore", "food": "food"}
const TROOPS_TAB := 0
const BUILDINGS_TAB := 1
const EVOLVE_TAB := 2
const UPGRADE_TAB := 3
const TROOP_SLOT := preload("res://src/ui/hud/portrait/troopSlot/troopSlot.tscn")

@export var buildings: Array[PackedScene] = []

var shown
var build_stats: Array[BuildingStats] = []
var build_index := 0
var picture_key := []
var trainer: Trainer
var queue_bars: Array = []


func _ready() -> void:
	for scene in buildings:
		var probe = scene.instantiate()
		build_stats.append(probe.stats)
		%BuildList.add_item(probe.stats.display_name, frame_texture(probe.get_node("Sprite2D")))
		probe.free()
	if build_stats:
		%BuildList.select(0)


func _process(_delta: float) -> void:
	if not visible:
		return
	show_build_detail()
	var building = selected_building()
	if building == null:
		return
	if building != shown:
		shown = building
		show_tabs(building)
	if building is Townhall:
		show_townhall(building)
	else:
		show_building(building)
	show_training()


func selected_building():
	for building in get_tree().get_nodes_in_group("buildings"):
		if building.Selected:
			return building
	return null


func show_tabs(building) -> void:
	var townhall: bool = building is Townhall
	watch_trainer(building.get_node_or_null("Trainer"))
	%TabContainer.set_tab_hidden(TROOPS_TAB, trainer == null)
	%TabContainer.set_tab_hidden(BUILDINGS_TAB, not townhall)
	%TabContainer.set_tab_hidden(EVOLVE_TAB, not townhall)
	%TabContainer.set_tab_hidden(UPGRADE_TAB, townhall)
	%TabContainer.current_tab = TROOPS_TAB if trainer else UPGRADE_TAB


func watch_trainer(new_trainer: Trainer) -> void:
	if trainer and trainer.queue_changed.is_connected(rebuild_queue):
		trainer.queue_changed.disconnect(rebuild_queue)
	trainer = new_trainer
	if trainer:
		trainer.queue_changed.connect(rebuild_queue)
	rebuild_queue()


func show_training() -> void:
	if not trainer:
		return
	%btnTroop1.text = "%s  (%s)" % [trainer.troop.display_name, cost_text(trainer.troop.cost)]
	%btnTroop1.tooltip_text = trainer.troop.description
	%btnTroop1.disabled = not trainer.can_train()
	for i in queue_bars.size():
		if queue_bars[i]:
			queue_bars[i].value = trainer.fraction() if i == 0 else 0.0


func rebuild_queue() -> void:
	for slot in %QueueGrid.get_children():
		%QueueGrid.remove_child(slot)
		slot.queue_free()
	queue_bars.clear()
	if not trainer:
		return
	for i in trainer.queue:
		var slot = TROOP_SLOT.instantiate()
		%QueueGrid.add_child(slot)
		var bar = slot.find_child("troopHealth", true, false)
		if bar:
			bar.max_value = 1.0
			bar.value = 0.0
		queue_bars.append(bar)


func show_townhall(townhall) -> void:
	var stats := Global.townhall_stats()
	%BuildingName.text = "TOWN HALL  Lv %d" % Global.townhall_level
	show_picture(townhall.get_node("Sprite2D"))
	%BuildingHealthBar.max_value = stats.health
	%BuildingHealthBar.value = Global.townhall_health
	%BuildingHealth.text = "%d / %d" % [Global.townhall_health, stats.health]
	%BuildingDefense.text = str(stats.defense)
	%InfoLabel.text = "Population %d / %d\nXP %d / %d" % [Global.populus, Global.maxPopulus, Global.xp, Global.next_evolve_xp()]

	%XpBar.max_value = Global.next_evolve_xp()
	%XpBar.value = Global.xp
	%EvolveButton.disabled = not Global.can_evolve()
	if Global.townhall_level < Global.TOWNHALL_LEVELS.size():
		var next: Dictionary = Global.TOWNHALL_LEVELS[Global.townhall_level]
		%EvolveNext.text = "Next: Lv %d (%d XP) - new troops +%d%%, buildings up to Lv %d, max population %d" % [
			Global.townhall_level + 1,
			Global.next_evolve_xp(),
			roundi(Global.TROOP_BONUS_PER_LEVEL * 100),
			Global.townhall_level + 1,
			next.max_population,
		]
	else:
		%EvolveNext.text = "The town hall is fully evolved"


func show_building(building) -> void:
	var stats: BuildingStats = building.stats
	%BuildingName.text = "%s  Lv %d" % [stats.display_name.to_upper(), building.level]
	show_picture(building.get_node("Sprite2D"))
	%BuildingHealthBar.max_value = stats.max_health
	%BuildingHealthBar.value = building.health
	%BuildingHealth.text = "%d / %d" % [building.health, stats.max_health]
	%BuildingDefense.text = str(stats.defense)
	%InfoLabel.text = stats.description
	if stats.produces:
		%InfoLabel.text = production_text(stats, building.production_amount())
	elif stats.population:
		%InfoLabel.text = "+%d max population" % building.population_bonus()

	%UpgradeButton.disabled = not building.can_upgrade()
	if building.level >= stats.max_level:
		%UpgradeInfo.text = "Max level"
	elif building.level >= building.level_cap():
		%UpgradeInfo.text = "Evolve the town hall to unlock level %d" % (building.level + 1)
	else:
		var effect := "Troops +%d%% speed, training -%d%%" % [roundi(trainer.faster_troops_per_level * 100), roundi(trainer.faster_training_per_level * 100)] if trainer else ""
		if stats.produces:
			effect = production_text(stats, building.production_amount() + stats.production_per_level)
		elif stats.population:
			effect = "+%d max population" % stats.population_per_level
		%UpgradeInfo.text = "Lv %d -> Lv %d\n%s\nCost: %s" % [building.level, building.level + 1, effect, cost_text(building.upgrade_cost())]


func show_picture(sprite: Sprite2D) -> void:
	var key := [sprite, sprite.frame]
	if key != picture_key:
		picture_key = key
		%BuildingPicture.texture = frame_texture(sprite)


func frame_texture(sprite: Sprite2D) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sprite.texture
	var frame_size := sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
	atlas.region = Rect2(frame_size * Vector2(sprite.frame_coords), frame_size)
	return atlas


func production_text(stats: BuildingStats, amount: int) -> String:
	return "+%d %s every %ss" % [amount, STOCK_LABELS.get(stats.produces, stats.produces), stats.production_time]


func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for stock in cost:
		parts.append("%d %s" % [cost[stock], STOCK_LABELS.get(stock, stock)])
	return ", ".join(PackedStringArray(parts)) if parts else "free"


func _on_upgrade_button_pressed() -> void:
	if shown and not (shown is Townhall):
		shown.upgrade()


func _on_evolve_button_pressed() -> void:
	Global.evolve_townhall()


func _on_train_pressed() -> void:
	if trainer:
		trainer.train()


func show_build_detail() -> void:
	if build_stats.is_empty():
		return
	var stats := build_stats[build_index]
	%BuildPicture.texture = %BuildList.get_item_icon(build_index)
	%BuildName.text = stats.display_name
	%BuildDescription.text = stats.description
	var parts: Array[String] = []
	for stock in stats.cost:
		var part := "%d %s" % [stats.cost[stock], STOCK_LABELS.get(stock, stock)]
		parts.append(part if Global.get(stock) >= stats.cost[stock] else "[color=red]%s[/color]" % part)
	%BuildCost.text = "Cost: " + ", ".join(PackedStringArray(parts))
	%BuildButton.disabled = not Global.can_afford(stats.cost)


func _on_build_list_item_selected(index: int) -> void:
	build_index = index


func _on_build_button_pressed() -> void:
	var world = get_tree().current_scene
	if world and world.has_method("begin_placement"):
		world.begin_placement(buildings[build_index])
