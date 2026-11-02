extends PanelContainer

var elapsed := 0.0


func _process(delta: float) -> void:
	var units := get_tree().current_scene.get_node_or_null("Units")
	if units and not units.can_process():
		return
	elapsed += delta
	var seconds := floori(elapsed)
	%Time.text = "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]
