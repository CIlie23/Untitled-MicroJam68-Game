class_name TroopStats
extends Resource

@export var display_name := "Troop"
@export_multiline var description := ""
@export var max_health := 100
@export var damage := 10
@export var defense := 0
@export var speed := 550.0
@export var can_gather := false
@export var cost := {}
@export var train_time := 3.0
@export var tint := Color.WHITE
@export var stage_sprites: Array[Texture2D] = []
