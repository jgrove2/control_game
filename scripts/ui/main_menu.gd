extends CanvasLayer
class_name MainMenu


func _ready() -> void:
	%Exit.pressed.connect(_on_exit_pressed)
	%Skirmish.pressed.connect(_on_skirmish_pressed)
	%MapCreator.pressed.connect(_on_map_creator_pressed)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_skirmish_pressed() -> void:
	get_parent().push_menu("res://scenes/ui/skirmish_mode_select.tscn")


func _on_map_creator_pressed() -> void:
	get_parent().push_menu("res://scenes/ui/map_creator.tscn")
