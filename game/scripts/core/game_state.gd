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
## Parts you carry (shared by every crab) and parts stored at home.
var bag: Array[PartInstance] = []
var stash: Array[PartInstance] = []
## Dev tools (skip level etc.). Prototype: on.
var dev_mode := true

const BAG_SIZE := 30
const STASH_SIZE := 90
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


# --- Levels: a branching chart ------------------------------------------------------
# Every depth has 1-3 levels ("branches"). Depth 1 is the Sandy Shallows alone;
# depths 2-5 are the hand-made level (branch 0) plus a generated side route;
# from depth 6 everything is generated, 2-3 branches per depth, forever.
# Each node links to 1-2 nodes in the depth below. A node unlocks when any of its
# parents is cleared, so you choose your route down.

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


## How many branches (levels) a depth has.
func branch_count(depth: int) -> int:
	if depth <= 1:
		return 1
	if depth <= handmade_count():
		return 2
	return 2 + (hash("debra-branches-%d" % depth) % 2)


func level_at(depth: int, branch: int) -> LevelData:
	depth = maxi(depth, 1)
	branch = clampi(branch, 0, branch_count(depth) - 1)
	if depth <= handmade_count() and branch == 0:
		return levels()[depth - 1]
	return LevelGenerator.generate(depth, branch)


## The main route's level at a depth (branch 0).
func level_at_depth(depth: int) -> LevelData:
	return level_at(depth, 0)


func level(id: StringName) -> LevelData:
	var s := String(id)
	if s.begins_with("depth_"):
		var bits := s.trim_prefix("depth_").split("_")
		return level_at(int(bits[0]), int(bits[1]) if bits.size() > 1 else 0)
	for l in levels():
		if l.id == id:
			return l
	return null


## 0..1 horizontal slot of a branch on the chart.
func branch_x(depth: int, branch: int) -> float:
	return (branch + 0.5) / branch_count(depth)


## Branches in depth-1 that lead to (depth, branch).
func parents(depth: int, branch: int) -> Array[int]:
	var out: Array[int] = []
	if depth <= 1:
		return out
	var pc := branch_count(depth - 1)
	var x := branch_x(depth, branch)
	var nearest := 0
	for p in pc:
		if absf(branch_x(depth - 1, p) - x) < absf(branch_x(depth - 1, nearest) - x):
			nearest = p
	out.append(nearest)
	# Some routes cross over to a neighbour.
	for p in pc:
		if p != nearest and absf(branch_x(depth - 1, p) - x) <= 0.45 and hash("debra-link-%d-%d-%d" % [depth, branch, p]) % 3 == 0:
			out.append(p)
	# Every parent must lead somewhere: give orphaned parents this child if it's their nearest.
	for p in pc:
		if out.has(p):
			continue
		var px := branch_x(depth - 1, p)
		var best := 0
		for b in branch_count(depth):
			if absf(branch_x(depth, b) - px) < absf(branch_x(depth, best) - px):
				best = b
		if best == branch:
			out.append(p)
	return out


func is_cleared(id: StringName) -> bool:
	if _cleared.has(String(id)):
		return true
	# Saves from before branches used "depth_N" for the main route.
	var s := String(id)
	return s.ends_with("_0") and s.begins_with("depth_") and _cleared.has(s.trim_suffix("_0"))


func is_unlocked(id: StringName) -> bool:
	var l := level(id)
	if l == null:
		return false
	if l.depth <= 1:
		return true
	for p in parents(l.depth, l.branch):
		if is_cleared(level_at(l.depth - 1, p).id):
			return true
	return false


## Deepest depth with an unlocked level.
func frontier_depth() -> int:
	var d := 1
	while true:
		var any := false
		for b in branch_count(d + 1):
			if is_unlocked(level_at(d + 1, b).id):
				any = true
				break
		if not any:
			return d
		d += 1
	return d


## Deepest depth cleared so far (0 = none).
func deepest_cleared() -> int:
	var best := 0
	for d in range(1, frontier_depth() + 1):
		for b in branch_count(d):
			if is_cleared(level_at(d, b).id):
				best = d
	return best


## Returns true if this was the first clear.
func mark_cleared(id: StringName) -> bool:
	var first := not is_cleared(id)
	_cleared[String(id)] = true
	save_game()
	return first


func next_level(id: StringName) -> LevelData:
	var l := level(id)
	return level_at_depth(l.depth + 1) if l else null


## Where "drop in and play" sends you: an unlocked, uncleared level at the frontier.
func frontier() -> LevelData:
	var d := frontier_depth()
	var fallback := level_at(d, 0)
	for b in branch_count(d):
		var l := level_at(d, b)
		if is_unlocked(l.id):
			if not is_cleared(l.id):
				return l
			fallback = l
	return fallback


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
		"bag": bag.map(func(p: PartInstance) -> Dictionary: return p.to_dict()),
		"stash": stash.map(func(p: PartInstance) -> Dictionary: return p.to_dict()),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	starter = &""
	_loadouts = {}
	_cleared = {}
	bag = []
	stash = []
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
	bag = _parts_from(data.get("bag", []))
	stash = _parts_from(data.get("stash", []))
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


# --- Bag and stash -------------------------------------------------------------------

func _parts_from(raw) -> Array[PartInstance]:
	var out: Array[PartInstance] = []
	if raw is Array:
		for d in raw:
			if d is Dictionary:
				var p := PartInstance.from_dict(d)
				if p:
					out.append(p)
	return out


## Returns false if the bag is full.
func add_to_bag(p: PartInstance) -> bool:
	if bag.size() >= BAG_SIZE:
		return false
	bag.append(p)
	save_game()
	return true


func bag_full() -> bool:
	return bag.size() >= BAG_SIZE


## Moves a part between bag and stash. Returns false if the other side is full.
func move_part(p: PartInstance, to_stash: bool) -> bool:
	var from := bag if to_stash else stash
	var to := stash if to_stash else bag
	if not from.has(p) or to.size() >= (STASH_SIZE if to_stash else BAG_SIZE):
		return false
	from.erase(p)
	to.append(p)
	save_game()
	return true


func remove_part(p: PartInstance) -> void:
	bag.erase(p)
	stash.erase(p)
	save_game()
