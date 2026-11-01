class_name TroopStats
extends Resource

@export var display_name := "Troop"
@export_multiline var description := ""
@export var max_health := 100
@export var damage := 10
@export var defense := 0
@export var speed := 550.0
@export var size := 1.0
@export var attack_range := 0.0
@export var attack_cooldown := 1.0
@export var ranged := false
@export var can_gather := false
@export var cost := {}
@export var train_time := 3.0
@export var tint := Color.WHITE
@export var frames: SpriteFrames
@export var enemy_frames: SpriteFrames
@export var level_frames: Array[SpriteFrames] = []
@export var enemy_level_frames: Array[SpriteFrames] = []
