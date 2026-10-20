class_name PartInstance
extends RefCounted
## A concrete part in the world or on a crab: PartData + rolled rarity +
## part level (the depth it dropped at). Both rarity and level scale the
## part's bonuses, so parts from deeper levels are stronger.

## Each level above 1 adds this much to a part's bonuses (level 11 = x2.2).
const PER_LEVEL := 0.12

var data: PartData
var rarity: int = Rarity.Tier.COMMON
var level := 1
## Legendary: a regular mod. Gold: a unique gold-only mod. Others: none (see Mods).
var mod: StringName = &""


func _init(d: PartData = null, r: int = Rarity.Tier.COMMON, lvl := 1, m: StringName = &"") -> void:
	data = d
	rarity = r
	level = maxi(lvl, 1)
	mod = m


static func level_mult(lvl: int) -> float:
	return 1.0 + PER_LEVEL * (maxi(lvl, 1) - 1)


## How much stronger than a Common level-1 copy this part is.
func power() -> float:
	return Rarity.multiplier(rarity) * level_mult(level)


## Rarity and level scale bonuses only; penalties (e.g. a heavy shell's -SPD) stay flat.
## SPD scales gently, or deep legs would make you teleport.
func stat(stat_name: StringName) -> float:
	var base: float = data.get(stat_name)
	if base <= 0.0:
		return base
	if stat_name == &"speed":
		return base * Rarity.multiplier(rarity) * (1.0 + 0.02 * (level - 1))
	return base * power()


func display_name() -> String:
	return "%s %s" % [Rarity.name_of(rarity), data.display_name]


## "Rare Shark Jaw  Lv 12"
func full_name() -> String:
	if mod != &"":
		return "%s  Lv %d  [%s]" % [display_name(), level, Mods.short_name(mod)]
	return "%s  Lv %d" % [display_name(), level]


func to_dict() -> Dictionary:
	return {"id": String(data.id), "rarity": rarity, "level": level, "mod": String(mod)}


static func from_dict(d: Dictionary) -> PartInstance:
	var p := PartCatalog.by_id(StringName(str(d.get("id", ""))))
	if p == null:
		return null
	return PartInstance.new(p, int(d.get("rarity", 0)), int(d.get("level", 1)), StringName(str(d.get("mod", ""))))


## Debra's own pieces: the top set. Gold rolls sometimes turn into one of these.
const DEBRA_SET: Array[StringName] = [&"debra_eyes", &"debra_shell", &"debra_crusher", &"debra_cutter", &"debra_legs", &"debra_tail"]
const GOLDEN_DEBRA_CHANCE := 0.15


## A fresh drop: rolls rarity (and its mod). A Gold roll has a chance to be a
## Golden Debra piece instead of `part`.
static func roll(part: PartData, rng: RandomNumberGenerator, luck: float, lvl: int) -> PartInstance:
	var tier := Rarity.roll(rng, luck)
	if tier == Rarity.Tier.GOLD and rng.randf() < GOLDEN_DEBRA_CHANCE:
		var p := PartCatalog.by_id(DEBRA_SET[rng.randi() % DEBRA_SET.size()])
		if p:
			part = p
	return PartInstance.new(part, tier, lvl, Mods.roll_for(tier, rng))


## Raise or lower the tier after the fact (boss/champion guarantees), keeping the mod rules.
func set_tier(tier: int, rng: RandomNumberGenerator) -> void:
	if tier == rarity:
		return
	rarity = tier
	mod = Mods.roll_for(tier, rng)
