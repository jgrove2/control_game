extends Node2D

class_name MapCreatorCanvas

signal data_changed()

var map_data: Dictionary = {}
var _panning: bool = false


func _ready():
	new_map()


func new_map():
	map_data = {
		"id": "new_map",
		"display_name": "New Map",
		"description": "",
		"map_size_px": {"x": 1600, "y": 900},
		"ground_color": "#4a7c3f",
		"shapes": [],
		"barriers": [],
		"deployment_zones": {
			"attacker": {"x": 50, "y": 300, "w": 200, "h": 300},
			"defender": {"x": 1350, "y": 300, "w": 200, "h": 300}
		}
	}
	queue_redraw()


func set_map_data(data: Dictionary):
	map_data = data.duplicate(true)
	queue_redraw()


func get_map_data() -> Dictionary:
	return map_data


func _draw():
	var ms := _get_map_size()
	var gc: Color = JsonMapDefinition.parse_color(map_data.get("ground_color", "#4a7c3f"))
	draw_rect(Rect2(Vector2.ZERO, ms), gc)

	var zones: Dictionary = map_data.get("deployment_zones", {})
	for side_name in ["attacker", "defender"]:
		var zd: Dictionary = zones.get(side_name, {})
		if zd.is_empty():
			continue
		var zx: float = zd.get("x", 0)
		var zy: float = zd.get("y", 0)
		var zw: float = zd.get("w", 200)
		var zh: float = zd.get("h", 300)
		draw_rect(Rect2(zx, zy, zw, zh), JsonMapDefinition.zone_fill_color(side_name))
		draw_rect(Rect2(zx, zy, zw, zh), JsonMapDefinition.zone_border_color(side_name), false, 2.0)


func _get_map_size() -> Vector2:
	var s: Dictionary = map_data.get("map_size_px", {})
	return Vector2(s.get("x", 1600), s.get("y", 900))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(1.1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(0.9)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_panning = mb.pressed
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			position -= mm.relative / scale


func update_map_property(key: String, value):
	map_data[key] = value
	if key in ["map_size_px", "ground_color"]:
		queue_redraw()
	data_changed.emit()


func update_deployment_zone(side: String, key: String, value: float):
	var zones: Dictionary = map_data.get("deployment_zones", {})
	var zone: Dictionary = zones.get(side, {})
	zone[key] = value
	zones[side] = zone
	map_data["deployment_zones"] = zones
	queue_redraw()
	data_changed.emit()


func _zoom_at(factor: float) -> void:
	var mouse_global := get_global_mouse_position()
	var mouse_local := (mouse_global - position) / scale
	scale *= factor
	scale = scale.clamp(Vector2(0.1, 0.1), Vector2(10, 10))
	position = mouse_global - mouse_local * scale
