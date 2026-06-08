extends Control
class_name SoldierIcon

var icon_color: Color = Color(1, 1, 1, 1)
var icon_radius: float = 16.0
var line_width: float = 3.0


func set_icon_color(color: Color) -> void:
	icon_color = color
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_arc(center, icon_radius, 0.0, TAU, 32, icon_color, line_width)
