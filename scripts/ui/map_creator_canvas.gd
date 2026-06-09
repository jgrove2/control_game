extends Node2D

class_name MapCreatorCanvas

signal data_changed()
signal selection_changed(drag_idx: int)

var map_data: Dictionary = {}

enum DragType { NONE, MOVE, RESIZE }

var _panning: bool = false
var _draggables: Array[Dictionary] = []
var _active_drag_idx: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_type: int = DragType.NONE
var _selected_idx: int = -1
var _resize_handles: Array[Dictionary] = []
var _active_handle_idx: int = -1
var _last_cursor: int = 0

const BIOME_COLORS: Dictionary = {
	"water": Color(0.29, 0.56, 0.85),
	"sand": Color(0.83, 0.65, 0.42),
	"grass": Color(0.49, 0.78, 0.31)
}

const SAND_BAG_COLOR: Color = Color(0.82, 0.71, 0.55)


func _ready():
	new_map()


func new_map():
	map_data = {
		"id": "new_map",
		"display_name": "New Map",
		"description": "",
		"map_size_px": {"x": 1080, "y": 1920},
		"ground_color": "#8B7355",
		"shapes": [],
		"barriers": [],
		"biomes": [],
		"sand_bags": [],
		"deployment_zones": {
			"attacker": {"x": 300, "y": 40, "w": 500, "h": 200},
			"defender": {"x": 300, "y": 1690, "w": 500, "h": 200}
		}
	}
	_rebuild_draggables()
	queue_redraw()


func set_map_data(data: Dictionary):
	map_data = data.duplicate(true)
	_rebuild_draggables()
	queue_redraw()


func get_map_data() -> Dictionary:
	return map_data


func _draw():
	var ms := _get_map_size()
	var gc: Color = JsonMapDefinition.parse_color(map_data.get("ground_color", "#8B7355"))
	draw_rect(Rect2(Vector2.ZERO, ms), gc)

	var biomes: Array = map_data.get("biomes", [])
	var sand_bags: Array = map_data.get("sand_bags", [])
	for layer in range(1, 7):
		for bd in biomes:
			if bd.get("layer", 1) != layer:
				continue
			var t: String = bd.get("type", "grass")
			var col: Color = BIOME_COLORS.get(t, BIOME_COLORS["grass"])
			var x: float = bd.get("x", 0)
			var y: float = bd.get("y", 0)
			draw_rect(Rect2(x, y, bd.get("w", 80), bd.get("h", 60)), col)
		for sd in sand_bags:
			if sd.get("layer", 1) != layer:
				continue
			var x: float = sd.get("x", 0)
			var y: float = sd.get("y", 0)
			draw_rect(Rect2(x, y, sd.get("w", 40), sd.get("h", 40)), SAND_BAG_COLOR)

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

	var highlight_idx := _active_drag_idx if _drag_type == DragType.MOVE else _selected_idx
	if highlight_idx >= 0 and highlight_idx < _draggables.size():
		var drag_id: String = _draggables[highlight_idx].get("id", "")
		if drag_id.begins_with("deployment_zone_"):
			var side := drag_id.trim_prefix("deployment_zone_")
			var zd: Dictionary = zones.get(side, {})
			if not zd.is_empty():
				draw_rect(Rect2(zd.get("x", 0), zd.get("y", 0), zd.get("w", 200), zd.get("h", 300)),
					Color.WHITE, false, 4.0)
		elif drag_id.begins_with("biome_") or drag_id.begins_with("sand_bag_"):
			var hr: Rect2 = _draggables[highlight_idx]["get_rect"].call()
			draw_rect(hr, Color.WHITE, false, 4.0)

	if _selected_idx >= 0:
		for handle in _resize_handles:
			var hr: Rect2 = handle["get_rect"].call()
			draw_rect(hr, Color.WHITE, true)
			draw_rect(hr, Color(0.2, 0.2, 0.2), false, 1.0)


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
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_left_press()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_on_left_release()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_update_cursor()
		if _drag_type == DragType.RESIZE:
			_update_resize_drag()
		elif _drag_type == DragType.MOVE:
			_update_move_drag()
		elif _panning:
			position -= mm.relative / scale


# ---- Drag system: generic descriptors ----

func _rebuild_draggables() -> void:
	_deselect()
	_draggables.clear()
	for side in ["attacker", "defender"]:
		_draggables.append(_make_zone_draggable(side))
	var biomes: Array = map_data.get("biomes", [])
	for i in biomes.size():
		_draggables.append(_make_biome_draggable(i))
	var sand_bags: Array = map_data.get("sand_bags", [])
	for i in sand_bags.size():
		_draggables.append(_make_sand_bag_draggable(i))


func _make_zone_draggable(side: String) -> Dictionary:
	return {
		"id": "deployment_zone_" + side,
		"get_rect": func() -> Rect2:
			var zd: Dictionary = map_data.get("deployment_zones", {}).get(side, {})
			return Rect2(zd.get("x", 0), zd.get("y", 0), zd.get("w", 200), zd.get("h", 300)),
		"set_pos": func(v: Vector2) -> void:
			map_data["deployment_zones"][side]["x"] = v.x
			map_data["deployment_zones"][side]["y"] = v.y
			queue_redraw(),
		"commit": func() -> void:
			var zd: Dictionary = map_data["deployment_zones"].get(side, {})
			commit_deployment_zone(side, zd.get("x", 0), zd.get("y", 0)),
		"get_resize_handles": func() -> Array[Dictionary]:
			var dirs := ["nw", "n", "ne", "w", "e", "sw", "s", "se"]
			var handles: Array[Dictionary] = []
			for dir in dirs:
				handles.append(_make_zone_resize_handle(side, dir))
			return handles,
	}


func _make_biome_draggable(idx: int) -> Dictionary:
	return {
		"id": "biome_" + str(idx),
		"get_rect": func() -> Rect2:
			var biomes: Array = map_data.get("biomes", [])
			if idx < 0 or idx >= biomes.size():
				return Rect2(0, 0, 0, 0)
			var bd: Dictionary = biomes[idx]
			return Rect2(bd.get("x", 0), bd.get("y", 0), bd.get("w", 100), bd.get("h", 100)),
		"set_pos": func(v: Vector2) -> void:
			var biomes: Array = map_data.get("biomes", [])
			if idx < 0 or idx >= biomes.size():
				return
			var bd: Dictionary = biomes[idx]
			bd["x"] = v.x
			bd["y"] = v.y
			map_data["biomes"][idx] = bd
			queue_redraw(),
		"commit": func() -> void:
			data_changed.emit(),
		"get_resize_handles": func() -> Array[Dictionary]:
			var dirs := ["nw", "n", "ne", "w", "e", "sw", "s", "se"]
			var handles: Array[Dictionary] = []
			for dir in dirs:
				handles.append(_make_biome_resize_handle(idx, dir))
			return handles,
	}


func _make_sand_bag_draggable(idx: int) -> Dictionary:
	return {
		"id": "sand_bag_" + str(idx),
		"get_rect": func() -> Rect2:
			var sand_bags: Array = map_data.get("sand_bags", [])
			if idx < 0 or idx >= sand_bags.size():
				return Rect2(0, 0, 0, 0)
			var sd: Dictionary = sand_bags[idx]
			return Rect2(sd.get("x", 0), sd.get("y", 0), sd.get("w", 40), sd.get("h", 40)),
		"set_pos": func(v: Vector2) -> void:
			var sand_bags: Array = map_data.get("sand_bags", [])
			if idx < 0 or idx >= sand_bags.size():
				return
			var sd: Dictionary = sand_bags[idx]
			sd["x"] = v.x
			sd["y"] = v.y
			map_data["sand_bags"][idx] = sd
			queue_redraw(),
		"commit": func() -> void:
			data_changed.emit(),
		"get_resize_handles": func() -> Array[Dictionary]:
			var dirs := ["nw", "n", "ne", "w", "e", "sw", "s", "se"]
			var handles: Array[Dictionary] = []
			for dir in dirs:
				handles.append(_make_sand_bag_resize_handle(idx, dir))
			return handles,
	}


func _get_draggable_at(world_pos: Vector2) -> int:
	for i in range(_draggables.size() - 1, -1, -1):
		var rect: Rect2 = _draggables[i]["get_rect"].call()
		if rect.has_point(world_pos):
			return i
	return -1


# ---- Selection ----

func _select_item(idx: int) -> void:
	_deselect()
	if idx < 0 or idx >= _draggables.size():
		return
	_selected_idx = idx
	_build_resize_handles()
	queue_redraw()
	selection_changed.emit(idx)


func _deselect() -> void:
	_selected_idx = -1
	_resize_handles.clear()
	_drag_type = DragType.NONE
	_active_drag_idx = -1
	_active_handle_idx = -1
	_drag_offset = Vector2.ZERO
	queue_redraw()
	selection_changed.emit(-1)


func _build_resize_handles() -> void:
	_resize_handles.clear()
	if _selected_idx < 0 or _selected_idx >= _draggables.size():
		return
	var desc := _draggables[_selected_idx]
	if desc.has("get_resize_handles"):
		_resize_handles = desc["get_resize_handles"].call()


# ---- Left-click state machine ----

func _on_left_press() -> void:
	var mouse_world := to_local(get_global_mouse_position())

	for d_idx in range(_draggables.size() - 1, -1, -1):
		var desc := _draggables[d_idx]
		if desc.has("get_resize_handles"):
			var handles: Array[Dictionary] = desc["get_resize_handles"].call()
			for i in range(handles.size() - 1, -1, -1):
				if handles[i]["get_rect"].call().has_point(mouse_world):
					if _selected_idx != d_idx:
						_select_item(d_idx)
					_drag_type = DragType.RESIZE
					_active_handle_idx = i
					_last_cursor = _cursor_for_handle(handles[i]["id"])
					get_parent().mouse_default_cursor_shape = _last_cursor
					return

	var idx := _get_draggable_at(mouse_world)
	if idx >= 0:
		if _selected_idx != idx:
			_select_item(idx)
		_drag_type = DragType.MOVE
		_active_drag_idx = idx
		_drag_offset = mouse_world - _draggables[idx]["get_rect"].call().position
		_last_cursor = Input.CURSOR_MOVE
		get_parent().mouse_default_cursor_shape = Input.CURSOR_MOVE
	else:
		_deselect()


func _on_left_release() -> void:
	if _drag_type == DragType.RESIZE and _active_handle_idx >= 0:
		_resize_handles[_active_handle_idx]["commit"].call()
	elif _drag_type == DragType.MOVE and _active_drag_idx >= 0:
		_draggables[_active_drag_idx]["commit"].call()

	_drag_type = DragType.NONE
	_active_drag_idx = -1
	_active_handle_idx = -1
	_drag_offset = Vector2.ZERO


func _update_move_drag() -> void:
	if _active_drag_idx < 0 or _active_drag_idx >= _draggables.size():
		_drag_type = DragType.NONE
		return
	var mouse_world := to_local(get_global_mouse_position())
	var target_pos := mouse_world - _drag_offset
	_draggables[_active_drag_idx]["set_pos"].call(target_pos)


func _update_resize_drag() -> void:
	if _active_handle_idx < 0 or _active_handle_idx >= _resize_handles.size():
		_drag_type = DragType.NONE
		return
	var mouse_world := to_local(get_global_mouse_position())
	_resize_handles[_active_handle_idx]["apply"].call(mouse_world)


# ---- Resize handle factory ----

func _make_zone_resize_handle(side: String, dir: String) -> Dictionary:
	var get_rect := func() -> Rect2:
		var zd: Dictionary = map_data["deployment_zones"].get(side, {})
		var r := Rect2(zd.get("x", 0), zd.get("y", 0), zd.get("w", 200), zd.get("h", 300))
		var inv_scale: float = 1.0 / scale.x
		return _handle_click_rect(r, dir, inv_scale)

	var apply := func(mouse_world: Vector2) -> void:
		var zd: Dictionary = map_data["deployment_zones"].get(side, {})
		var r := Rect2(zd.get("x", 0), zd.get("y", 0), zd.get("w", 200), zd.get("h", 300))
		var new_r := _resize_rect(r, mouse_world, dir)
		if new_r.size.x >= 20 and new_r.size.y >= 20:
			zd["x"] = new_r.position.x
			zd["y"] = new_r.position.y
			zd["w"] = new_r.size.x
			zd["h"] = new_r.size.y
			map_data["deployment_zones"][side] = zd
			queue_redraw()

	var commit := func() -> void:
		var zd: Dictionary = map_data["deployment_zones"].get(side, {})
		commit_deployment_zone(side, zd.get("x", 0), zd.get("y", 0))

	return {
		"id": "resize_" + dir,
		"get_rect": get_rect,
		"apply": apply,
		"commit": commit,
	}


func _make_biome_resize_handle(idx: int, dir: String) -> Dictionary:
	var get_rect := func() -> Rect2:
		var biomes: Array = map_data.get("biomes", [])
		if idx < 0 or idx >= biomes.size():
			return Rect2(0, 0, 0, 0)
		var bd: Dictionary = biomes[idx]
		var r := Rect2(bd.get("x", 0), bd.get("y", 0), bd.get("w", 100), bd.get("h", 100))
		var inv_scale: float = 1.0 / scale.x
		return _handle_click_rect(r, dir, inv_scale)

	var apply := func(mouse_world: Vector2) -> void:
		var biomes: Array = map_data.get("biomes", [])
		if idx < 0 or idx >= biomes.size():
			return
		var bd: Dictionary = biomes[idx]
		var r := Rect2(bd.get("x", 0), bd.get("y", 0), bd.get("w", 100), bd.get("h", 100))
		var new_r := _resize_rect(r, mouse_world, dir)
		if new_r.size.x >= 20 and new_r.size.y >= 20:
			bd["x"] = new_r.position.x
			bd["y"] = new_r.position.y
			bd["w"] = new_r.size.x
			bd["h"] = new_r.size.y
		map_data["biomes"][idx] = bd
		queue_redraw()

	var commit := func() -> void:
		data_changed.emit()

	return {
		"id": "resize_" + dir,
		"get_rect": get_rect,
		"apply": apply,
		"commit": commit,
	}


func _make_sand_bag_resize_handle(idx: int, dir: String) -> Dictionary:
	var get_rect := func() -> Rect2:
		var sand_bags: Array = map_data.get("sand_bags", [])
		if idx < 0 or idx >= sand_bags.size():
			return Rect2(0, 0, 0, 0)
		var sd: Dictionary = sand_bags[idx]
		var r := Rect2(sd.get("x", 0), sd.get("y", 0), sd.get("w", 40), sd.get("h", 40))
		var inv_scale: float = 1.0 / scale.x
		return _handle_click_rect(r, dir, inv_scale)

	var apply := func(mouse_world: Vector2) -> void:
		var sand_bags: Array = map_data.get("sand_bags", [])
		if idx < 0 or idx >= sand_bags.size():
			return
		var sd: Dictionary = sand_bags[idx]
		var r := Rect2(sd.get("x", 0), sd.get("y", 0), sd.get("w", 40), sd.get("h", 40))
		var new_r := _resize_rect(r, mouse_world, dir)
		if new_r.size.x >= 10 and new_r.size.y >= 10:
			sd["x"] = new_r.position.x
			sd["y"] = new_r.position.y
			sd["w"] = new_r.size.x
			sd["h"] = new_r.size.y
		map_data["sand_bags"][idx] = sd
		queue_redraw()

	var commit := func() -> void:
		data_changed.emit()

	return {
		"id": "resize_" + dir,
		"get_rect": get_rect,
		"apply": apply,
		"commit": commit,
	}


# ---- Resize math helpers ----

static func _handle_click_rect(rect: Rect2, dir: String, inv_scale: float = 1.0) -> Rect2:
	var pos := _handle_position(rect, dir)
	var half := 6.0 * inv_scale
	return Rect2(pos - Vector2(half, half), Vector2(half * 2.0, half * 2.0))


static func _handle_position(rect: Rect2, dir: String) -> Vector2:
	match dir:
		"nw": return Vector2(rect.position.x, rect.position.y)
		"n":  return Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y)
		"ne": return Vector2(rect.position.x + rect.size.x, rect.position.y)
		"w":  return Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5)
		"e":  return Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y * 0.5)
		"sw": return Vector2(rect.position.x, rect.position.y + rect.size.y)
		"s":  return Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y)
		"se": return Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y)
	return rect.position


static func _resize_rect(rect: Rect2, mouse_world: Vector2, dir: String) -> Rect2:
	var r := Rect2(rect.position, rect.size)
	match dir:
		"se":
			r.size.x = max(20, mouse_world.x - r.position.x)
			r.size.y = max(20, mouse_world.y - r.position.y)
		"sw":
			var new_w := r.size.x + (r.position.x - mouse_world.x)
			r.position.x = mouse_world.x
			r.size.x = max(20, new_w)
			r.size.y = max(20, mouse_world.y - r.position.y)
		"ne":
			r.size.x = max(20, mouse_world.x - r.position.x)
			var new_h := r.size.y + (r.position.y - mouse_world.y)
			r.position.y = mouse_world.y
			r.size.y = max(20, new_h)
		"nw":
			var new_w := r.size.x + (r.position.x - mouse_world.x)
			var new_h := r.size.y + (r.position.y - mouse_world.y)
			r.position.x = mouse_world.x
			r.position.y = mouse_world.y
			r.size.x = max(20, new_w)
			r.size.y = max(20, new_h)
		"n":
			var new_h := r.size.y + (r.position.y - mouse_world.y)
			r.position.y = mouse_world.y
			r.size.y = max(20, new_h)
		"s":
			r.size.y = max(20, mouse_world.y - r.position.y)
		"w":
			var new_w := r.size.x + (r.position.x - mouse_world.x)
			r.position.x = mouse_world.x
			r.size.x = max(20, new_w)
		"e":
			r.size.x = max(20, mouse_world.x - r.position.x)
	return r


# ---- Mouse cursor ----

func _exit_tree() -> void:
	get_parent().mouse_default_cursor_shape = 0


func _update_cursor() -> void:
	if _drag_type != DragType.NONE:
		return
	var mouse_world := to_local(get_global_mouse_position())
	var shape := _get_cursor_for_pos(mouse_world)
	if shape != _last_cursor:
		_last_cursor = shape
		get_parent().mouse_default_cursor_shape = shape


func _get_cursor_for_pos(world_pos: Vector2) -> int:
	if _selected_idx >= 0:
		for handle in _resize_handles:
			if handle["get_rect"].call().has_point(world_pos):
				return _cursor_for_handle(handle["id"])
	var idx := _get_draggable_at(world_pos)
	if idx >= 0:
		return Input.CURSOR_MOVE
	return Input.CURSOR_ARROW


static func _cursor_for_handle(id: String) -> int:
	var dir := id.trim_prefix("resize_")
	match dir:
		"nw", "se": return Input.CURSOR_FDIAGSIZE
		"ne", "sw": return Input.CURSOR_BDIAGSIZE
		"n", "s":   return Input.CURSOR_VSIZE
		"e", "w":   return Input.CURSOR_HSIZE
	return Input.CURSOR_ARROW


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


func commit_deployment_zone(side: String, x: float, y: float) -> void:
	var zones: Dictionary = map_data.get("deployment_zones", {})
	var zone: Dictionary = zones.get(side, {})
	zone["x"] = x
	zone["y"] = y
	zones[side] = zone
	map_data["deployment_zones"] = zones
	queue_redraw()
	data_changed.emit()


func add_biome(biome_type: String) -> void:
	var biomes: Array = map_data.get("biomes", [])
	var biome: Dictionary = {
		"type": biome_type,
		"x": 100 + biomes.size() * 30,
		"y": 100 + biomes.size() * 30,
		"w": 120,
		"h": 80,
		"layer": 1
	}
	biomes.append(biome)
	map_data["biomes"] = biomes
	_rebuild_draggables()
	queue_redraw()
	data_changed.emit()


func set_biome_layer(idx: int, layer: int) -> void:
	var biomes: Array = map_data.get("biomes", [])
	if idx < 0 or idx >= biomes.size():
		return
	var bd: Dictionary = biomes[idx]
	bd["layer"] = clamp(layer, 1, 6)
	biomes[idx] = bd
	map_data["biomes"] = biomes
	queue_redraw()
	data_changed.emit()


func get_selected_biome_layer() -> int:
	var idx := get_selected_biome_idx()
	if idx < 0:
		return 1
	var biomes: Array = map_data.get("biomes", [])
	return biomes[idx].get("layer", 1)


func delete_biome(idx: int) -> void:
	var biomes: Array = map_data.get("biomes", [])
	if idx < 0 or idx >= biomes.size():
		return
	biomes.remove_at(idx)
	map_data["biomes"] = biomes
	_rebuild_draggables()
	queue_redraw()
	data_changed.emit()


func add_sand_bag() -> void:
	var sand_bags: Array = map_data.get("sand_bags", [])
	var sand_bag: Dictionary = {
		"x": 200 + sand_bags.size() * 25,
		"y": 200 + sand_bags.size() * 25,
		"w": 40,
		"h": 40,
		"layer": 1
	}
	sand_bags.append(sand_bag)
	map_data["sand_bags"] = sand_bags
	_rebuild_draggables()
	queue_redraw()
	data_changed.emit()


func set_sand_bag_layer(idx: int, layer: int) -> void:
	var sand_bags: Array = map_data.get("sand_bags", [])
	if idx < 0 or idx >= sand_bags.size():
		return
	var sd: Dictionary = sand_bags[idx]
	sd["layer"] = clamp(layer, 1, 6)
	sand_bags[idx] = sd
	map_data["sand_bags"] = sand_bags
	queue_redraw()
	data_changed.emit()


func get_selected_sand_bag_layer() -> int:
	var idx := get_selected_sand_bag_idx()
	if idx < 0:
		return 1
	var sand_bags: Array = map_data.get("sand_bags", [])
	return sand_bags[idx].get("layer", 1)


func delete_sand_bag(idx: int) -> void:
	var sand_bags: Array = map_data.get("sand_bags", [])
	if idx < 0 or idx >= sand_bags.size():
		return
	sand_bags.remove_at(idx)
	map_data["sand_bags"] = sand_bags
	_rebuild_draggables()
	queue_redraw()
	data_changed.emit()


func get_selected_biome_idx() -> int:
	if _selected_idx < 0 or _selected_idx >= _draggables.size():
		return -1
	var drag_id: String = _draggables[_selected_idx].get("id", "")
	if not drag_id.begins_with("biome_"):
		return -1
	return int(drag_id.trim_prefix("biome_"))


func get_selected_sand_bag_idx() -> int:
	if _selected_idx < 0 or _selected_idx >= _draggables.size():
		return -1
	var drag_id: String = _draggables[_selected_idx].get("id", "")
	if not drag_id.begins_with("sand_bag_"):
		return -1
	return int(drag_id.trim_prefix("sand_bag_"))


func _zoom_at(factor: float) -> void:
	var mouse_global := get_global_mouse_position()
	var mouse_local := to_local(mouse_global)
	scale *= factor
	scale = scale.clamp(Vector2(0.1, 0.1), Vector2(10, 10))
	position = mouse_global - mouse_local * scale
	_rebuild_resize_handles_if_selected()
	queue_redraw()


func _rebuild_resize_handles_if_selected() -> void:
	if _selected_idx >= 0:
		_build_resize_handles()
