extends Node2D

var menu_stack: Array[Node] = []
var current_combat: CombatManager = null


func _ready() -> void:
	push_menu("res://scenes/ui/main_menu.tscn")


func push_menu(scene_path: String) -> void:
	var scene: PackedScene = load(scene_path)
	var menu: Node = scene.instantiate()
	add_child(menu)
	if menu_stack.size() > 0:
		menu_stack[-1].visible = false
	menu_stack.append(menu)


func pop_menu() -> void:
	if menu_stack.size() <= 1:
		return
	var top: Node = menu_stack.pop_back()
	top.queue_free()
	menu_stack[-1].visible = true


func start_combat(config: CombatConfig) -> void:
	while menu_stack.size() > 0:
		var menu: Node = menu_stack.pop_back()
		menu.queue_free()

	game_manager.start_game()

	current_combat = CombatManager.new(config)
	add_child(current_combat)


func return_to_menu() -> void:
	if current_combat:
		current_combat.queue_free()
		current_combat = null

	push_menu("res://scenes/ui/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if menu_stack.size() > 1:
			pop_menu()
			get_viewport().set_input_as_handled()
