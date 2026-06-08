extends CanvasLayer
class_name GameUI

enum Mode { DEPLOYMENT, COMBAT }

const MAX_UNITS := 12

signal unit_selected(soldier: Soldier, index: int)
signal unit_deselected()
signal slot_clicked(slot_index: int, soldier: Soldier)
signal start_combat_pressed

var unit_slots: Array[Panel] = []
var selected_index: int = -1
var selected_soldier: Soldier = null
var mode: Mode = Mode.COMBAT

var _slot_cards: Array[UnitCard] = []


func _ready() -> void:
	var grid := %Grid as GridContainer
	if grid:
		for child in grid.get_children():
			var panel := child as Panel
			if panel:
				unit_slots.append(panel)

	_slot_cards.resize(MAX_UNITS)
	%StartCombatButton.pressed.connect(_on_start_combat_pressed)


func set_mode(m: Mode) -> void:
	mode = m
	%StartCombatButton.visible = (m == Mode.DEPLOYMENT)


func get_slot_count() -> int:
	return MAX_UNITS


func assign_unit_to_slot(slot_index: int, soldier: Soldier) -> void:
	if slot_index < 0 or slot_index >= unit_slots.size():
		return

	var slot: Panel = unit_slots[slot_index]
	for child in slot.get_children():
		child.queue_free()

	var card_scene: PackedScene = preload("res://scenes/ui/unit_card.tscn")
	var card: UnitCard = card_scene.instantiate()
	slot.add_child(card)
	card.setup(soldier, slot_index)
	card.clicked.connect(_on_card_clicked)

	_slot_cards[slot_index] = card


func _on_card_clicked(slot_index: int, soldier: Soldier) -> void:
	if mode == Mode.DEPLOYMENT:
		if soldier != null:
			slot_clicked.emit(slot_index, soldier)
			return

		if selected_index >= 0 and selected_index < _slot_cards.size():
			var old_card: UnitCard = _slot_cards[selected_index]
			if old_card != null:
				old_card.set_selected(false)

		if selected_index == slot_index:
			selected_index = -1
			selected_soldier = null
		else:
			selected_index = slot_index
			selected_soldier = soldier
			var card: UnitCard = _slot_cards[slot_index]
			if card != null:
				card.set_selected(true)

		slot_clicked.emit(slot_index, soldier)
		return

	if selected_index == slot_index:
		_deselect_current()
		return

	if selected_index >= 0 and selected_index < _slot_cards.size():
		var old_card: UnitCard = _slot_cards[selected_index]
		if old_card != null:
			old_card.set_selected(false)

	selected_index = slot_index
	selected_soldier = soldier

	var card: UnitCard = _slot_cards[slot_index]
	if card != null:
		card.set_selected(true)

	unit_selected.emit(soldier, slot_index)


func deselect_all() -> void:
	_deselect_current()


func _deselect_current() -> void:
	if selected_index >= 0 and selected_index < _slot_cards.size():
		var old_card: UnitCard = _slot_cards[selected_index]
		if old_card != null:
			old_card.set_selected(false)

	selected_index = -1
	selected_soldier = null
	unit_deselected.emit()


func clear_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= unit_slots.size():
		return

	var slot: Panel = unit_slots[slot_index]
	for child in slot.get_children():
		child.queue_free()

	if slot_index < _slot_cards.size():
		_slot_cards[slot_index] = null

	if slot_index == selected_index:
		_deselect_current()


func clear_all_slots() -> void:
	for i in unit_slots.size():
		clear_slot(i)


func _on_start_combat_pressed() -> void:
	start_combat_pressed.emit()
