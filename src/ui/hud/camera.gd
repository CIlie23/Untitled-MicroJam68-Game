extends Camera2D


# Camera Control
@export var ZOOM_SPEED = 20.0
@export var ZOOM_MARGIN = 0.1
@export var ZOOM_MIN = 0.5
@export var ZOOM_MAX = 3.0
@export var PAN_SPEED = 8.0

var pan_target: Vector2
var panning := false
var zoomFactor = 1.0
var zoomPos = Vector2()
var zooming = false
var mousePos = Vector2()

var mousePosGlobal = Vector2()
var start = Vector2()
var startV = Vector2()
var end = Vector2()
var endV = Vector2()
var isDragging = false

signal area_selected(area)
signal start_move_selection

@onready var panel: Panel = $"../UI/Panel"

# Ease toward a world position. Called by the minimap.
func pan_to(target: Vector2) -> void:
	pan_target = target
	panning = true

func _process(delta: float) -> void:
	
	var input = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	var speed = Global.CAMERA_SPEED * Settings.camera_speed / 100.0
	position += input * speed * delta / zoom.x
	
	# Keyboard wins: while it is held, kill any pending minimap pan.
	# Anything that sets position directly is left alone, since panning stays false.
	if input != Vector2.ZERO:
		panning = false
	if panning:
		position = position.lerp(pan_target, PAN_SPEED * delta)
		if position.distance_squared_to(pan_target) < 1.0:
			position = pan_target
			panning = false
	
	zoom.x = lerp(zoom.x, zoom.x * zoomFactor, ZOOM_SPEED * delta)
	zoom.y = lerp(zoom.y, zoom.y * zoomFactor, ZOOM_SPEED * delta)
	
	zoom.x = clamp(zoom.x, ZOOM_MIN, ZOOM_MAX)
	zoom.y = clamp(zoom.y, ZOOM_MIN, ZOOM_MAX)

	var halfView = get_viewport_rect().size / zoom / 2
	position = position.clamp(Vector2(limit_left, limit_top) + halfView, Vector2(limit_right, limit_bottom) - halfView)
	
	if not zooming:
		zoomFactor = 1.0
	
	if Input.is_action_just_pressed("LeftClick"):
		start = mousePosGlobal
		startV = mousePos
		isDragging = true
		
	if isDragging:
		end = mousePosGlobal
		endV = mousePos
		draw_area()
		
	if Input.is_action_just_released("LeftClick"):
		if startV.distance_to(mousePos) > 20:
			end = mousePosGlobal
			endV = mousePos
			isDragging = false
			draw_area(false)
		else:
			# Too short to be a drag, so treat it as a click: end == start, which
			# makes an empty area, and world.gd deselects everything it does not find.
			end = start
			isDragging = false
			draw_area(false)
		emit_signal("area_selected", self)

func _input(event: InputEvent) -> void:
	if abs(zoomPos.x - get_global_mouse_position().x) > ZOOM_MARGIN:
		zoomFactor = 1.0
	if abs(zoomPos.y - get_global_mouse_position().y) > ZOOM_MARGIN:
		zoomFactor = 1.0
	
	if event is InputEventMouse:
		mousePos = event.position
		mousePosGlobal = get_global_mouse_position()

# Unhandled, not _input: the GUI gets the event first, so a wheel over a
# ScrollContainer scrolls the panel instead of zooming the camera.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			zooming = true
			if event.is_action("WheelDown"):
				zoomFactor -= 0.01 * ZOOM_SPEED
				zoomPos = get_global_mouse_position()
			if event.is_action("WheelUp"):
				zoomFactor += 0.01 * ZOOM_SPEED
				zoomPos = get_global_mouse_position()
	else:
		zooming = false
		
# the select area
func draw_area(s=true):
	panel.size = Vector2(abs(startV.x - endV.x), abs(startV.y - endV.y))
	var pos = Vector2()
	pos.x = min(startV.x, endV.x)
	pos.y = min(startV.y, endV.y)
	panel.position = pos
	panel.size *= int(s)
