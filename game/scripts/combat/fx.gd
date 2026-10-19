class_name FX
extends RefCounted
## One-shot effects (all Compatibility-renderer safe): damage numbers, claw
## swipes per style, rings, sparks, lightning, tentacles, ground telegraphs,
## and camera shake. Everything frees itself.

static var _unshaded: Dictionary = {}


## Floating damage number.
static func number(parent: Node, pos: Vector3, value: float, col: Color) -> void:
	if parent == null:
		return
	var l := Label3D.new()
	l.text = str(roundi(value))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 56
	l.outline_size = 12
	l.pixel_size = 0.008
	l.modulate = col
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0, 0)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position:y", pos.y + 0.9, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)


## Claw attack visual, different for every style.
static func claw(parent: Node, pos: Vector3, dir: Vector3, reach: float, arc: float, style: StringName, team: int) -> void:
	var warm := Color(1, 0.85, 0.6) if team == 0 else Color(1, 0.45, 0.35)
	var tip := pos + dir.normalized() * reach * 0.8
	match style:
		&"crush":
			slash(parent, pos, dir, reach, arc, warm, 0.25)
			cracks(parent, Vector3(tip.x, 0.03, tip.z), reach * 0.6)
			burst(parent, tip, Color(0.75, 0.7, 0.6), 14, 3.0, 0.12)
			shake(parent, 0.25)
		&"cut":
			slash(parent, pos, dir.rotated(Vector3.UP, 0.25), reach, arc * 0.6, Color(0.85, 0.95, 1.0), 0.14, 0.25)
			slash(parent, pos, dir.rotated(Vector3.UP, -0.25), reach, arc * 0.6, Color(0.85, 0.95, 1.0), 0.14, 0.25)
		&"bite":
			chomp(parent, tip, dir, Color(1, 0.95, 0.9))
			burst(parent, tip, Color(0.9, 0.2, 0.2), 8, 2.0, 0.08)
		&"lash":
			ribbon(parent, PackedVector3Array([pos, pos + dir * reach * 0.5 + dir.cross(Vector3.UP) * 0.25, pos + dir * reach]), 0.12, warm, 0.22)
			burst(parent, pos + dir * reach, warm, 6, 2.0, 0.07)
		&"sting":
			ribbon(parent, PackedVector3Array([pos, pos + dir * reach]), 0.08, Color(0.6, 1.0, 0.4), 0.2)
			burst(parent, tip, Color(0.5, 1.0, 0.3), 12, 1.5, 0.1)
		&"rake":
			for i in 3:
				slash(parent, pos, dir.rotated(Vector3.UP, (i - 1) * 0.35), reach, arc * 0.35, warm, 0.16, 0.2)
		_:  # pinch
			slash(parent, pos, dir, reach, arc, warm, 0.16)
			burst(parent, tip, Color(1, 1, 0.8), 5, 2.0, 0.06)


## Flat fading arc on the ground.
static func slash(parent: Node, pos: Vector3, dir: Vector3, reach: float, arc_deg: float, col: Color, sec := 0.18, inner := 0.45) -> void:
	if parent == null:
		return
	var im := ImmediateMesh.new()
	var half := deg_to_rad(arc_deg) * 0.5
	var base := atan2(dir.x, dir.z)
	var steps := 12
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in steps + 1:
		var a := base - half + 2.0 * half * i / steps
		var d := Vector3(sin(a), 0, cos(a))
		im.surface_add_vertex(d * reach * inner)
		im.surface_add_vertex(d * reach)
	im.surface_end()
	_fade(parent, im, pos, col, 0.85, sec)


## A flat strip through points (whips, stings, tentacles).
static func ribbon(parent: Node, pts: PackedVector3Array, width: float, col: Color, sec := 0.2, glow := true) -> MeshInstance3D:
	if parent == null or pts.size() < 2:
		return null
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var origin := pts[0]
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var side := (b - a).cross(Vector3.UP).normalized() * width * 0.5 * (1.0 - 0.6 * float(i) / pts.size())
		im.surface_add_vertex(pts[i] - origin + side)
		im.surface_add_vertex(pts[i] - origin - side)
	im.surface_end()
	return _fade(parent, im, origin, col, 0.8, sec, glow)


## Two crescents snapping shut.
static func chomp(parent: Node, pos: Vector3, dir: Vector3, col: Color) -> void:
	if parent == null:
		return
	var side := dir.cross(Vector3.UP).normalized()
	for s in [-1.0, 1.0]:
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in 9:
			var t := lerpf(-1.0, 1.0, i / 8.0)
			var p: Vector3 = dir * t * 0.7 + side * s * (0.55 - 0.3 * t * t)
			im.surface_add_vertex(p)
			im.surface_add_vertex(p + side * s * 0.16)
		im.surface_end()
		var mi := _fade(parent, im, pos + Vector3(0, 0.3, 0), col, 0.85, 0.22)
		mi.create_tween().tween_property(mi, "position", -side * s * 0.22, 0.09)


## Dark cracks radiating on the ground (crush).
static func cracks(parent: Node, pos: Vector3, radius: float) -> void:
	if parent == null:
		return
	for i in 6:
		var a := TAU * i / 6.0 + randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		var mid := d * radius * 0.5 + d.cross(Vector3.UP) * randf_range(-0.15, 0.15)
		ribbon(parent, PackedVector3Array([pos, pos + mid, pos + d * radius]), 0.07, Color(0.08, 0.06, 0.05), 0.6, false)


## Expanding, fading ring (pulses, pops, slams).
static func ring(parent: Node, pos: Vector3, radius: float, col: Color, sec := 0.25) -> void:
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 6
	mi.mesh = t
	var m := _mat(col, 0.7)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 0.3
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(radius, radius * 0.5, radius), sec)
	tw.tween_property(m, "albedo_color:a", 0.0, sec)
	tw.chain().tween_callback(mi.queue_free)


## Big slam: double ring, dust and shake.
static func shockwave(parent: Node, pos: Vector3, radius: float, col: Color) -> void:
	ring(parent, pos + Vector3(0, 0.1, 0), radius, col, 0.35)
	ring(parent, pos + Vector3(0, 0.2, 0), radius * 0.6, Color(1, 1, 1), 0.25)
	burst(parent, pos + Vector3(0, 0.2, 0), Color(0.7, 0.65, 0.55), 24, 5.0, 0.15)
	cracks(parent, Vector3(pos.x, 0.03, pos.z), radius * 0.7)
	shake(parent, 0.45)


## Little particle burst (sparks, dust, poison puffs).
static func burst(parent: Node, pos: Vector3, col: Color, count: int, speed: float, size: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(count / (2 if Platform.is_low() else 1), 2)
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -4, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _mat(col, 0.9)
	p.mesh = sm
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(0.6).timeout.connect(p.queue_free)


## Jagged lightning bolt from a to b.
static func lightning(parent: Node, a: Vector3, b: Vector3, col: Color) -> void:
	if parent == null:
		return
	for k in 2:
		var pts := PackedVector3Array()
		var n := 8
		var side := (b - a).cross(Vector3.UP).normalized()
		for i in n + 1:
			var t := float(i) / n
			var jitter := 0.0 if i == 0 or i == n else randf_range(-0.35, 0.35)
			pts.append(a.lerp(b, t) + side * jitter + Vector3(0, randf_range(-0.1, 0.1), 0))
		var mi := ribbon(parent, pts, 0.14 if k == 0 else 0.06, col if k == 0 else Color.WHITE, 0.25)
		if mi:
			mi.material_override.set("emission_enabled", true)
	burst(parent, b, col, 8, 3.0, 0.06)


## Telegraph: a ground circle that fills up over `sec`, then vanishes.
static func warn_circle(parent: Node, pos: Vector3, radius: float, sec: float, col := Color(1, 0.25, 0.2)) -> void:
	if parent == null:
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = Vector3(pos.x, 0.04, pos.z)
	var edge := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.93
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 4
	edge.mesh = t
	edge.material_override = _mat(col, 0.8)
	edge.scale = Vector3(radius, 0.05, radius)
	root.add_child(edge)
	var fill := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.0
	c.height = 0.01
	c.radial_segments = 32
	fill.mesh = c
	fill.material_override = _mat(col, 0.28)
	fill.scale = Vector3(0.05, 1, 0.05)
	root.add_child(fill)
	var tw := root.create_tween()
	tw.tween_property(fill, "scale", Vector3(radius, 1, radius), maxf(sec, 0.05))
	tw.tween_callback(root.queue_free)


## Telegraph: a lane on the ground showing where a charge will go.
static func warn_lane(parent: Node, from: Vector3, dir: Vector3, length: float, width: float, sec: float) -> void:
	if parent == null:
		return
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var a := Vector3(from.x, 0.04, from.z)
	var mi := ribbon(parent, PackedVector3Array([a, a + d * length * 0.5, a + d * length]), width, Color(1, 0.25, 0.2), sec)
	if mi:
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.35


## Shake the follow camera (if any).
static func shake(node: Node, amount: float) -> void:
	if node and node.is_inside_tree():
		node.get_tree().call_group("follow_camera", "shake", amount)


static func _fade(parent: Node, mesh: Mesh, pos: Vector3, col: Color, alpha: float, sec: float, glow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:   # additive: swipes and bolts glow against the dark water
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col, alpha)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, sec)
	tw.tween_callback(mi.queue_free)
	return mi


## Unique (tweenable) unshaded transparent material.
static func _mat(col: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col, alpha)
	return m
