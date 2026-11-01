extends ColorRect

const MAX_SOURCES := 128

var sources := PackedVector4Array()


func _process(_delta: float) -> void:
	sources.clear()
	for vision in get_tree().get_nodes_in_group("vision"):
		var owner_node = vision.get_parent()
		if owner_node.team == "player" and not owner_node.get("preview") and sources.size() < MAX_SOURCES:
			sources.append(Vector4(owner_node.global_position.x, owner_node.global_position.y, vision.radius, 0.0))
	material.set_shader_parameter("sources", sources)
	material.set_shader_parameter("source_count", sources.size())
	for unit in get_tree().get_nodes_in_group("unit"):
		if unit.team != "player":
			unit.visible = is_seen(unit.global_position)


func is_seen(pos: Vector2) -> bool:
	for source in sources:
		if pos.distance_to(Vector2(source.x, source.y)) <= source.z:
			return true
	return false
