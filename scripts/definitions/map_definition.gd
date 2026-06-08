extends Resource
class_name MapDefinition

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var scene_path: String = ""
@export var json_path: String = ""
@export var thumbnail: Texture2D


static func from_json_file(path: String) -> MapDefinition:
	var jmd := JsonMapDefinition.new(path)
	if not jmd.is_valid():
		return null
	var def := new()
	def.id = jmd.get_id()
	def.display_name = jmd.get_display_name()
	def.description = jmd.get_description()
	def.json_path = path
	return def
