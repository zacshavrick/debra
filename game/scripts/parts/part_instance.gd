class_name PartInstance
extends RefCounted
## A concrete part in the world or on a crab: PartData + rolled rarity.

var data: PartData
var rarity: int = Rarity.Tier.COMMON


func _init(d: PartData = null, r: int = Rarity.Tier.COMMON) -> void:
	data = d
	rarity = r


## Rarity scales bonuses only; penalties (e.g. a heavy shell's -SPD) stay flat.
func stat(stat_name: StringName) -> float:
	var base: float = data.get(stat_name)
	return base * Rarity.multiplier(rarity) if base > 0.0 else base


func display_name() -> String:
	return "%s %s" % [Rarity.name_of(rarity), data.display_name]


func to_dict() -> Dictionary:
	return {"id": String(data.id), "rarity": rarity}


static func from_dict(d: Dictionary) -> PartInstance:
	var p := PartCatalog.by_id(StringName(str(d.get("id", ""))))
	if p == null:
		return null
	return PartInstance.new(p, int(d.get("rarity", 0)))
