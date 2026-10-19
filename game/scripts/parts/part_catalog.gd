class_name PartCatalog
extends RefCounted
## Finds every PartData / CreatureData in data/. Works in exported builds,
## where resources are listed as "*.tres.remap".

const PARTS_DIR := "res://data/parts/"
const CREATURES_DIR := "res://data/creatures/"

static var _parts: Dictionary = {}
static var _creatures: Dictionary = {}


static func all_parts() -> Array[PartData]:
	if _parts.is_empty():
		for r in _load_dir(PARTS_DIR):
			if r is PartData:
				_parts[r.id] = r
	var out: Array[PartData] = []
	for p in _parts.values():
		out.append(p)
	out.sort_custom(func(a: PartData, b: PartData) -> bool: return a.slot < b.slot if a.slot != b.slot else String(a.id) < String(b.id))
	return out


static func by_id(id: StringName) -> PartData:
	all_parts()
	return _parts.get(id)


static func all_creatures() -> Array[CreatureData]:
	if _creatures.is_empty():
		for r in _load_dir(CREATURES_DIR):
			if r is CreatureData:
				_creatures[r.id] = r
	var out: Array[CreatureData] = []
	for c in _creatures.values():
		out.append(c)
	out.sort_custom(func(a: CreatureData, b: CreatureData) -> bool: return String(a.id) < String(b.id))
	return out


static func creature(id: StringName) -> CreatureData:
	all_creatures()
	return _creatures.get(id)


static func _load_dir(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	for f in DirAccess.get_files_at(dir):
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tres") or file.ends_with(".res"):
			var r := load(dir + file)
			if r:
				out.append(r)
	return out
