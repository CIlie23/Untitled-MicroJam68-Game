class_name Health
extends ProgressBar

signal died(killer_team: String)
signal damaged(amount: int)

@export var defense := 0

var current := 0


func setup(maximum: int, armor: int, refill := true) -> void:
	max_value = maximum
	defense = armor
	if refill:
		current = maximum
	current = mini(current, maximum)
	refresh()


func take_damage(amount: int, attacker_team := "") -> int:
	if current <= 0:
		return 0
	var dealt := maxi(1, roundi(amount * 100.0 / (100.0 + defense)))
	current = maxi(current - dealt, 0)
	refresh()
	damaged.emit(dealt)
	if current == 0:
		died.emit(attacker_team)
	return dealt


func heal(amount: int) -> void:
	if current <= 0:
		return
	current = mini(current + amount, int(max_value))
	refresh()


func refresh() -> void:
	value = current
	visible = current < max_value
