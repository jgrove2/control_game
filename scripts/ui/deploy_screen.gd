extends CanvasLayer
class_name DeployScreen

var selected_count: int = 0

const BUDGET: int = 100
const TROOP_COST: int = 25
const MAX_TROOPS: int = BUDGET / TROOP_COST


func _ready() -> void:
	%AddButton.pressed.connect(_on_add)
	%RemoveButton.pressed.connect(_on_remove)
	%StartButton.pressed.connect(_on_start)
	%BackButton.pressed.connect(_on_back)
	_update_display()


func _on_add() -> void:
	selected_count += 1
	_update_display()


func _on_remove() -> void:
	if selected_count > 0:
		selected_count -= 1
		_update_display()


func _on_start() -> void:
	if selected_count < 1 or session_manager.pending_config == null:
		return
	session_manager.pending_config.troop_count = selected_count
	session_manager.pending_config.troop_scene = preload("res://scenes/entities/soldier.tscn")
	get_parent().start_combat(session_manager.pending_config)
	session_manager.pending_config = null


func _on_back() -> void:
	get_parent().pop_menu()


func _update_display() -> void:
	var used: int = selected_count * TROOP_COST
	var remaining: int = BUDGET - used

	%BudgetLabel.text = "Budget: $%d" % BUDGET
	%RemainingLabel.text = "Remaining: $%d" % remaining
	%TroopNameLabel.text = "DEFAULT SOLDIER"
	%TroopCostLabel.text = "$%d" % TROOP_COST
	%CountLabel.text = "%d" % selected_count
	%TotalLabel.text = "Total Deployed: %d / %d" % [selected_count, MAX_TROOPS]

	%AddButton.disabled = (selected_count >= MAX_TROOPS)
	%RemoveButton.disabled = (selected_count <= 0)
	%StartButton.disabled = (selected_count <= 0)
