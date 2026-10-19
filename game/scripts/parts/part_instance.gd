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


func _init(d: PartData = null, r: int = Rarity.Tier.COMMON, lvl := 1) -> void:
	data = d
	rarity = r
	level = maxi(lvl, 1)


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
	return "%s  Lv %d" % [display_name(), level]


func to_dict() -> Dictionary:
	return {"id": String(data.id), "rarity": rarity, "level": level}


static func from_dict(d: Dictionary) -> PartInstance:
	var p := PartCatalog.by_id(StringName(str(d.get("id", ""))))
	if p == null:
		return null
	return PartInstance.new(p, int(d.get("rarity", 0)), int(d.get("level", 1)))
