extends CanvasLayer
class_name SkirmishModeSelect


func _ready() -> void:
	%Attacker.pressed.connect(_on_attacker_pressed)
	%Defender.pressed.connect(_on_defender_pressed)
	%VsAI.pressed.connect(_on_vs_ai_pressed)
	%Back.pressed.connect(_on_back_pressed)


func _on_attacker_pressed() -> void:
	_set_side(CombatConfig.Side.ATTACKER)


func _on_defender_pressed() -> void:
	_set_side(CombatConfig.Side.DEFENDER)


func _set_side(side: int) -> void:
	session_manager.player_side = side
	%Attacker.modulate = Color(1, 1, 1, 1) if side == CombatConfig.Side.ATTACKER else Color(0.5, 0.5, 0.5, 0.7)
	%Defender.modulate = Color(1, 1, 1, 1) if side == CombatConfig.Side.DEFENDER else Color(0.5, 0.5, 0.5, 0.7)


func _on_vs_ai_pressed() -> void:
	get_parent().push_menu("res://scenes/ui/map_selection.tscn")


func _on_back_pressed() -> void:
	get_parent().pop_menu()
