extends Node
## Autoload `GameState`: the save file and scene flow.
##   - which starter crab you play, and what each starter is wearing
##     (mutations persist per crab)
##   - which levels are cleared (clearing one unlocks the next)
## Saved as JSON at user:// (IndexedDB on the web, so it survives reloads).

const SAVE_PATH := "user://debra_save.json"
const SAVE_VERSION := 1
## Order shown on the crab select screen. Debra headlines.
const STARTERS: Array[StringName] = [&"debra", &"saul", &"louise", &"marjorie", &"gary"]
const LEVELS_DIR := "res://data/levels/"

const MAP_SCENE := "res://scenes/map.tscn"
const SELECT_SCENE := "res://scenes/select.tscn"
const LEVEL_SCENE := "res://scenes/level.tscn"

var save_path := SAVE_PATH
## "" until the player picks a crab.
var starter: StringName = &""
## The level being played (set by play_level).
var current_level: StringName = &""
var _loadouts: Dictionary = {}   # starter id -> Array of {id, rarity} (null = default)
var _cleared: Dictionary = {}    # level id -> true
static var _levels: Array[LevelData] = []


func _ready() -> void:
	load_game()


# --- Starters ------------------------------------------------------------------------

func starter_data(id: StringName = &"") -> CreatureData:
	return PartCatalog.creature(id if id != &"" else starter)


## What a starter is wearing: its saved mutations, or its default loadout.
func loadout_for(id: StringName) -> Array[PartInstance]:
	var out: Array[PartInstance] = []
	var defaults := starter_data(id).loadout()
	var saved: Array = _loadouts.get(String(id), [])
	for s in Equipment.SOCKET_COUNT:
		var inst: PartInstance = null
		if s < saved.size() and saved[s] is Dictionary:
			inst = PartInstance.from_dict(saved[s])
		if (inst == null or not Equipment.accepts(s, inst.data.slot)) and defaults[s] != null:
			inst = PartInstance.new(defaults[s], Rarity.Tier.COMMON)
		out.append(inst)
	return out


func store_loadout(id: StringName, equipment: Equipment) -> void:
	_loadouts[String(id)] = equipment.to_array()
	save_game()


func reset_loadout(id: StringName) -> void:
	_loadouts.erase(String(id))
	save_game()


func choose_starter(id: StringName) -> void:
	starter = id
	save_game()


# --- Levels --------------------------------------------------------------------------
# Depths 1-5 are the hand-made levels in data/levels/. Every depth after that is
# generated (LevelGenerator) and never ends. Clearing depth N unlocks N + 1.

## The hand-made levels, by depth.
func levels() -> Array[LevelData]:
	if _levels.is_empty():
		for f in DirAccess.get_files_at(LEVELS_DIR):
			var file := f.trim_suffix(".remap")
			if file.ends_with(".tres"):
				var l := load(LEVELS_DIR + file) as LevelData
				if l:
					_levels.append(l)
		_levels.sort_custom(func(a: LevelData, b: LevelData) -> bool: return a.depth < b.depth)
	return _levels


func handmade_count() -> int:
	return levels().size()


func level_at_depth(depth: int) -> LevelData:
	depth = maxi(depth, 1)
	if depth <= handmade_count():
		return levels()[depth - 1]
	return LevelGenerator.generate(depth)


func level(id: StringName) -> LevelData:
	var s := String(id)
	if s.begins_with("depth_"):
		return level_at_depth(int(s.trim_prefix("depth_")))
	for l in levels():
		if l.id == id:
			return l
	return null


func is_cleared(id: StringName) -> bool:
	return _cleared.has(String(id))


## Deepest depth cleared so far (0 = none).
func deepest_cleared() -> int:
	return frontier_depth() - 1


func frontier_depth() -> int:
	var d := 1
	while is_cleared(level_at_depth(d).id):
		d += 1
	return d


func is_unlocked(id: StringName) -> bool:
	var l := level(id)
	return l != null and l.depth <= frontier_depth()


## Returns true if this clear unlocked a new depth.
func mark_cleared(id: StringName) -> bool:
	var first := not is_cleared(id)
	_cleared[String(id)] = true
	save_game()
	return first


func next_level(id: StringName) -> LevelData:
	var l := level(id)
	return level_at_depth(l.depth + 1) if l else null


## The deepest unlocked level (where "drop in and play" sends you).
func frontier() -> LevelData:
	return level_at_depth(frontier_depth())


# --- Scene flow ----------------------------------------------------------------------

func go_to_map() -> void:
	get_tree().change_scene_to_file.call_deferred(MAP_SCENE)


func go_to_select() -> void:
	get_tree().change_scene_to_file.call_deferred(SELECT_SCENE)


func play_level(id: StringName) -> void:
	current_level = id
	get_tree().change_scene_to_file.call_deferred(LEVEL_SCENE)


# --- Save file -----------------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"starter": String(starter),
		"loadouts": _loadouts,
		"cleared": _cleared.keys(),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	starter = &""
	_loadouts = {}
	_cleared = {}
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (data is Dictionary):
		return
	var s := StringName(str(data.get("starter", "")))
	starter = s if STARTERS.has(s) else &""
	var lo = data.get("loadouts", {})
	if lo is Dictionary:
		_loadouts = lo
	var cl = data.get("cleared", [])
	if cl is Array:
		for id in cl:
			_cleared[str(id)] = true


## Tests: use a throwaway save file and start fresh.
func use_save_file(path: String) -> void:
	save_path = path
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	load_game()
