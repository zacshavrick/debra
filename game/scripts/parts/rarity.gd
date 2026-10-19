class_name Rarity
extends RefCounted
## Rarity tiers. Rolled when a part drops; scales the part's positive stats.

enum Tier { COMMON, UNCOMMON, RARE, EPIC }

const NAMES := ["Common", "Uncommon", "Rare", "Epic"]
const COLORS := [
	Color(0.86, 0.86, 0.86),
	Color(0.38, 0.92, 0.42),
	Color(0.32, 0.62, 1.0),
	Color(0.78, 0.42, 1.0),
]
const MULTIPLIERS := [1.0, 1.3, 1.7, 2.2]
## Base drop odds (relative weights).
const WEIGHTS := [60.0, 28.0, 10.0, 2.0]


static func name_of(tier: int) -> String:
	return NAMES[clampi(tier, 0, NAMES.size() - 1)]


static func color_of(tier: int) -> Color:
	return COLORS[clampi(tier, 0, COLORS.size() - 1)]


static func multiplier(tier: int) -> float:
	return MULTIPLIERS[clampi(tier, 0, MULTIPLIERS.size() - 1)]


## Rolls a tier. `luck` > 0 shifts odds toward higher tiers (each tier above
## Common is weighted by (1 + luck)^tier).
static func roll(rng: RandomNumberGenerator, luck := 0.0) -> int:
	var w := PackedFloat32Array()
	for i in WEIGHTS.size():
		var base: float = WEIGHTS[i]
		w.append(base * pow(1.0 + maxf(luck, 0.0), i))
	return rng.rand_weighted(w)
