class_name Sets
extends RefCounted
## Gear sets: every crustacean family's parts form a set (PartData.set_id).
## Wear every piece of a set, all at Epic or better, and the set bonus turns
## on: a boost to all stats plus perks (which reuse Mods).
## The Debra set is the best gear in the game and needs every piece at Gold,
## so the strongest look in the game is Debra's own.

const SETS := {
	&"debra": {"name": "Headliner (Debra)", "tier": Rarity.Tier.GOLD, "mult": 1.6, "perks": {&"echo": 1, &"vampiric": 2, &"second_wind": 1, &"detonate": 1}},
	&"saul": {"name": "Saul's Set", "mult": 1.25, "perks": {&"sturdy": 1, &"keen": 1}},
	&"louise": {"name": "Louise's Set", "mult": 1.25, "perks": {&"swift": 2, &"echo": 1}},
	&"marjorie": {"name": "Marjorie's Set", "mult": 1.25, "perks": {&"thorns": 1, &"colossus": 1}},
	&"gary": {"name": "Gary's Set", "mult": 1.25, "perks": {&"stormcaller": 1}},
	&"shore": {"name": "Shore Set", "mult": 1.2, "perks": {&"swift": 1}},
	&"fiddler": {"name": "Fiddler Set", "mult": 1.2, "perks": {&"keen": 2}},
	&"hermit": {"name": "Hermit Set", "mult": 1.2, "perks": {&"thorns": 1, &"sturdy": 1}},
	&"mantis": {"name": "Mantis Set", "mult": 1.2, "perks": {&"echo": 1}},
	&"lobster": {"name": "Rock Lobster Set", "mult": 1.2, "perks": {&"keen": 1, &"sturdy": 1}},
	&"shrimp": {"name": "Pistol Shrimp Set", "mult": 1.2, "perks": {&"swift": 1, &"vampiric": 1}},
	&"spider": {"name": "Spider Crab Set", "mult": 1.2, "perks": {&"keen": 1, &"frost": 1}},
	&"coconut": {"name": "Coconut Crab Set", "mult": 1.2, "perks": {&"colossus": 1}},
	&"isopod": {"name": "Isopod Set", "mult": 1.2, "perks": {&"sturdy": 1, &"regen": 2}},
	&"king": {"name": "King Crab Set", "mult": 1.3, "perks": {&"detonate": 1, &"sturdy": 1}},
	&"blue": {"name": "Blue Crab Set", "mult": 1.2, "perks": {&"swift": 1, &"vampiric": 1}},
	&"ghost": {"name": "Ghost Crab Set", "mult": 1.2, "perks": {&"swift": 2}},
	&"yeti": {"name": "Yeti Crab Set", "mult": 1.2, "perks": {&"frost": 1, &"regen": 1}},
	&"squat": {"name": "Squat Lobster Set", "mult": 1.2, "perks": {&"vampiric": 1, &"keen": 1}},
}

static var _pieces: Dictionary = {}


## Every part in a set.
static func pieces(set_id: StringName) -> Array[PartData]:
	if _pieces.is_empty():
		for p in PartCatalog.all_parts():
			if p.set_id != &"" and not p.special:
				if not _pieces.has(p.set_id):
					_pieces[p.set_id] = []
				(_pieces[p.set_id] as Array).append(p)
	var out: Array[PartData] = []
	out.assign(_pieces.get(set_id, []))
	return out


static func required_tier(set_id: StringName) -> int:
	var s: Dictionary = SETS.get(set_id, {})
	return s.get("tier", Rarity.Tier.EPIC)


static func title_of(set_id: StringName) -> String:
	var s: Dictionary = SETS.get(set_id, {})
	return s.get("name", String(set_id).capitalize())


static func describe(set_id: StringName) -> String:
	var s: Dictionary = SETS.get(set_id, {})
	if s.is_empty():
		return ""
	var bits: Array[String] = ["+%d%% HP/ATK/DEF" % roundi((float(s.mult) - 1.0) * 100.0)]
	var perks: Dictionary = s.perks
	for m in perks:
		bits.append(Mods.short_name(m) + (" x%d" % perks[m] if int(perks[m]) > 1 else ""))
	return ", ".join(bits)


## {set_id: {"have": n, "need": n, "good": n}} for every set you're wearing any piece of.
## good = pieces worn at the required tier or better.
static func progress(eq: Equipment) -> Dictionary:
	var out := {}
	for s in Equipment.SOCKET_COUNT:
		var p := eq.get_part(s)
		if p == null or p.data.set_id == &"" or not SETS.has(p.data.set_id):
			continue
		var id := p.data.set_id
		if not out.has(id):
			out[id] = {"have": 0, "need": pieces(id).size(), "good": 0, "_seen": []}
		var row: Dictionary = out[id]
		if not (row._seen as Array).has(p.data.id):
			(row._seen as Array).append(p.data.id)
			row.have += 1
			if p.rarity >= required_tier(id):
				row.good += 1
	for id in out:
		(out[id] as Dictionary).erase("_seen")
	return out


static func active(eq: Equipment) -> Array[StringName]:
	var out: Array[StringName] = []
	var prog := progress(eq)
	for id in prog:
		var row: Dictionary = prog[id]
		if int(row.good) >= int(row.need) and int(row.need) > 0:
			out.append(id)
	return out


## Stat multiplier for HP/ATK/DEF from completed sets (they stack if you somehow complete two).
static func stat_mult(eq: Equipment) -> float:
	var m := 1.0
	for id in active(eq):
		m *= float((SETS[id] as Dictionary).mult)
	return m


## Mods granted by completed sets, as {mod: count}.
static func perks(eq: Equipment) -> Dictionary:
	var out := {}
	for id in active(eq):
		var p: Dictionary = (SETS[id] as Dictionary).perks
		for m in p:
			out[m] = int(out.get(m, 0)) + int(p[m])
	return out
