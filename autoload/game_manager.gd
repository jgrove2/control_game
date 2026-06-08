extends Node
class_name GameManager

signal game_started
signal game_over


func start_game() -> void:
	game_started.emit()


func end_game() -> void:
	game_over.emit()
