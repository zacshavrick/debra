class_name LevelData
extends Resource
## One level (a seafloor zone on the world map). Lives in res://data/levels/*.tres.
## Flow: kill `kill_goal` creatures -> the boss shows up -> beat it -> cleared,
## next level unlocks. You can keep fighting after the clear.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Unlock order (0 = first).
@export var order := 0
## Position on the world map, 0..1 in both axes (y = depth).
@export var map_pos := Vector2(0.5, 0.5)

@export_group("Arena")
@export var radius := 22.0
## Decor set: shallows, kelp, reef, wreck, abyss (see LevelBuilder).
@export var decor: StringName = &"shallows"
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
@export var max_alive := 5
@export var kill_goal := 12
@export var boss: CreatureData
## Multiplies enemy HP and damage.
@export var difficulty := 1.0
## Extra rarity luck for every drop in this level.
@export var rarity_luck := 0.0


func enemy_list() -> Array[CreatureData]:
	var out: Array[CreatureData] = []
	for e in enemies:
		if e is CreatureData:
			out.append(e)
	return out
