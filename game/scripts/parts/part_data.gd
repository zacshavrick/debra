class_name PartData
extends Resource
## One body part definition (data only). Lives in res://data/parts/*.tres.
## A dropped part is a PartInstance: this data plus a rolled rarity.
##
## Look: either `visual_scene` (an authored model whose origin is the attach
## point; claws are built for the RIGHT side, +X) or, while we're on
## placeholders, the procedural `shape` parameters read by PartVisual.

enum Slot { HEAD, SHELL, CLAW, LEGS, TAIL }

@export var id: StringName
@export var display_name := ""
@export var slot: Slot = Slot.HEAD
@export_multiline var description := ""

@export_group("Stats")
@export var max_hp := 0.0
@export var attack := 0.0
@export var defense := 0.0
@export var speed := 0.0

@export_group("Ability")
## Claws: the attack style this claw gives (a key of CrabCombat.STYLES).
## Tails: what the tail does on its own (a key of TailBrain.TAILS).
## Head, shell, legs: reserved for passives (not designed yet).
@export var ability: StringName = &""

@export_group("Look")
@export var color := Color(0.9, 0.45, 0.25)
@export var accent := Color(0.15, 0.08, 0.05)
## Procedural placeholder parameters, see PartVisual. Ignored if visual_scene is set.
@export var shape: Dictionary = {}
@export var visual_scene: PackedScene

@export_group("Drops")
## Special parts only drop from creatures that list them in `special_drops`.
@export var special := false

const STATS: Array[StringName] = [&"max_hp", &"attack", &"defense", &"speed"]
const STAT_LABELS := {&"max_hp": "HP", &"attack": "ATK", &"defense": "DEF", &"speed": "SPD"}


static func slot_name(s: int) -> String:
	return ["Head", "Shell", "Claw", "Legs", "Tail"][s]
