extends CanvasLayer
class_name MapSelection

var map_options: Array[MapDefinition] = []


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	_refresh_map_list()


func _refresh_map_list() -> void:
	map_options = MapFileManager.get_all_map_definitions()

	# Rebuild map buttons dynamically
	var grid := %GridContainer as GridContainer
	if not grid:
		return

	# Clear old buttons (keep first child as template)
	for ch in grid.get_children():
		grid.remove_child(ch)
		ch.queue_free()

	for i in map_options.size():
		var def: MapDefinition = map_options[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 120)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		btn.text = def.display_name
		if def.description:
			btn.tooltip_text = def.description
		var idx := i
		btn.pressed.connect(func(): _on_map_pressed(idx))
		grid.add_child(btn)


func _on_map_pressed(index: int) -> void:
	if index < 0 or index >= map_options.size():
		return
	var config := CombatConfig.new()
	config.map_definition = map_options[index]
	config.player_side = session_manager.player_side
	session_manager.pending_config = config
	get_parent().push_menu("res://scenes/ui/deploy_screen.tscn")


func _on_back_pressed() -> void:
	get_parent().pop_menu()
