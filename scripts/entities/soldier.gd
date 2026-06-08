extends Node2D
class_name Soldier

## Faction the unit belongs to.
enum Team { PLAYER, ENEMY, NEUTRAL }

@export var unit_name: String = "Soldier"
@export var team: Team = Team.PLAYER
@export var strength: float = 100.0
@export var morale: float = 100.0

var inventory: Inventory
var is_selected: bool = false

var _circle_color: Color = Color(0.2, 0.6, 1.0, 1.0)
var _select_color: Color = Color(0.3, 0.8, 1.0, 0.5)


func _ready() -> void:
	# Set team color
	match team:
		Team.PLAYER:
			_circle_color = Color(0.2, 0.6, 1.0, 1.0)
		Team.ENEMY:
			_circle_color = Color(1.0, 0.2, 0.2, 1.0)
		Team.NEUTRAL:
			_circle_color = Color(0.8, 0.8, 0.2, 1.0)

	# Create inventory node at runtime
	inventory = Inventory.new()
	inventory.name = "Inventory"
	add_child(inventory)
	inventory.owner = self

	queue_redraw()


func set_selected(selected: bool) -> void:
	if is_selected == selected:
		return
	is_selected = selected
	queue_redraw()


func _draw() -> void:
	var radius: float = 16.0
	var line_width: float = 3.0

	# Selection highlight: filled circle behind the hollow one
	if is_selected:
		draw_circle(Vector2.ZERO, radius + 4.0, _select_color)

	# Hollow circle outline (team color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, _circle_color, line_width)
