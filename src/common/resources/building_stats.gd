class_name BuildingStats
extends Resource

enum Category { FARM, MILITARY }

@export var display_name := "Building"
@export_multiline var description := ""
@export var category := Category.FARM
@export var max_health := 200
@export var defense := 2
@export var cost := {}
@export var upgrade_cost := {}
@export var max_level := 4
@export var produces := ""
@export var production := 0
@export var production_per_level := 0
@export var production_time := 5.0
@export var population := 0
@export var population_per_level := 0
