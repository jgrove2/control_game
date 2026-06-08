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
	_map_node = config.map_definition.get_scene().instantiate()
	add_child(_map_node)

	# If the MapDefinition has a json_path, extract deployment zone info
	if config.map_definition.json_path:
		var jmd := JsonMapDefinition.new(config.map_definition.json_path)
		if jmd.is_valid():
			_deployment_zones = jmd.get_deployment_zones()
			_store_zone_overlays()


# Store zone visual data from the generated scene so deploy logic can reference it
func _store_zone_overlays() -> void:
	for ch in _map_node.get_children():
		if ch.name.ends_with("DeployZone") and ch is Polygon2D:
			var side := "attacker" if ch.name.begins_with("Attacker") else "defender"
			if not _deployment_zones.has(side):
				_deployment_zones[side] = {
					"x": ch.position.x,
					"y": ch.position.y,
					"w": ch.polygon[2].x if ch.polygon.size() >= 3 else 200,
					"h": ch.polygon[2].y if ch.polygon.size() >= 3 else 300
				}


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
