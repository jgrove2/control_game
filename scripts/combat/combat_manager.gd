class_name CombatManager extends Node

var config: CombatConfig
var _map_node: Node2D
var _map_size: Vector2 = Vector2(1600, 900)
var _deployment_zones: Dictionary = {}
var _camera: Camera2D
var _zoom_min := 1.0   # <-- add this here, at class scope

const ZOOM_MAX := 5.0
const ZOOM_START := 2.0
const PAN_SPEED := 500.0


func _init(config: CombatConfig) -> void:
	self.config = config


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	set_process(true)
	_load_map()
	get_viewport().size_changed.connect(_update_min_zoom)


func _load_map() -> void:
	var md := config.map_definition
	_map_node = Node2D.new()
	_map_node.name = md.id if md.id else "Map"

	if md.json_path:
		_build_from_json(md.json_path)
	elif md.scene_path:
		_build_from_scene(md.scene_path)

	add_child(_map_node)
	_add_camera()

func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir != Vector2.ZERO:
		_camera.position += dir.normalized() * PAN_SPEED * delta / _camera.zoom.x
		_clamp_camera()


func _clamp_camera() -> void:
	var half_view := get_viewport().get_visible_rect().size / (2.0 * _camera.zoom.x)
	# If the view is bigger than the map on an axis, lock to map center on that axis.
	var min_x: float
	var max_x: float
	if half_view.x * 2.0 >= _map_size.x:
		min_x = _map_size.x / 2.0
		max_x = _map_size.x / 2.0
	else:
		min_x = half_view.x
		max_x = _map_size.x - half_view.x

	var min_y: float
	var max_y: float
	if half_view.y * 2.0 >= _map_size.y:
		min_y = _map_size.y / 2.0
		max_y = _map_size.y / 2.0
	else:
		min_y = half_view.y
		max_y = _map_size.y - half_view.y

	_camera.position.x = clamp(_camera.position.x, min_x, max_x)
	_camera.position.y = clamp(_camera.position.y, min_y, max_y)

func _build_from_json(path: String) -> void:
	var jmd := JsonMapDefinition.new(path)
	if not jmd.is_valid():
		return

	_map_size = jmd.get_map_size()
	_deployment_zones = jmd.get_deployment_zones()
	var gc := jmd.get_ground_color()

	var ground := Polygon2D.new()
	ground.name = "Ground"
	ground.color = gc
	ground.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(_map_size.x, 0), Vector2(_map_size.x, _map_size.y), Vector2(0, _map_size.y)
	])
	_map_node.add_child(ground)

	for s in jmd.get_shapes():
		var n := JsonMapDefinition._build_polygon(s, false)
		if n:
			_map_node.add_child(n)

	for b in jmd.get_barriers():
		var n := JsonMapDefinition._build_polygon(b, true)
		if n:
			_map_node.add_child(n)

	for b in jmd.get_biomes():
		var n := JsonMapDefinition._build_biome_polygon(b)
		if n:
			_map_node.add_child(n)

	for s in jmd.get_sand_bags():
		var n := JsonMapDefinition._build_sand_bag_polygon(s)
		if n:
			_map_node.add_child(n)


func _build_from_scene(path: String) -> void:
	var packed: PackedScene = load(path)
	if not packed:
		return
	var scene: Node = packed.instantiate()
	for child in scene.get_children():
		scene.remove_child(child)
		_map_node.add_child(child)
	scene.queue_free()


func _add_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.enabled = true

	_update_min_zoom()
	var start_zoom: float = max(ZOOM_START, _zoom_min)
	_camera.zoom = Vector2(start_zoom, start_zoom)

	var side := "attacker" if config.player_side == CombatConfig.Side.ATTACKER else "defender"
	var zd: Dictionary = _deployment_zones.get(side, {})
	if not zd.is_empty():
		_camera.position = Vector2(
			zd.get("x", 0) + zd.get("w", 200) / 2.0,
			zd.get("y", 0) + zd.get("h", 300) / 2.0
		)
	else:
		_camera.position = _map_size / 2.0

	_map_node.add_child(_camera)
	_clamp_camera()

func _update_min_zoom() -> void:
	# zoom that makes the view exactly fit the map on each axis;
	# take the larger so neither axis ever shows past the map edge
	var vp := get_viewport().get_visible_rect().size
	var fit_x := vp.x / _map_size.x
	var fit_y := vp.y / _map_size.y
	_zoom_min = max(fit_x, fit_y)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_parent().return_to_menu()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var zoom_dir := 0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_dir = 1
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_dir = -1

		if zoom_dir != 0:
			var factor := 1.1 if zoom_dir > 0 else 0.9
			var old_zoom := _camera.zoom.x
			var z: float = clamp(_camera.zoom.x * factor, _zoom_min, ZOOM_MAX)
			_camera.zoom = Vector2(z, z)

			var mouse_viewport := get_viewport().get_mouse_position()
			var viewport_size := get_viewport().get_visible_rect().size
			var world_before := _camera.position + (mouse_viewport - viewport_size / 2.0) / old_zoom
			var world_after := _camera.position + (mouse_viewport - viewport_size / 2.0) / _camera.zoom.x
			_camera.position += world_before - world_after
			_clamp_camera()
			get_viewport().set_input_as_handled()
