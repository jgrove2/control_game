extends Resource
class_name InventoryItem

enum SlotType { GUN, HELMET, BODY_ARMOR, BACKPACK }

@export var slot_type: SlotType
@export var item_name: String = ""
@export var icon: Texture2D

# Generic stat modifiers — individual items define their own keys
@export var stats: Dictionary = {}
