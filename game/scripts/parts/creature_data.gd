class_name CreatureData
extends Resource
## A creature type: what it wears (its loadout = its parts catalogue), how it
## fights, and what it drops. Lives in res://data/creatures/*.tres.
## Debra and the other playable crabs use this too (their starting loadout).

@export var id: StringName
@export var display_name := ""
@export var playable := false

@export_group("Body")
## Visual/collision size relative to Debra (1.0).
@export var size := 1.0
@export var base_hp := 50.0
@export var head: PartData
@export var shell: PartData
@export var claw_l: PartData
@export var claw_r: PartData
@export var legs: PartData

@export_group("Behaviour")
@export var damage_mult := 0.5
@export var aggro_range := 7.0
## 0 = close to melee. >0 = try to keep this distance (ranged creatures).
@export var preferred_range := 0.0
@export var spawn_weight := 1.0

@export_group("Loot")
## Chance (0..1) that a kill drops a part at all.
@export var drop_chance := 1.0
## Extra parts only this creature drops. Untyped so .tres files stay simple.
@export var special_drops: Array = []
@export var special_chance := 0.1
## Shifts rarity odds up (see Rarity.roll).
@export var rarity_luck := 0.0


## Parts by Equipment.Socket order: head, shell, claw L, claw R, legs.
func loadout() -> Array[PartData]:
	return [head, shell, claw_l, claw_r, legs]


## Everything this creature can drop: its own parts (once each) + specials.
func drop_pool() -> Array[PartData]:
	var pool: Array[PartData] = []
	for p in loadout():
		if p and not pool.has(p):
			pool.append(p)
	for p in special_drops:
		if p is PartData and not pool.has(p):
			pool.append(p)
	return pool


## Rolls a drop for one kill, or null for nothing.
func roll_drop(rng: RandomNumberGenerator) -> PartInstance:
	if rng.randf() >= drop_chance:
		return null
	var part: PartData
	if not special_drops.is_empty() and rng.randf() < special_chance:
		part = special_drops[rng.randi() % special_drops.size()]
	else:
		var own: Array[PartData] = []
		for p in loadout():
			if p and not own.has(p):
				own.append(p)
		part = own[rng.randi() % own.size()]
	return PartInstance.new(part, Rarity.roll(rng, rarity_luck))
