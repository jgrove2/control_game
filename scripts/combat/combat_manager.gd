class_name CombatManager extends Node

enum Phase { DEPLOYMENT, COMBAT }

var config: CombatConfig
var phase: Phase = Phase.DEPLOYMENT

var _soldiers: Array[Soldier] = []
var _game_ui: GameUI
var _map_node: Node2D
var _deployment_zones: Dictionary = {}  # populated from JSON map data

var _selected_placement_slot: int = -1


func _init(config: CombatConfig) -> void:
	self.config = config


func _ready() -> void:
	_load_map()
	_setup_deployment()


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


func _build_from_json(path: String) -> void:
	var jmd := JsonMapDefinition.new(path)
	if not jmd.is_valid():
		return
	_deployment_zones = jmd.get_deployment_zones()

	var ms := jmd.get_map_size()
	var gc := jmd.get_ground_color()

	var ground := Polygon2D.new()
	ground.name = "Ground"
	ground.color = gc
	ground.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(ms.x, 0), Vector2(ms.x, ms.y), Vector2(0, ms.y)
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

	for side in ["attacker", "defender"]:
		var zd := _deployment_zones.get(side, {})
		if zd.is_empty():
			continue
		var zone := Polygon2D.new()
		zone.name = side.capitalize() + "DeployZone"
		var zx := zd.get("x", 0)
		var zy := zd.get("y", 0)
		var zw := zd.get("w", 200)
		var zh := zd.get("h", 300)
		zone.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(zw, 0), Vector2(zw, zh), Vector2(0, zh)
		])
		zone.position = Vector2(zx, zy)
		zone.color = JsonMapDefinition.zone_fill_color(side)
		_map_node.add_child(zone)


func _build_from_scene(path: String) -> void:
	var packed := load(path)
	if not packed:
		return
	var scene := packed.instantiate()
	for child in scene.get_children():
		scene.remove_child(child)
		_map_node.add_child(child)
	scene.queue_free()

	for child in _map_node.get_children():
		if not (child is Polygon2D):
			continue
		var side := ""
		if child.name.begins_with("Attacker") or child.name.begins_with("attacker"):
			side = "attacker"
		elif child.name.begins_with("Defender") or child.name.begins_with("defender"):
			side = "defender"
		else:
			continue
		if _deployment_zones.has(side):
			continue
		var p := child.polygon
		_deployment_zones[side] = {
			"x": child.position.x,
			"y": child.position.y,
			"w": p[2].x if p.size() >= 3 else 200,
			"h": p[2].y if p.size() >= 3 else 300
		}


func _add_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.enabled = true

	var side := "attacker" if config.player_side == CombatConfig.Side.ATTACKER else "defender"
	var zd := _deployment_zones.get(side, {})
	if not zd.is_empty():
		cam.position = Vector2(
			zd.get("x", 0) + zd.get("w", 200) / 2.0,
			zd.get("y", 0) + zd.get("h", 300) / 2.0
		)

	_map_node.add_child(cam)


func get_attacker_deploy_zone() -> Dictionary:
	return _deployment_zones.get("attacker", {})


func get_defender_deploy_zone() -> Dictionary:
	return _deployment_zones.get("defender", {})


func _setup_deployment() -> void:
	_create_ui()
	_game_ui.set_mode(GameUI.Mode.DEPLOYMENT)

	_game_ui.slot_clicked.connect(_on_deploy_slot_clicked)

	for i in range(config.troop_count):
		_game_ui.assign_unit_to_slot(i, null)


func _create_ui() -> void:
	var ui_scene: PackedScene = preload("res://scenes/ui/game_ui.tscn")
	_game_ui = ui_scene.instantiate()
	add_child(_game_ui)
	_game_ui.start_combat_pressed.connect(_on_start_combat)


func _find_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for child in _map_node.get_children():
		if child is Marker2D and child.is_in_group(&"spawn_point"):
			points.append(child.position)
	return points


func _on_deploy_slot_clicked(slot_index: int, soldier: Soldier) -> void:
	if soldier != null:
		_remove_unit(slot_index, soldier)
		return
	_selected_placement_slot = slot_index


func _remove_unit(slot_index: int, soldier: Soldier) -> void:
	_soldiers.erase(soldier)
	soldier.queue_free()
	_game_ui.assign_unit_to_slot(slot_index, null)


func _try_place_unit(global_pos: Vector2) -> void:
	var soldier: Soldier = config.troop_scene.instantiate()
	soldier.unit_name = "Squad %d" % (_selected_placement_slot + 1)
	soldier.team = Soldier.Team.PLAYER
	soldier.position = _map_node.to_local(global_pos)
	_map_node.add_child(soldier)
	_game_ui.assign_unit_to_slot(_selected_placement_slot, soldier)
	_soldiers.append(soldier)
	_selected_placement_slot = -1


func _on_start_combat() -> void:
	phase = Phase.COMBAT

	_game_ui.slot_clicked.disconnect(_on_deploy_slot_clicked)
	_game_ui.start_combat_pressed.disconnect(_on_start_combat)

	_game_ui.unit_selected.connect(_on_unit_selected)
	_game_ui.unit_deselected.connect(_on_unit_deselected)
	_game_ui.set_mode(GameUI.Mode.COMBAT)


func _on_unit_selected(soldier: Soldier, index: int) -> void:
	for s in _soldiers:
		s.set_selected(s == soldier)


func _on_unit_deselected() -> void:
	for s in _soldiers:
		s.set_selected(false)


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.DEPLOYMENT:
		if event is InputEventMouseButton \
				and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			if _selected_placement_slot >= 0:
				_try_place_unit((event as InputEventMouseButton).global_position)
			else:
				_game_ui.deselect_all()
			get_viewport().set_input_as_handled()

		if event.is_action_pressed("ui_cancel"):
			get_parent().return_to_menu()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_game_ui.deselect_all()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		get_parent().return_to_menu()
		get_viewport().set_input_as_handled()
