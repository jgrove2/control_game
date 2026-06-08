extends Node
class_name Inventory

signal item_equipped(slot: int, item: InventoryItem)
signal item_unequipped(slot: int)

var slots: Dictionary = {
	InventoryItem.SlotType.GUN: null,
	InventoryItem.SlotType.HELMET: null,
	InventoryItem.SlotType.BODY_ARMOR: null,
	InventoryItem.SlotType.BACKPACK: null,
}


func equip(item: InventoryItem) -> void:
	slots[item.slot_type] = item
	item_equipped.emit(item.slot_type, item)


func unequip(slot_type: int) -> InventoryItem:
	var item: InventoryItem = slots.get(slot_type)
	slots[slot_type] = null
	item_unequipped.emit(slot_type)
	return item


func get_item(slot_type: int) -> InventoryItem:
	return slots.get(slot_type)


func has_item(slot_type: int) -> bool:
	return slots.get(slot_type) != null
