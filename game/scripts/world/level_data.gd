class_name LevelData
extends Resource
## One level. The first five are hand-made (res://data/levels/*.tres); every
## depth after that is made by LevelGenerator on the fly.
## Flow: complete the objective -> the boss shows up -> beat it -> a portal
## opens back to the map and the next depth unlocks.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## 1-based depth. Unlock order, difficulty and part level all follow it.
@export var depth := 1
## Which route at this depth (0 = main; hand-made levels are branch 0).
@export var branch := 0
## Position on the world map (x 0..1; y is derived from depth).
@export var map_pos := Vector2(0.5, 0.5)

@export_group("Arena")
@export var radius := 22.0
## Decor set: shallows, kelp, reef, wreck, abyss, vents, ice, trench, sargassum, bones.
@export var decor: StringName = &"shallows"
## Obstacle layout: open, pillars, ring, canyon, islands.
@export var layout: StringName = &"open"
@export var sand_a := Color(0.5, 0.45, 0.35)
@export var sand_b := Color(0.36, 0.33, 0.26)
@export var background := Color(0.03, 0.16, 0.24)
@export var fog_color := Color(0.06, 0.24, 0.34)
@export var fog_density := 0.03
@export var ambient := Color(0.32, 0.5, 0.65)
@export var ambient_energy := 0.55
@export var sun_color := Color(0.72, 0.9, 1.0)
@export var sun_energy := 0.95
@export var caustics := 0.12

@export_group("Creatures")
## CreatureData list; each creature's spawn_weight sets how often it appears.
@export var enemies: Array = []
## The level's "personality": spawns three times as often.
@export var featured: CreatureData
@export var max_alive := 5
@export var boss: CreatureData
## Multiplies enemy HP and damage.
@export var difficulty := 1.0
## Extra rarity luck for every drop in this level.
@export var rarity_luck := 0.0

@export_group("Rules")
## cull (kill N), waves (survive N waves), hunt (kill the marked champions).
@export var objective: StringName = &"cull"
## cull: kills needed. waves: number of waves. hunt: marked targets.
@export var objective_count := 12
## swarm, armored, venom, dark, treasure, champions, riptide, frenzy.
@export var modifiers: Array[StringName] = []
## Generated boss extras (see BossBrain.TRAITS).
@export var boss_traits: Array[StringName] = []
@export var boss_name := ""
## Stolen parts the boss wears, per socket (null = its own).
@export var boss_parts: Array = []


func enemy_list() -> Array[CreatureData]:
	var out: Array[CreatureData] = []
	for e in enemies:
		if e is CreatureData:
			out.append(e)
	return out


func has_mod(m: StringName) -> bool:
	return modifiers.has(m)


## Old name, still used by the hand-made levels' data.
var kill_goal: int:
	get:
		return objective_count
	set(v):
		objective_count = v


func objective_text() -> String:
	match objective:
		&"waves":
			return "Survive %d waves, then the boss." % objective_count
		&"hunt":
			return "Hunt %d marked champions, then the boss." % objective_count
	return "Kill %d to call the boss." % objective_count
