extends SubViewport

@onready var camera: Camera2D = $Camera
@onready var container: SubViewportContainer = get_parent()

func _ready() -> void:
	world_2d = get_tree().root.world_2d
	container.gui_input.connect(_on_minimap_clicked)

func _physics_process(delta: float) -> void:
	var main_camera: Camera2D = get_tree().root.get_camera_2d()
	if not main_camera:
		return
	camera.position = main_camera.position
	# Mirror the main camera's map bounds so the minimap never shows past the map edge.
	camera.limit_left = main_camera.limit_left
	camera.limit_top = main_camera.limit_top
	camera.limit_right = main_camera.limit_right
	camera.limit_bottom = main_camera.limit_bottom

# Click a spot on the minimap to send the main camera there.
func _on_minimap_clicked(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not (click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		return
	var main_camera = get_tree().root.get_camera_2d()
	if main_camera:
		main_camera.pan_to(get_canvas_transform().affine_inverse() * click.position)
