class_name Building
extends StaticBody2D

# shared type for buildings like townhall, placeholder
func _enter_tree() -> void:
	add_to_group(&"buildings")
