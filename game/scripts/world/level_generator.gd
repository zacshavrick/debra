class_name LevelGenerator
extends RefCounted
## Makes a level for any depth past the hand-made ones. Deterministic: the
## same depth always gives the same level (seeded from the depth), so
## "depth 23 is brutal" means the same thing for everyone.
##
## Ingredients: a biome (palette + decor), an arena layout, a creature mix
## with a featured creature, an objective, modifiers, and a chimera boss
## wearing parts stolen from other creatures, with traits.

const BIOMES := {
	&"shallows": {"name": "Sunlit Shallows", "min": 1, "sand_a": Color(0.62, 0.56, 0.42), "sand_b": Color(0.48, 0.43, 0.32), "bg": Color(0.07, 0.3, 0.38), "fog": Color(0.1, 0.36, 0.42), "amb": Color(0.4, 0.6, 0.65), "sun": Color(0.85, 0.95, 1.0), "caustics": 0.18},
	&"kelp": {"name": "Kelp Maze", "min": 2, "sand_a": Color(0.42, 0.38, 0.28), "sand_b": Color(0.3, 0.28, 0.2), "bg": Color(0.04, 0.2, 0.17), "fog": Color(0.06, 0.26, 0.2), "amb": Color(0.35, 0.5, 0.45), "sun": Color(0.75, 1.0, 0.8), "caustics": 0.1},
	&"reef": {"name": "Coral Gardens", "min": 3, "sand_a": Color(0.55, 0.48, 0.42), "sand_b": Color(0.4, 0.34, 0.33), "bg": Color(0.05, 0.22, 0.38), "fog": Color(0.08, 0.28, 0.45), "amb": Color(0.45, 0.55, 0.75), "sun": Color(0.85, 0.92, 1.0), "caustics": 0.16},
	&"wreck": {"name": "Ship Graveyard", "min": 4, "sand_a": Color(0.36, 0.34, 0.3), "sand_b": Color(0.26, 0.25, 0.23), "bg": Color(0.03, 0.1, 0.15), "fog": Color(0.04, 0.13, 0.18), "amb": Color(0.3, 0.42, 0.5), "sun": Color(0.6, 0.78, 0.9), "caustics": 0.05},
	&"abyss": {"name": "Glowing Dark", "min": 5, "sand_a": Color(0.2, 0.2, 0.26), "sand_b": Color(0.12, 0.12, 0.17), "bg": Color(0.01, 0.02, 0.06), "fog": Color(0.02, 0.03, 0.08), "amb": Color(0.3, 0.36, 0.6), "sun": Color(0.4, 0.5, 0.8), "caustics": 0.0},
	&"vents": {"name": "Smoking Vents", "min": 6, "sand_a": Color(0.25, 0.2, 0.18), "sand_b": Color(0.15, 0.11, 0.1), "bg": Color(0.08, 0.03, 0.03), "fog": Color(0.18, 0.07, 0.04), "amb": Color(0.6, 0.35, 0.25), "sun": Color(1.0, 0.6, 0.4), "caustics": 0.0},
	&"sargassum": {"name": "Sargassum Drift", "min": 6, "sand_a": Color(0.5, 0.45, 0.3), "sand_b": Color(0.36, 0.32, 0.2), "bg": Color(0.12, 0.18, 0.1), "fog": Color(0.2, 0.25, 0.12), "amb": Color(0.55, 0.55, 0.35), "sun": Color(1.0, 0.95, 0.7), "caustics": 0.12},
	&"ice": {"name": "Cold Seep", "min": 7, "sand_a": Color(0.46, 0.52, 0.58), "sand_b": Color(0.33, 0.38, 0.45), "bg": Color(0.04, 0.1, 0.18), "fog": Color(0.1, 0.18, 0.28), "amb": Color(0.42, 0.52, 0.68), "sun": Color(0.8, 0.9, 1.0), "caustics": 0.08},
	&"trench": {"name": "Black Trench", "min": 8, "sand_a": Color(0.16, 0.16, 0.18), "sand_b": Color(0.09, 0.09, 0.11), "bg": Color(0.0, 0.0, 0.02), "fog": Color(0.01, 0.01, 0.03), "amb": Color(0.3, 0.3, 0.45), "sun": Color(0.45, 0.5, 0.7), "caustics": 0.0},
	&"bones": {"name": "Whale Fall", "min": 9, "sand_a": Color(0.4, 0.38, 0.36), "sand_b": Color(0.28, 0.27, 0.26), "bg": Color(0.02, 0.06, 0.1), "fog": Color(0.04, 0.08, 0.12), "amb": Color(0.4, 0.42, 0.55), "sun": Color(0.6, 0.7, 0.85), "caustics": 0.02},
}
const LAYOUTS: Array[StringName] = [&"open", &"pillars", &"ring", &"canyon", &"islands"]
const OBJECTIVES: Array[StringName] = [&"cull", &"waves", &"hunt"]
const MODIFIERS := {
	&"swarm": "Swarm: twice as many creatures, half the HP each",
	&"armored": "Armoured: creatures take 35% less damage",
	&"venom": "Venom tide: every hit poisons. Yours too",
	&"dark": "Dark water: thick fog, glowing creatures",
	&"treasure": "Treasure current: much better loot",
	&"champions": "Champions: some creatures are elites wearing stolen parts",
	&"riptide": "Riptide: a current keeps pushing everyone",
	&"frenzy": "Frenzy: creatures move and attack faster",
}
const ADJECTIVES := ["Barnacled", "Ravenous", "Gnarled", "Glittering", "Hollow-eyed", "Rusted", "Colossal", "Grumpy",
	"Many-limbed", "Abyssal", "Bloated", "Ancient", "Furious", "Patchwork", "Moonlit", "Crooked"]
const TITLES := ["the Hoarder", "Who Ate the Reef", "of the Deep", "the Unfinished", "Wearer of Others",
	"the Collector", "Twice-Shelled", "the Hungry Tide", "Breaker of Claws", "the Stitched"]

static var _cache: Dictionary = {}


static func difficulty(depth: int) -> float:
	return 1.0 + 0.25 * (depth - 1)


static func luck(depth: int) -> float:
	return minf(0.3 * (depth - 1), 3.0)


static func generate(depth: int) -> LevelData:
	if _cache.has(depth):
		return _cache[depth]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("debra-depth-%d" % depth)
	var l := LevelData.new()
	l.id = StringName("depth_%d" % depth)
	l.depth = depth
	l.map_pos = Vector2(rng.randf_range(0.15, 0.8), 0.0)
	l.radius = rng.randf_range(22.0, 28.0)
	l.difficulty = difficulty(depth)
	l.rarity_luck = luck(depth)
	l.max_alive = mini(5 + depth / 8, 8)

	# Biome: newer biomes are likelier the deeper you go.
	var biome_ids: Array[StringName] = []
	var bw := PackedFloat32Array()
	for id in BIOMES:
		var b: Dictionary = BIOMES[id]
		if int(b.min) <= depth:
			biome_ids.append(id)
			bw.append(1.0 + float(b.min) * 0.4)
	var biome: StringName = biome_ids[rng.rand_weighted(bw)]
	var bd: Dictionary = BIOMES[biome]
	l.decor = biome
	var hue := rng.randf_range(-0.04, 0.04)
	l.sand_a = _shift(bd.sand_a, hue)
	l.sand_b = _shift(bd.sand_b, hue)
	l.background = _shift(bd.bg, hue)
	l.fog_color = _shift(bd.fog, hue)
	l.ambient = bd.amb
	l.sun_color = bd.sun
	l.caustics = bd.caustics
	var dim := clampf(1.0 - depth * 0.008, 0.7, 1.0)
	l.ambient_energy = 0.6 * dim + (0.1 if bd.caustics == 0.0 else 0.0)
	l.sun_energy = 0.95 * dim
	l.fog_density = rng.randf_range(0.022, 0.04)
	l.layout = LAYOUTS[rng.randi() % LAYOUTS.size()]

	# Creatures: 5-6 from everything unlocked at this depth, favouring newer ones.
	var pool: Array[CreatureData] = []
	for c in PartCatalog.all_creatures():
		if not c.playable and not c.boss and c.min_depth <= depth:
			pool.append(c)
	var picks: Array[CreatureData] = []
	var want := 6 if depth > 10 else 5
	# At least two crustaceans: they're the walking parts catalogues.
	var crusts := pool.filter(func(c: CreatureData) -> bool: return c.is_crustacean())
	for i in 2:
		var c: CreatureData = crusts[rng.randi() % crusts.size()]
		if not picks.has(c):
			picks.append(c)
	var guard := 0
	while picks.size() < want and guard < 100:
		guard += 1
		var w := PackedFloat32Array()
		for c in pool:
			w.append(0.0 if picks.has(c) else 1.0 + float(c.min_depth) / maxf(depth, 1.0) * 2.0)
		picks.append(pool[rng.rand_weighted(w)])
	l.enemies = picks
	l.featured = picks[rng.randi() % picks.size()]

	# Objective
	l.objective = OBJECTIVES[rng.randi() % OBJECTIVES.size()]
	match l.objective:
		&"waves":
			l.objective_count = mini(3 + depth / 6, 7)
		&"hunt":
			l.objective_count = mini(3 + depth / 12, 5)
		_:
			l.objective_count = mini(10 + int(depth * 0.6), 30)

	# Modifiers: one early, more later.
	var n_mods := 1 if depth < 12 else (2 if depth < 25 else 3)
	var mod_ids: Array = MODIFIERS.keys()
	while l.modifiers.size() < n_mods:
		var m: StringName = mod_ids[rng.randi() % mod_ids.size()]
		if not l.modifiers.has(m):
			l.modifiers.append(m)

	_make_boss(l, rng, pool)
	l.display_name = "Depth %d: %s" % [depth, bd.name]
	var mods: Array[String] = []
	for m in l.modifiers:
		mods.append(String(MODIFIERS[m]).get_slice(":", 0))
	l.description = "%s, crawling with %s. %s." % [bd.name, l.featured.display_name, ", ".join(mods)]
	_cache[depth] = l
	return l


## A chimera: a big creature wearing parts stolen from other creatures.
static func _make_boss(l: LevelData, rng: RandomNumberGenerator, pool: Array[CreatureData]) -> void:
	var crusts := l.enemy_list().filter(func(c: CreatureData) -> bool: return c.is_crustacean())
	var base: CreatureData
	if not crusts.is_empty() and rng.randf() < 0.65:
		base = crusts[rng.randi() % crusts.size()]
	else:
		base = l.featured
	var b := base.duplicate() as CreatureData
	b.id = StringName("boss_depth_%d" % l.depth)
	b.boss = true
	b.size = clampf(base.size * 2.1, 1.7, 2.8)
	b.base_hp = 220.0 + base.base_hp * 2.0
	b.damage_mult = 0.7
	b.aggro_range = 40.0
	b.rarity_luck = 1.0
	# Steal parts from anything that lives at this depth.
	var loot: Array[PartData] = []
	for c in pool:
		for p in c.drop_pool():
			if not loot.has(p) and not p.special:
				loot.append(p)
	var stolen: Array = [null, null, null, null, null, null]
	if b.is_crustacean():
		var sockets := [0, 1, 2, 3, 4, 5]
		var n := 2 + (1 if l.depth > 12 else 0) + rng.randi_range(0, 1)
		for i in n:
			var s: int = sockets.pop_at(rng.randi() % sockets.size())
			var fits := loot.filter(func(p: PartData) -> bool: return Equipment.accepts(s, p.slot))
			if not fits.is_empty():
				stolen[s] = fits[rng.randi() % fits.size()]
	else:
		stolen[0] = loot[rng.randi() % loot.size()]   # critters carry one stolen part as loot
	l.boss_parts = stolen
	l.boss = b
	l.boss_name = "The %s %s %s" % [ADJECTIVES[rng.randi() % ADJECTIVES.size()], base.display_name, TITLES[rng.randi() % TITLES.size()]]
	var traits: Array = BossBrain.TRAITS.keys()
	var n_traits := mini(1 + l.depth / 8, 3)
	while l.boss_traits.size() < n_traits:
		var t: StringName = traits[rng.randi() % traits.size()]
		if not l.boss_traits.has(t):
			l.boss_traits.append(t)


static func _shift(c: Color, hue: float) -> Color:
	return Color.from_hsv(fposmod(c.h + hue, 1.0), c.s, c.v)
