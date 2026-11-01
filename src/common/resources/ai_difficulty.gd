class_name AIDifficulty
extends Resource

@export var gather_rate := 0.8
@export var stat_multiplier := 0.85
@export var cost_multiplier := 1.25
@export var think_interval := 1.5
@export var max_workers := 4
@export var army_cap := 10
@export var carry_before_return := 10
@export var first_attack_delay := 240.0
@export var wave_size := 4
@export var wave_growth := 2
@export var wave_cooldown := 150.0
@export var defend_radius := 1100.0
@export var retreat_health := 0.25
@export var rally_distance := 600.0
@export var raid_interval := 75.0
@export var raid_size := 2
@export var scout_after := 45.0
@export var spot_range := 700.0
@export var expand_interval := 90.0
@export var outposts_per_level := 1
@export var outpost_radius := 700.0
@export var outpost_guards := 1
@export var safe_radius := 1500.0
@export var aggressive_level := 3
@export var worker_scout_interval := 90.0
@export var farm_scene: PackedScene
@export var house_scene: PackedScene
@export var tower_scene: PackedScene
@export var military_scenes: Array[PackedScene] = []
