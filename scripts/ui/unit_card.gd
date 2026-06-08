extends Panel
class_name UnitCard

enum Status { ALIVE, WOUNDED, KIA }

signal clicked(slot_index: int, soldier: Soldier)

var _soldier: Soldier
var _slot_index: int = -1
var _is_selected: bool = false

var _team_color: Color = Color(0.2, 0.6, 1.0, 1.0)

@onready var squad_label: Label = $%SquadLabel
@onready var soldier_icon: SoldierIcon = $%SoldierIcon
@onready var strength_label: Label = $%StrengthLabel
@onready var status_bar: ColorRect = $%StatusBar
@onready var status_label: Label = $%StatusLabel
@onready var selection_overlay: ColorRect = $%SelectionOverlay


func setup(soldier: Soldier, slot_index: int) -> void:
	_soldier = soldier
	_slot_index = slot_index

	squad_label.text = "%d" % (slot_index + 1)

	if soldier == null:
		soldier_icon.modulate = Color(0.5, 0.5, 0.5, 0.3)
		soldier_icon.set_icon_color(Color(0.5, 0.5, 0.5))
		strength_label.text = "--"
		status_label.text = "EMPTY"
		status_bar.color = Color(0.3, 0.3, 0.3, 1.0)
		_set_selected_visual(false)
		return

	strength_label.text = "%d%%" % int(soldier.strength)

	match soldier.team:
		Soldier.Team.PLAYER:
			_team_color = Color(0.2, 0.6, 1.0, 1.0)
		Soldier.Team.ENEMY:
			_team_color = Color(1.0, 0.2, 0.2, 1.0)
		Soldier.Team.NEUTRAL:
			_team_color = Color(0.8, 0.8, 0.2, 1.0)

	soldier_icon.modulate = Color(1, 1, 1, 1)
	soldier_icon.set_icon_color(_team_color)
	_refresh_status()
	_set_selected_visual(false)


func set_selected(selected: bool) -> void:
	_is_selected = selected
	_set_selected_visual(selected)


func _set_selected_visual(selected: bool) -> void:
	selection_overlay.visible = selected


func _refresh_status() -> void:
	if _soldier.strength <= 0:
		status_label.text = "KIA"
		status_bar.color = Color(0.7, 0.1, 0.1, 1.0)
	elif _soldier.strength < 50:
		status_label.text = "WOUNDED"
		status_bar.color = Color(0.8, 0.6, 0.1, 1.0)
	else:
		status_label.text = "ALIVE"
		status_bar.color = Color(0.2, 0.7, 0.2, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(_slot_index, _soldier)
		accept_event()
