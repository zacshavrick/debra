class_name Props
extends RefCounted
## Game-ready decorative props: corals, sponges, anemones, seagrass. Each
## builder returns a Node3D whose origin sits on the sand, built from primitives
## with the shared sway shader (shaders/sway.gdshader), so they move gently with
## the water. Used by the title screen and by LevelBuilder.

const SWAY_SHADER := "res://shaders/sway.gdshader"
const KINDS: Array[StringName] = [&"branch_coral", &"brain_coral", &"sea_fan", &"table_coral", &"tube_sponge", &"anemone", &"seagrass", &"staghorn"]
const CORAL_COLORS := [Color(0.95, 0.42, 0.5), Color(0.98, 0.62, 0.28), Color(0.66, 0.42, 0.92), Color(0.3, 0.8, 0.75), Color(0.98, 0.85, 0.38), Color(0.95, 0.55, 0.75)]

static var _mats: Dictionary = {}
static var _shader: Shader


## A material that sways. glow > 0 makes it emit in `glow_col`.
static func sway_mat(col: Color, sway := 0.02, glow_col := Color.BLACK, glow := 0.0) -> ShaderMaterial:
	var key := "%s|%.3f|%s|%.2f" % [col.to_html(), sway, glow_col.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = load(SWAY_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("glow", glow_col)
	m.set_shader_parameter("glow_energy", glow)
	_mats[key] = m
	return m


static func random_coral_color(d: RandomNumberGenerator) -> Color:
	return CORAL_COLORS[d.randi() % CORAL_COLORS.size()]


## Builds any prop by kind. Returns null for an unknown kind.
static func build(kind: StringName, d: RandomNumberGenerator, scale_ := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = String(kind)
	match kind:
		&"branch_coral":
			_branch_coral(root, d)
		&"staghorn":
			_staghorn(root, d)
		&"brain_coral":
			_brain_coral(root, d)
		&"sea_fan":
			_sea_fan(root, d)
		&"table_coral":
			_table_coral(root, d)
		&"tube_sponge":
			_tube_sponge(root, d)
		&"anemone":
			_anemone(root, d)
		&"seagrass":
			_seagrass(root, d)
		_:
			return null
	root.scale = Vector3.ONE * scale_
	root.rotation.y = d.randf() * TAU
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == &"seagrass" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


## Rough footprint radius (for collision / spacing) of a prop kind at scale 1.
static func footprint(kind: StringName) -> float:
	match kind:
		&"brain_coral":
			return 0.7
		&"table_coral":
			return 0.9
		&"tube_sponge":
			return 0.4
	return 0.0   # soft props: walk through them


# --- Builders ------------------------------------------------------------------------

## Recursive branching coral with rounded tips.
static func _branch_coral(root: Node3D, d: RandomNumberGenerator) -> void:
	var col := random_coral_color(d)
	var m := sway_mat(col, 0.015)
	var tip := sway_mat(col.lightened(0.35), 0.015)
	_branch(root, Vector3.ZERO, Vector3.UP, 0.75, 0.09, 3, d, m, tip)


static func _branch(root: Node3D, from: Vector3, dir: Vector3, length: float, r: float, depth: int, d: RandomNumberGenerator, m: Material, tip: Material) -> void:
	var to := from + dir * length
	PartVisual._segment(root, from, to, r, r * 0.75, m)
	if depth <= 0:
		PartVisual._ellipsoid(root, to, Vector3.ONE * r * 1.8, tip)
		return
	var n := 2 + d.randi() % 2
	for i in n:
		var side := Vector3(d.randf_range(-1, 1), 0, d.randf_range(-1, 1)).normalized()
		var nd := (dir + side * d.randf_range(0.35, 0.7)).normalized()
		_branch(root, to, nd, length * d.randf_range(0.6, 0.8), r * 0.72, depth - 1, d, m, tip)


## Antler-like staghorn: many straight prongs.
static func _staghorn(root: Node3D, d: RandomNumberGenerator) -> void:
	var col := random_coral_color(d).lerp(Color(0.95, 0.9, 0.8), 0.3)
	var m := sway_mat(col, 0.01)
	for i in 7:
		var a := TAU * i / 7.0 + d.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6).normalized()
		var mid := dir * d.randf_range(0.5, 0.8)
		PartVisual._segment(root, Vector3.ZERO, mid, 0.07, 0.06, m)
		PartVisual._segment(root, mid, mid + (dir + Vector3(0, 0.6, 0)).normalized() * 0.45, 0.06, 0.02, m)


static func _brain_coral(root: Node3D, d: RandomNumberGenerator) -> void:
	var col := random_coral_color(d)
	var s := d.randf_range(0.8, 1.2)
	PartVisual._ellipsoid(root, Vector3(0, s * 0.3, 0), Vector3(s * 1.4, s, s * 1.4), PartVisual.mat(col, 0, 0.0, 0.9))
	# Winding ridges: rows of small lumps hugging the dome.
	var ridge := PartVisual.mat(col.lightened(0.12), 0, 0.0, 0.9)
	for row in 3:
		var lat := 0.35 + row * 0.22   # 0 = equator, 1 = top
		var n := 10 - row * 3
		var phase := d.randf() * TAU
		for i in n:
			var a := phase + TAU * i / n
			var y := s * 0.3 + s * 0.5 * lat
			var rr := s * 0.7 * sqrt(maxf(0.0, 1.0 - lat * lat))
			var lump := PartVisual._ellipsoid(root, Vector3(cos(a) * rr, y, sin(a) * rr), Vector3(s * 0.28, s * 0.14, s * 0.12), ridge)
			lump.rotation.y = -a


## A flat lattice fan.
static func _sea_fan(root: Node3D, d: RandomNumberGenerator) -> void:
	var col := random_coral_color(d)
	var m := sway_mat(col, 0.03)
	var h := d.randf_range(1.0, 1.6)
	PartVisual._segment(root, Vector3.ZERO, Vector3(0, 0.3, 0), 0.06, 0.05, m)
	var tips: Array[Vector3] = []
	for i in 9:
		var a := lerpf(-1.1, 1.1, i / 8.0)
		var tip := Vector3(sin(a) * h * 0.7, 0.3 + cos(a) * h, 0)
		tips.append(tip)
		PartVisual._segment(root, Vector3(0, 0.3, 0), tip, 0.025, 0.012, m)
	for j in 3:   # cross-links
		var f := 0.4 + j * 0.2
		for i in tips.size() - 1:
			var a := Vector3(0, 0.3, 0).lerp(tips[i], f)
			var b := Vector3(0, 0.3, 0).lerp(tips[i + 1], f)
			PartVisual._segment(root, a, b, 0.012, 0.012, m)


## A flat plate on a stalk.
static func _table_coral(root: Node3D, d: RandomNumberGenerator) -> void:
	var col := random_coral_color(d).lerp(Color(0.6, 0.7, 0.55), 0.3)
	var m := PartVisual.mat(col, 0, 0.0, 0.85)
	var h := d.randf_range(0.6, 1.0)
	PartVisual._segment(root, Vector3.ZERO, Vector3(0, h, 0), 0.14, 0.1, m)
	PartVisual._ellipsoid(root, Vector3(0, h, 0), Vector3(1.8, 0.12, 1.6), m)
	PartVisual._ellipsoid(root, Vector3(0, h + 0.05, 0), Vector3(1.5, 0.08, 1.3), PartVisual.mat(col.lightened(0.15), 0, 0.0, 0.85))


## A cluster of open tubes.
static func _tube_sponge(root: Node3D, d: RandomNumberGenerator) -> void:
	var tubes := [Color(0.85, 0.5, 0.25), Color(0.6, 0.4, 0.8), Color(0.9, 0.75, 0.3), Color(0.35, 0.6, 0.85)]
	var col: Color = tubes[d.randi() % tubes.size()]
	var m := PartVisual.mat(col, 0, 0.0, 0.95)
	var inner := PartVisual.mat(col.darkened(0.6))
	for i in d.randi_range(3, 5):
		var a := d.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * d.randf_range(0.0, 0.3)
		var h := d.randf_range(0.5, 1.2)
		var r := d.randf_range(0.1, 0.16)
		PartVisual._segment(root, p, p + Vector3(0, h, 0), r * 0.9, r, m)
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = r * 0.75
		c.bottom_radius = r * 0.75
		c.height = 0.01
		mi.mesh = c
		mi.material_override = inner
		mi.position = p + Vector3(0, h + 0.005, 0)
		root.add_child(mi)


## A sea anemone: a squat column crowned with swaying, glowing-tipped tentacles.
static func _anemone(root: Node3D, d: RandomNumberGenerator) -> void:
	var cols := [[Color(0.95, 0.45, 0.6), Color(1, 0.85, 0.9)], [Color(0.4, 0.85, 0.6), Color(0.9, 1, 0.6)], [Color(0.95, 0.6, 0.25), Color(1, 0.9, 0.5)], [Color(0.6, 0.45, 0.95), Color(0.95, 0.8, 1)]]
	var pick: Array = cols[d.randi() % cols.size()]
	var body: Color = pick[0]
	var tipc: Color = pick[1]
	PartVisual._segment(root, Vector3.ZERO, Vector3(0, 0.3, 0), 0.22, 0.26, PartVisual.mat(body.darkened(0.2), 0, 0.0, 0.8))
	var tm := sway_mat(body, 0.12)
	var glow := sway_mat(tipc, 0.12, tipc, 0.6)
	for i in 18:
		var a := i * 2.39996
		var rr := 0.1 + (i % 3) * 0.06
		var base := Vector3(cos(a) * rr, 0.3, sin(a) * rr)
		var tip := base + Vector3(cos(a) * 0.18, d.randf_range(0.3, 0.5), sin(a) * 0.18)
		PartVisual._segment(root, base, tip, 0.03, 0.015, tm)
		PartVisual._ellipsoid(root, tip, Vector3.ONE * 0.05, glow)


## A tuft of seagrass blades.
static func _seagrass(root: Node3D, d: RandomNumberGenerator) -> void:
	var col := Color(0.3, 0.6, 0.3).lerp(Color(0.55, 0.65, 0.25), d.randf())
	var m := sway_mat(col, 0.12)
	for i in d.randi_range(6, 10):
		var a := d.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * d.randf_range(0.0, 0.25)
		var h := d.randf_range(0.4, 0.9)
		var bend := Vector3(cos(a), 0, sin(a)) * h * 0.25
		PartVisual._segment(root, p, p + Vector3(0, h * 0.55, 0) + bend * 0.3, 0.025, 0.02, m)
		PartVisual._segment(root, p + Vector3(0, h * 0.55, 0) + bend * 0.3, p + Vector3(0, h, 0) + bend, 0.02, 0.0, m)
