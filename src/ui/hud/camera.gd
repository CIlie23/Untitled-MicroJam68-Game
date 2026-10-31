extends Camera2D

var mousePos = Vector2()

var mousePosGlobal = Vector2()
var start = Vector2()
var startY = Vector2()
var end = Vector2()
var endY = Vector2()
var isDragging = false

signal area_selected
signal start_move_selection

func draw_area():
	pass
