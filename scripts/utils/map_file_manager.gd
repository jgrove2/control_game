extends Node
class_name MapFileManager

const USER_MAPS_DIR := "maps"
const BUILTIN_MAPS_DIR := "res://resources/maps"

static func get_user_maps_dir() -> String:
	return "user://".path_join(USER_MAPS_DIR)

static func ensure_user_maps_dir() -> void:
	DirAccess.make_dir_recursive_absolute(get_user_maps_dir())

static func save_map(map_data: Dictionary) -> bool:
	ensure_user_maps_dir()
	var file_path: String = get_user_maps_dir().path_join(map_data.get("id", "unnamed") + ".json")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("MapFileManager: failed to open ", file_path, " for writing")
		return false
	var json_string := JSON.stringify(map_data, "\t")
	file.store_string(json_string)
	file.close()
	return true

static func load_map_file(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("MapFileManager: JSON parse error in ", file_path, ": ", json.get_error_message())
		return {}
	return json.data

static func get_user_map_paths() -> Array[String]:
	ensure_user_maps_dir()
	var dir := DirAccess.open(get_user_maps_dir())
	var paths: Array[String] = []
	if not dir:
		return paths
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json") and not dir.current_is_dir():
			paths.append(get_user_maps_dir().path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	return paths

static func get_builtin_map_paths() -> Array[String]:
	var dir := DirAccess.open(BUILTIN_MAPS_DIR)
	var paths: Array[String] = []
	if not dir:
		return paths
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".tres") and not dir.current_is_dir():
			paths.append(BUILTIN_MAPS_DIR.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	return paths

static func get_all_map_definitions() -> Array[MapDefinition]:
	var maps: Array[MapDefinition] = []

	for p in get_builtin_map_paths():
		var def: MapDefinition = load(p)
		if def:
			maps.append(def)

	for p in get_user_map_paths():
		var def := MapDefinition.from_json_file(p)
		if def:
			maps.append(def)

	return maps
