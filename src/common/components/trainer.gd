class_name Trainer
extends Node

signal queue_changed

@export var troop: TroopStats
@export var faster_training_per_level := 0.15
@export var faster_troops_per_level := 0.10

var queue := 0
var progress := 0.0


func _enter_tree() -> void:
	add_to_group(&"trainers")


func can_train() -> bool:
	return Global.populus + Global.queued_troops() < Global.maxPopulus and Global.can_afford(troop.cost)


func train() -> void:
	if can_train() and Global.spend(troop.cost):
		queue += 1
		queue_changed.emit()


func train_time() -> float:
	return troop.train_time * maxf(1.0 - faster_training_per_level * (get_parent().level - 1), 0.1)


func fraction() -> float:
	return progress / train_time() if queue > 0 else 0.0


func _process(delta: float) -> void:
	if queue == 0:
		progress = 0.0
		return
	progress += delta
	if progress >= train_time():
		progress = 0.0
		queue -= 1
		Global.spawn_unit(troop, get_parent().global_position, 1.0 + faster_troops_per_level * (get_parent().level - 1))
		queue_changed.emit()
