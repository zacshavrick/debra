class_name LevelBuilder
extends RefCounted
## Builds a level's look: lighting, seafloor, arena wall, and themed decor
## (shallows, kelp, reef, wreck, abyss). Everything is primitives and
## Compatibility-safe; counts drop on phones (Platform.is_low()).

const KELP_SHADER := "res://shaders/kelp.gdshader"
const FLOOR_SHADER := "res://shaders/seafloor.gdshader"


static func build(root: Node3D, level: LevelData, keep_clear: Array[Vector3]) -> void:
	var d := RandomNumberGenerator.new()
	d.seed = hash(level.id)   # same layout every visit
	_environment(root, level)
	_floor(root, level)
	_rim(root, level, d)
	var low := Platform.is_low()
	match level.decor:
		&"kelp":
			_kelp(root, level, d, 70 if not low else 35, 0.0, keep_clear, Color(0.18, 0.5, 0.22), Color(0.45, 0.55, 0.15), 3.0, 7.5)
			_rocks(root, level, d, 6, keep_clear)
		&"reef":
			_coral(root, level, d, 45 if not low else 25, keep_clear)
			_kelp(root, level, d, 12, 0.0, keep_clear, Color(0.3, 0.6, 0.35), Color(0.5, 0.65, 0.3), 1.0, 2.5)
		&"wreck":
			_wreck(root, level, d, keep_clear)
			_rocks(root, level, d, 7, keep_clear)
			_kelp(root, level, d, 14, 0.0, keep_clear, Color(0.15, 0.3, 0.2), Color(0.25, 0.35, 0.18), 2.0, 5.0)
		&"abyss":
			_abyss(root, level, d, 40 if not low else 20, keep_clear)
			_rocks(root, level, d, 6, keep_clear, Color(0.12, 0.12, 0.16))
		&"vents":
			_vents(root, level, d, 10 if not low else 6, keep_clear)
			_rocks(root, level, d, 6, keep_clear, Color(0.18, 0.14, 0.13))
		&"sargassum":
			_sargassum(root, level, d, 24 if not low else 12, keep_clear)
			_kelp(root, level, d, 18, 0.0, keep_clear, Color(0.55, 0.45, 0.15), Color(0.65, 0.55, 0.2), 1.0, 3.0)
		&"ice":
			_crystals(root, level, d, 26 if not low else 14, keep_clear)
			_rocks(root, level, d, 5, keep_clear, Color(0.6, 0.66, 0.72))
		&"trench":
			_rocks(root, level, d, 12, keep_clear, Color(0.1, 0.1, 0.12))
			_abyss(root, level, d, 16 if not low else 8, keep_clear)
		&"bones":
			_bones(root, level, d, keep_clear)
			_shells(root, level, d, 12, keep_clear)
		_:  # shallows
			_shells(root, level, d, 30 if not low else 15, keep_clear)
			_kelp(root, level, d, 25 if not low else 12, 0.0, keep_clear, Color(0.35, 0.6, 0.3), Color(0.55, 0.65, 0.3), 0.8, 1.8)
			_rocks(root, level, d, 4, keep_clear)
	_layout(root, level, d, keep_clear)
	var dark := [&"abyss", &"trench"].has(level.decor)
	_bubbles(root, level, 0 if dark else (25 if low else 60))


## Obstacles that change how a level plays: pillars, an inner ring wall,
## two canyon walls, or rocky islands.
static func _layout(root: Node3D, level: LevelData, d: RandomNumberGenerator, keep_clear: Array[Vector3]) -> void:
	var col := level.sand_b.darkened(0.3).lerp(Color(0.3, 0.32, 0.35), 0.4)
	var r := level.radius
	match level.layout:
		&"pillars":
			for i in 9:
				var p := _free_spot(level, d, keep_clear, 5.0, 0.8)
				_pillar(root, p, d.randf_range(0.7, 1.1), d.randf_range(2.5, 4.5), col)
		&"ring":   # an inner wall with four gaps: fight in the middle or circle around
			var n := 28
			for i in n:
				var a := TAU * i / n
				if i % 7 == 0 or i % 7 == 1:
					continue
				var p := Vector3(cos(a), 0, sin(a)) * r * 0.45
				var clear := true
				for k in keep_clear:
					if p.distance_to(k) < 3.0:
						clear = false
				if clear:
					rock(root, p, d.randf_range(1.0, 1.3), d, true, col)
		&"canyon":   # two long ridges make three lanes
			for side in [-1.0, 1.0]:
				for i in 11:
					var z := lerpf(-r * 0.55, r * 0.55, i / 10.0)
					var p := Vector3(side * r * 0.3 + d.randf_range(-0.4, 0.4), 0, z)
					if absf(z) < 2.5 or p.distance_to(keep_clear[0]) < 4.0 or p.distance_to(keep_clear[1]) < 4.0:
						continue   # gaps to cross through
					rock(root, p, d.randf_range(1.1, 1.5), d, true, col)
		&"islands":
			for i in 5:
				var c := _free_spot(level, d, keep_clear, 6.0, 0.75)
				for j in 4:
					rock(root, c + Vector3(d.randf_range(-1.5, 1.5), 0, d.randf_range(-1.5, 1.5)), d.randf_range(0.8, 1.3), d, true, col)


static func _pillar(root: Node3D, pos: Vector3, r: float, h: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r * 0.7
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 9
	mi.mesh = c
	mi.material_override = PartVisual.mat(col, 0, 0.0, 0.9)
	mi.position = pos + Vector3(0, h * 0.5, 0)
	root.add_child(mi)
	_solid(root, pos, r)


static func _vents(root: Node3D, level: LevelData, d: RandomNumberGenerator, count: int, keep_clear: Array[Vector3]) -> void:
	var rockm := PartVisual.mat(Color(0.16, 0.12, 0.11), 0, 0.0, 0.95)
	for i in count:
		var p := _free_spot(level, d, keep_clear, 4.0)
		var h := d.randf_range(1.2, 3.0)
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.3
		c.bottom_radius = 0.75
		c.height = h
		mi.mesh = c
		mi.material_override = rockm
		mi.position = p + Vector3(0, h * 0.5, 0)
		root.add_child(mi)
		PartVisual._ellipsoid(root, p + Vector3(0, h, 0), Vector3(0.45, 0.12, 0.45), CritterVisual._glass(Color(1.0, 0.45, 0.15), 0.95, 2.5))
		_solid(root, p, 0.6)
		var smoke := CPUParticles3D.new()
		smoke.amount = 10 if Platform.is_low() else 20
		smoke.lifetime = 3.0
		smoke.direction = Vector3.UP
		smoke.spread = 8.0
		smoke.gravity = Vector3(0, 1.2, 0)
		smoke.initial_velocity_min = 0.6
		smoke.initial_velocity_max = 1.2
		smoke.scale_amount_min = 1.0
		smoke.scale_amount_max = 3.0
		var sm := SphereMesh.new()
		sm.radius = 0.15
		sm.height = 0.3
		sm.radial_segments = 6
		sm.rings = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.15, 0.12, 0.12, 0.35)
		sm.material = m
		smoke.mesh = sm
		smoke.position = p + Vector3(0, h + 0.1, 0)
		root.add_child(smoke)


static func _sargassum(root: Node3D, level: LevelData, d: RandomNumberGenerator, count: int, keep_clear: Array[Vector3]) -> void:
	# Floating golden weed rafts overhead (casting shadows) and clumps on the floor.
	var weed := PartVisual.mat(Color(0.62, 0.5, 0.18), 0, 0.0, 0.8)
	var berry := PartVisual.mat(Color(0.75, 0.62, 0.25))
	for i in count:
		var p := _free_spot(level, d, keep_clear, 2.0)
		var high := i % 2 == 0
		var y := d.randf_range(4.0, 6.0) if high else 0.15
		for j in 5:
			var off := Vector3(d.randf_range(-1.2, 1.2), d.randf_range(-0.1, 0.1), d.randf_range(-1.2, 1.2))
			PartVisual._ellipsoid(root, p + off + Vector3(0, y, 0), Vector3(d.randf_range(0.6, 1.2), 0.12, d.randf_range(0.3, 0.6)), weed)
			PartVisual._ellipsoid(root, p + off + Vector3(0, y + 0.08, 0), Vector3.ONE * 0.1, berry)


static func _crystals(root: Node3D, level: LevelData, d: RandomNumberGenerator, count: int, keep_clear: Array[Vector3]) -> void:
	var ice := CritterVisual._glass(Color(0.75, 0.9, 1.0), 0.75, 0.5)
	for i in count:
		var p := _free_spot(level, d, keep_clear, 3.0)
		for j in d.randi_range(3, 6):
			var dir := Vector3(d.randf_range(-0.5, 0.5), 1.0, d.randf_range(-0.5, 0.5)).normalized()
			PartVisual._segment(root, p, p + dir * d.randf_range(0.6, 1.8), d.randf_range(0.12, 0.22), 0.0, ice)
		if i % 3 == 0:
			_solid(root, p, 0.5)


static func _bones(root: Node3D, level: LevelData, d: RandomNumberGenerator, keep_clear: Array[Vector3]) -> void:
	# A whale skeleton: a spine with ribs arching over it, plus scattered vertebrae.
	var bone := PartVisual.mat(Color(0.85, 0.82, 0.74), 0, 0.0, 0.7)
	var a := d.randf() * TAU
	var axis := Vector3(cos(a), 0, sin(a))
	var side := axis.cross(Vector3.UP)
	var center := axis * 2.0 + side * level.radius * 0.35
	for i in 9:
		var p := center + axis * (i - 4) * 1.6
		PartVisual._ellipsoid(root, p + Vector3(0, 0.3, 0), Vector3(0.6, 0.5, 0.7), bone)
		if i % 3 == 0:
			_solid(root, p, 0.5)
		for s in [-1.0, 1.0]:   # arching ribs
			var pts := [p + Vector3(0, 0.4, 0), p + side * s * 1.5 + Vector3(0, 2.2, 0), p + side * s * 2.6 + Vector3(0, 0.6, 0)]
			PartVisual._segment(root, pts[0], pts[1], 0.12, 0.1, bone)
			PartVisual._segment(root, pts[1], pts[2], 0.1, 0.07, bone)
	var skull := center + axis * 8.0
	PartVisual._ellipsoid(root, skull + Vector3(0, 0.7, 0), Vector3(2.2, 1.4, 2.8), bone)
	_solid(root, skull, 1.3)
	for i in 8:
		var p := _free_spot(level, d, keep_clear, 3.0)
		PartVisual._ellipsoid(root, p + Vector3(0, 0.15, 0), Vector3(0.5, 0.35, 0.4), bone)


static func _environment(root: Node3D, level: LevelData) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = level.background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = level.ambient
	env.ambient_light_energy = level.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = level.fog_color
	env.fog_density = level.fog_density * (2.2 if level.has_mod(&"dark") else 1.0)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 25, 0)
	sun.light_color = level.sun_color
	sun.light_energy = level.sun_energy
	sun.shadow_enabled = not Platform.is_low()
	sun.directional_shadow_max_distance = 40.0
	root.add_child(sun)


static func _floor(root: Node3D, level: LevelData) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 2, 160)
	cs.shape = box
	cs.position.y = -1.0
	body.add_child(cs)
	root.add_child(body)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	mi.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = load(FLOOR_SHADER)
	m.set_shader_parameter("sand_a", level.sand_a)
	m.set_shader_parameter("sand_b", level.sand_b)
	m.set_shader_parameter("caustic_strength", level.caustics)
	m.set_shader_parameter("arena_radius", level.radius)
	mi.material_override = m
	root.add_child(mi)
	# Invisible wall ring
	var wall := StaticBody3D.new()
	root.add_child(wall)
	var n := 40
	for i in n:
		var a := TAU * i / n
		var w := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(TAU * level.radius / n + 1.0, 4.0, 1.0)
		w.shape = b
		w.position = Vector3(cos(a), 0, sin(a)) * (level.radius + 0.5) + Vector3(0, 2, 0)
		w.rotation.y = -a + PI * 0.5
		wall.add_child(w)


static func _rim(root: Node3D, level: LevelData, d: RandomNumberGenerator) -> void:
	var col := level.sand_b.darkened(0.25).lerp(Color(0.3, 0.32, 0.35), 0.5)
	var n := int(level.radius * 1.9)
	for i in n:
		var a := TAU * i / n + d.randf_range(-0.04, 0.04)
		var r := level.radius + d.randf_range(0.5, 2.5)
		rock(root, Vector3(cos(a) * r, 0, sin(a) * r), d.randf_range(1.3, 2.8), d, false, col)


static func _rocks(root: Node3D, level: LevelData, d: RandomNumberGenerator, n: int, keep_clear: Array[Vector3], col := Color(0.32, 0.34, 0.36)) -> void:
	for i in n:
		var p := _free_spot(level, d, keep_clear, 5.0, 0.75)
		rock(root, p, d.randf_range(0.9, 1.5), d, true, col)


static func rock(root: Node3D, pos: Vector3, s: float, d: RandomNumberGenerator, solid: bool, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = PartVisual.mat(col.lerp(Color(0.4, 0.36, 0.3), d.randf() * 0.3), 0, 0.0, 0.9)
	mi.scale = Vector3(s * d.randf_range(1.0, 1.6), s * d.randf_range(0.6, 1.0), s * d.randf_range(1.0, 1.5))
	mi.position = pos + Vector3(0, s * 0.15, 0)
	mi.rotation.y = d.randf() * TAU
	root.add_child(mi)
	if solid:
		_solid(root, pos, s * 0.6)


static func _solid(root: Node3D, pos: Vector3, r: float) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = 2.0
	cs.shape = cyl
	body.position = pos + Vector3(0, 1, 0)
	body.add_child(cs)
	root.add_child(body)


## A random spot inside the arena, away from keep_clear points.
static func _free_spot(level: LevelData, d: RandomNumberGenerator, keep_clear: Array[Vector3], clearance: float, max_frac := 0.9) -> Vector3:
	var p := Vector3.ZERO
	for tries in 30:
		var a := d.randf() * TAU
		var r := sqrt(d.randf()) * level.radius * max_frac
		p = Vector3(cos(a) * r, 0, sin(a) * r)
		var ok := true
		for k in keep_clear:
			if p.distance_to(k) < clearance:
				ok = false
				break
		if ok:
			return p
	return p


static func _kelp(root: Node3D, level: LevelData, d: RandomNumberGenerator, count: int, _unused: float, keep_clear: Array[Vector3], c1: Color, c2: Color, hmin: float, hmax: float) -> void:
	var shader: Shader = load(KELP_SHADER)
	for i in count:
		var p: Vector3
		if i % 3 == 0:
			p = _free_spot(level, d, keep_clear, 3.0)
		else:
			var a := d.randf() * TAU
			var r := d.randf_range(level.radius - 4.0, level.radius + 2.0)
			p = Vector3(cos(a) * r, 0, sin(a) * r)
			var near := false
			for k in keep_clear:
				if p.distance_to(k) < 3.0:
					near = true
			if near:
				continue
		var h := d.randf_range(hmin, hmax)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, h, 0.05)
		bm.subdivide_height = 6
		mi.mesh = bm
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("tint", c1.lerp(c2, d.randf()))
		m.set_shader_parameter("phase", d.randf() * TAU)
		m.set_shader_parameter("height", h)
		mi.material_override = m
		mi.position = p + Vector3(0, h * 0.5, 0)
		mi.rotation.y = d.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


static func _shells(root: Node3D, level: LevelData, d: RandomNumberGenerator, count: int, keep_clear: Array[Vector3]) -> void:
	var cols := [Color(0.95, 0.9, 0.85), Color(0.95, 0.75, 0.7), Color(0.9, 0.85, 0.6), Color(0.8, 0.75, 0.85)]
	for i in count:
		var p := _free_spot(level, d, keep_clear, 2.0)
		var c: Color = cols[i % cols.size()]
		var mi := PartVisual._ellipsoid(root, p + Vector3(0, 0.04, 0), Vector3(0.35, 0.1, 0.28) * d.randf_range(0.6, 1.3), PartVisual.mat(c, 0, 0.1, 0.4))
		mi.rotation.y = d.randf() * TAU
		if i % 4 == 0:   # a little spiral shell
			for j in 3:
				PartVisual._ellipsoid(root, p + Vector3(0.05 * j, 0.08 + j * 0.06, 0), Vector3.ONE * (0.2 - j * 0.05), PartVisual.mat(c.darkened(0.1 * j)))


static func _coral(root: Node3D, level: LevelData, d: RandomNumberGenerator, count: int, keep_clear: Array[Vector3]) -> void:
	var cols := [Color(0.95, 0.4, 0.5), Color(0.98, 0.6, 0.25), Color(0.65, 0.4, 0.9), Color(0.3, 0.8, 0.75), Color(0.98, 0.85, 0.35)]
	for i in count:
		var p := _free_spot(level, d, keep_clear, 3.5)
		var c: Color = cols[d.randi() % cols.size()]
		var m := PartVisual.mat(c)
		match i % 3:
			0:  # branching coral
				var node := Node3D.new()
				node.position = p
				root.add_child(node)
				for b in 5:
					var dir := Vector3(d.randf_range(-0.5, 0.5), 1.0, d.randf_range(-0.5, 0.5)).normalized()
					var tip := dir * d.randf_range(0.8, 1.6)
					PartVisual._segment(node, Vector3.ZERO, tip, 0.09, 0.05, m)
					PartVisual._segment(node, tip, tip + Vector3(d.randf_range(-0.4, 0.4), 0.5, d.randf_range(-0.4, 0.4)), 0.05, 0.03, m)
			1:  # brain coral (solid)
				var s := d.randf_range(0.7, 1.3)
				PartVisual._ellipsoid(root, p + Vector3(0, s * 0.3, 0), Vector3(s * 1.4, s, s * 1.4), m)
				for b in 6:
					var a := TAU * b / 6.0
					PartVisual._ellipsoid(root, p + Vector3(cos(a) * s * 0.35, s * 0.62, sin(a) * s * 0.35), Vector3.ONE * s * 0.3, PartVisual.mat(c.darkened(0.15)))
				_solid(root, p, s * 0.65)
			2:  # sea fan
				var fan := PartVisual._ellipsoid(root, p + Vector3(0, 0.8, 0), Vector3(1.4, 1.5, 0.05), m)
				fan.rotation.y = d.randf() * TAU
				PartVisual._segment(root, p, p + Vector3(0, 0.3, 0), 0.06, 0.05, m)


static func _wreck(root: Node3D, level: LevelData, d: RandomNumberGenerator, keep_clear: Array[Vector3]) -> void:
	var wood := PartVisual.mat(Color(0.35, 0.25, 0.17), 0, 0.0, 0.9)
	var dark := PartVisual.mat(Color(0.22, 0.16, 0.12), 0, 0.0, 0.9)
	var metal := PartVisual.mat(Color(0.3, 0.3, 0.32), 0, 0.6, 0.5)
	# The broken hull: a curved row of tilted planks on one side.
	var hull_c := Vector3(-level.radius * 0.45, 0, level.radius * 0.1)
	for i in 9:
		var a := lerpf(-0.9, 0.9, i / 8.0)
		var p := hull_c + Vector3(cos(a) * 4.0, 0, sin(a) * 4.0)
		var plank := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, d.randf_range(1.5, 3.2), 1.4)
		plank.mesh = bm
		plank.material_override = wood if i % 2 else dark
		plank.position = p + Vector3(0, bm.size.y * 0.4, 0)
		plank.rotation = Vector3(0, -a, d.randf_range(-0.35, 0.1))
		root.add_child(plank)
		_solid(root, p, 0.7)
	# Fallen mast
	var mast := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.28
	cm.height = 11.0
	mast.mesh = cm
	mast.material_override = dark
	mast.position = Vector3(level.radius * 0.25, 0.25, -level.radius * 0.15)
	mast.rotation = Vector3(0, 0.7, PI * 0.5)
	root.add_child(mast)
	# Barrels and cannons
	for i in 10:
		var p := _free_spot(level, d, keep_clear, 3.5)
		if i % 3 == 0:
			var cannon := MeshInstance3D.new()
			var cc := CylinderMesh.new()
			cc.top_radius = 0.16
			cc.bottom_radius = 0.24
			cc.height = 1.6
			cannon.mesh = cc
			cannon.material_override = metal
			cannon.position = p + Vector3(0, 0.25, 0)
			cannon.rotation = Vector3(PI * 0.5, d.randf() * TAU, 0)
			root.add_child(cannon)
		else:
			var barrel := MeshInstance3D.new()
			var bc := CylinderMesh.new()
			bc.top_radius = 0.38
			bc.bottom_radius = 0.38
			bc.height = 0.9
			barrel.mesh = bc
			barrel.material_override = wood
			barrel.position = p + Vector3(0, 0.45, 0)
			if i % 2:
				barrel.rotation.z = PI * 0.5
				barrel.position.y = 0.38
			root.add_child(barrel)
			_solid(root, p, 0.45)


static func _abyss(root: Node3D, level: LevelData, d: RandomNumberGenerator, count: int, keep_clear: Array[Vector3]) -> void:
	var glow_cols := [Color(0.3, 0.9, 1.0), Color(0.7, 0.4, 1.0), Color(0.3, 1.0, 0.6)]
	var tube := PartVisual.mat(Color(0.85, 0.85, 0.8), 0, 0.0, 0.7)
	for i in count:
		var p := _free_spot(level, d, keep_clear, 3.0)
		var g: Color = glow_cols[i % glow_cols.size()]
		var glow := CritterVisual._glass(g, 0.9, 2.0)
		if i % 2 == 0:   # tube worm cluster
			for j in 4:
				var off := Vector3(d.randf_range(-0.4, 0.4), 0, d.randf_range(-0.4, 0.4))
				var h := d.randf_range(0.6, 1.6)
				PartVisual._segment(root, p + off, p + off + Vector3(0, h, 0), 0.06, 0.05, tube)
				PartVisual._ellipsoid(root, p + off + Vector3(0, h + 0.05, 0), Vector3(0.18, 0.12, 0.18), glow)
		else:            # glowing specks on the sand
			for j in 5:
				PartVisual._ellipsoid(root, p + Vector3(d.randf_range(-1, 1), 0.03, d.randf_range(-1, 1)), Vector3.ONE * 0.08, glow)


static func _bubbles(root: Node3D, level: LevelData, amount: int) -> void:
	if amount <= 0:
		return
	var bubbles := CPUParticles3D.new()
	bubbles.amount = amount
	bubbles.lifetime = 7.0
	bubbles.preprocess = 7.0
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(level.radius, 0.1, level.radius)
	bubbles.direction = Vector3.UP
	bubbles.spread = 10.0
	bubbles.gravity = Vector3(0, 0.5, 0)
	bubbles.initial_velocity_min = 0.3
	bubbles.initial_velocity_max = 0.8
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.5
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 6
	sm.rings = 3
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(0.8, 0.95, 1.0, 0.4)
	sm.material = bmat
	bubbles.mesh = sm
	root.add_child(bubbles)


## Debra's home: a Coke can on its side, open end facing `facing_dir`.
static func home_can(root: Node3D, pos: Vector3) -> Node3D:
	var home := Node3D.new()
	home.name = "Home"
	home.position = pos
	home.rotation_degrees.y = 180   # open end faces +Z (the arena centre when placed north)
	root.add_child(home)
	var can := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.1
	cyl.height = 3.2
	can.mesh = cyl
	can.material_override = PartVisual.mat(Color(0.78, 0.06, 0.08), 0, 0.5, 0.35)
	can.rotation_degrees.x = 90
	can.position.y = 1.1
	home.add_child(can)
	var band := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 1.12
	bc.bottom_radius = 1.12
	bc.height = 0.5
	band.mesh = bc
	band.material_override = PartVisual.mat(Color(0.95, 0.95, 0.95), 0, 0.2, 0.4)
	band.rotation_degrees.x = 90
	band.position = Vector3(0, 1.1, 0.3)
	home.add_child(band)
	var mouth := MeshInstance3D.new()
	var mc := CylinderMesh.new()
	mc.top_radius = 0.95
	mc.bottom_radius = 0.95
	mc.height = 0.02
	mouth.mesh = mc
	mouth.material_override = PartVisual.mat(Color(0.05, 0.03, 0.03))
	mouth.rotation_degrees.x = 90
	mouth.position = Vector3(0, 1.1, -1.61)
	home.add_child(mouth)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.1
	shape.height = 3.2
	cs.shape = shape
	cs.rotation_degrees.x = 90
	cs.position.y = 1.1
	body.add_child(cs)
	home.add_child(body)
	return home
