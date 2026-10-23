class_name CreatureData
extends Resource
## A creature type. Lives in res://data/creatures/*.tres.
##  - Crustaceans (kind = CRUSTACEAN) use the shared crab rig and wear their
##    loadout, which is exactly what they can drop. Playable starters are
##    crustaceans with `playable = true`.
##  - Other sea creatures (kind = CRITTER) have their own procedural body
##    (`body_kind`, see CritterVisual) and drop only their 1-2 `drops`.

enum Kind { CRUSTACEAN, CRITTER }

@export var id: StringName
@export var display_name := ""
@export var kind: Kind = Kind.CRUSTACEAN
@export var playable := false
## Starters only: their own movement move (see MoveAbility): leap, scuttle, lunge, arc, shimmy.
@export var move_ability: StringName = &""
@export_multiline var blurb := ""
@export var boss := false

@export_group("Body")
## Visual/collision size relative to Debra (1.0).
@export var size := 1.0
@export var base_hp := 50.0
@export var head: PartData
@export var shell: PartData
@export var claw_l: PartData
@export var claw_r: PartData
@export var legs: PartData
@export var tail: PartData
## Critters only: a CritterVisual.KINDS body (starfish, eel, shark, squid, clam...)
@export var body_kind: StringName = &""
@export var color := Color(0.8, 0.5, 0.3)
@export var accent := Color(0.2, 0.1, 0.1)
## Critters only: how high the body floats above the sand.
@export var hover := 0.0
@export var speed := 3.0

@export_group("Behaviour")
@export var damage_mult := 0.5
@export var aggro_range := 7.0
## 0 = close to melee. >0 = try to keep this distance (ranged creatures).
@export var preferred_range := 0.0
@export var spawn_weight := 1.0
## The level generator only uses this creature at this depth or deeper.
@export var min_depth := 1
## Hits poison the target (damage per second for 3 s, before difficulty).
@export var venom := 0.0
## Critters only: melee, ranged, charger, drifter, turret, ambusher (see Critter).
@export var behaviour: StringName = &"melee"
## Critters only: a CritterAttack.ATTACKS key (bite, dash, pierce, spit, volley, spines, pulse, ink, zap, pull).
@export var attack: StringName = &"bite"

@export_group("Loot")
## Chance (0..1) that a kill drops a part at all.
@export var drop_chance := 1.0
## Critters: their only drops. Crustaceans: extra drops besides the loadout.
@export var drops: Array = []
## Extra parts only this creature drops, rolled with special_chance.
@export var special_drops: Array = []
@export var special_chance := 0.1
## Shifts rarity odds up (see Rarity.roll).
@export var rarity_luck := 0.0


func is_crustacean() -> bool:
	return kind == Kind.CRUSTACEAN


## Parts by Equipment.Socket order: head, shell, claw L, claw R, legs, tail.
func loadout() -> Array[PartData]:
	return [head, shell, claw_l, claw_r, legs, tail]


## Regular drops (not specials), each once.
func regular_drops() -> Array[PartData]:
	var own: Array[PartData] = []
	if is_crustacean():
		for p in loadout():
			if p and not own.has(p):
				own.append(p)
	for p in drops:
		if p is PartData and not own.has(p):
			own.append(p)
	return own


## Everything this creature can drop.
func drop_pool() -> Array[PartData]:
	var pool := regular_drops()
	for p in special_drops:
		if p is PartData and not pool.has(p):
			pool.append(p)
	return pool


## Rolls a drop for one kill, or null for nothing.
func roll_drop(rng: RandomNumberGenerator, extra_luck := 0.0, part_level := 1) -> PartInstance:
	if rng.randf() >= drop_chance:
		return null
	var part: PartData
	if not special_drops.is_empty() and rng.randf() < special_chance:
		part = special_drops[rng.randi() % special_drops.size()]
	else:
		var own := regular_drops()
		if own.is_empty():
			return null
		part = own[rng.randi() % own.size()]
	return PartInstance.roll(part, rng, rarity_luck + extra_luck, part_level)
