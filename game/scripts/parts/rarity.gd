class_name Rarity
extends RefCounted
## Rarity tiers. Rolled when a part drops; scales the part's positive stats.
## Legendary parts always roll one mod; Gold parts are far rarer than
## everything else and always roll one unique gold-only mod (see Mods).

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, GOLD }

const NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Gold"]
const COLORS := [
	Color(0.86, 0.86, 0.86),
	Color(0.38, 0.92, 0.42),
	Color(0.32, 0.62, 1.0),
	Color(0.78, 0.42, 1.0),
	Color(1.0, 0.55, 0.15),
	Color(1.0, 0.86, 0.25),
]
const MULTIPLIERS := [1.0, 1.3, 1.7, 2.2, 2.8, 3.5]
## Base drop odds (relative weights). Gold is ~1 in 1700 at depth 1.
const WEIGHTS := [60.0, 28.0, 10.0, 2.0, 0.4, 0.06]


static func name_of(tier: int) -> String:
	return NAMES[clampi(tier, 0, NAMES.size() - 1)]


static func color_of(tier: int) -> Color:
	return COLORS[clampi(tier, 0, COLORS.size() - 1)]


static func multiplier(tier: int) -> float:
	return MULTIPLIERS[clampi(tier, 0, MULTIPLIERS.size() - 1)]


## Rolls a tier. `luck` > 0 shifts odds toward higher tiers. Luck helps up to
## Epic fully; Legendary and Gold only get part of it, so Gold stays rare.
static func roll(rng: RandomNumberGenerator, luck := 0.0) -> int:
	var l := maxf(luck, 0.0)
	var w := PackedFloat32Array()
	for i in WEIGHTS.size():
		var base: float = WEIGHTS[i]
		var boost := pow(1.0 + l, mini(i, 3))
		if i == Tier.LEGENDARY:
			boost *= 1.0 + l * 0.5
		elif i == Tier.GOLD:
			boost *= 1.0 + l * 0.25
		w.append(base * boost)
	return rng.rand_weighted(w)
