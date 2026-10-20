class_name Mods
extends RefCounted
## Part mods (and set-bonus perks, which reuse them). Legendary parts roll one
## regular mod; Gold parts roll one unique gold-only mod. A crab's active mods
## = the mods on everything it wears + perks from completed sets.
## Effects hook into combat through Crab (on hit, on kill, cheat death) and
## stats through Crab.apply_stats.

const REGULAR := {
	&"vampiric": "Vampiric: heal 8% of damage dealt",
	&"thorns": "Thorns: reflect 15% of melee damage",
	&"swift": "Swift: +15% speed",
	&"sturdy": "Sturdy: +20% max HP",
	&"keen": "Keen: +20% damage",
	&"lucky": "Lucky: better loot",
	&"regen": "Regen: heal 1% HP per second",
	&"magnet": "Magnet: pick up parts from further away",
}
const GOLD := {
	&"echo": "Echo: every claw strike hits again",
	&"detonate": "Detonate: kills explode, hurting everything nearby",
	&"stormcaller": "Stormcaller: hits chain lightning to 2 more enemies",
	&"second_wind": "Second wind: once per dive, survive a killing blow",
	&"colossus": "Colossus: +40% HP, bigger, can't be knocked back",
	&"midas": "Midas: everything you kill drops an extra part",
	&"timeless": "Timeless: shell ability cooldowns -40%",
	&"frost": "Frost: hits slow enemies",
}


static func info(id: StringName) -> String:
	if REGULAR.has(id):
		return REGULAR[id]
	return GOLD.get(id, String(id))


static func short_name(id: StringName) -> String:
	return info(id).get_slice(":", 0)


static func is_gold(id: StringName) -> bool:
	return GOLD.has(id)


## Picks a mod for a freshly rolled part (or &"" for none).
static func roll_for(tier: int, rng: RandomNumberGenerator) -> StringName:
	if tier == Rarity.Tier.GOLD:
		var g: Array = GOLD.keys()
		return g[rng.randi() % g.size()]
	if tier == Rarity.Tier.LEGENDARY:
		var r: Array = REGULAR.keys()
		return r[rng.randi() % r.size()]
	return &""


# --- Effects (called by Crab) ------------------------------------------------------

static func on_hit(owner_: Crab, target: Creature, dealt: float, active: Dictionary) -> void:
	if active.has(&"vampiric"):
		owner_.health.heal(dealt * 0.08 * active[&"vampiric"])
	if active.has(&"frost"):
		target.slow(0.55, 2.0)
	if active.has(&"stormcaller"):
		var hit: Array[Creature] = [target]
		var from := target.global_position + Vector3(0, 0.5, 0)
		for i in 2:
			var best: Creature = null
			var best_d := 5.0
			for n in owner_.get_tree().get_nodes_in_group("creatures"):
				var c := n as Creature
				if c == null or c.team == owner_.team or c.is_dead() or hit.has(c):
					continue
				var d := c.global_position.distance_to(from)
				if d < best_d:
					best_d = d
					best = c
			if best == null:
				break
			var to := best.global_position + Vector3(0, 0.5, 0)
			FX.lightning(owner_.get_parent(), from, to, Color(0.6, 0.85, 1.0))
			best.receive_hit(dealt * 0.4, from, 1.0, null)   # null source: no chain reactions
			hit.append(best)
			from = to


static func on_kill(owner_: Crab, victim: Creature, active: Dictionary) -> void:
	if active.has(&"detonate"):
		var r := 2.8 * maxf(victim.size, 1.0)
		var dmg := minf(victim.health.max_hp * 0.3, owner_.combat.damage_for(0) * 3.0)
		FX.shockwave(owner_.get_parent(), victim.global_position, r, Color(1.0, 0.7, 0.25))
		for t in Melee.targets(owner_, victim.global_position, Vector3.FORWARD, r, 360.0):
			t.receive_hit(dmg, victim.global_position, 4.0, null)


## Stat multipliers from mods: {max_hp, damage, speed}.
static func stat_mults(active: Dictionary) -> Dictionary:
	var m := {&"max_hp": 1.0, &"damage": 1.0, &"speed": 1.0}
	m[&"max_hp"] *= pow(1.2, active.get(&"sturdy", 0)) * (1.4 if active.has(&"colossus") else 1.0)
	m[&"damage"] *= pow(1.2, active.get(&"keen", 0))
	m[&"speed"] *= pow(1.15, active.get(&"swift", 0))
	return m
