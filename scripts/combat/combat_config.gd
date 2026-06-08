class_name CombatConfig extends RefCounted

enum Side { ATTACKER, DEFENDER }

var map_definition: MapDefinition
var troop_count: int = 0
var troop_scene: PackedScene
var player_side: int = Side.ATTACKER
