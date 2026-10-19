class_name CritterVisual
extends RefCounted
## Procedural placeholder bodies for non-crustacean sea creatures.
## Forward = -Z, built at "size 1"; the Critter scales and hovers the result.
## Each body has named nodes that animate() moves (Tail, Spin, Bell, Seg_i, Arm_i, WingL/R, Puff).

const KINDS: Array[StringName] = [&"starfish", &"urchin", &"jelly", &"eel", &"puffer", &"shark", &"angler", &"octopus", &"ray", &"lionfish"]

static var _glass_cache: Dictionary = {}


static func build(kind: StringName, c: Color, a: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	root.set_meta("kind", kind)
	match kind:
		&"starfish":
			_starfish(root, c, a)
		&"urchin":
			_urchin(root, c, a)
		&"jelly":
			_jelly(root, c, a)
		&"eel":
			_eel(root, c, a)
		&"puffer":
			_fish(root, c, a, {"len": 0.9, "h": 0.8, "w": 0.8, "tail": 0.3, "spikes": true, "eye": 0.12})
		&"shark":
			_fish(root, c, a, {"len": 2.2, "h": 0.6, "w": 0.6, "tail": 0.6, "dorsal": "fin", "teeth": true, "eye": 0.06, "belly": true})
		&"angler":
			_fish(root, c, a, {"len": 1.0, "h": 0.8, "w": 0.75, "tail": 0.3, "teeth": true, "lure": true, "eye": 0.07})
		&"lionfish":
			_fish(root, c, a, {"len": 1.1, "h": 0.55, "w": 0.35, "tail": 0.35, "dorsal": "spines", "stripes": 5, "eye": 0.07})
		&"octopus":
			_octopus(root, c, a)
		&"ray":
			_ray(root, c, a)
		_:
			PartVisual._ellipsoid(root, Vector3(0, 0.3, 0), Vector3.ONE * 0.6, PartVisual.mat(c))
	return root


## Idle/move animation. t = time, move = 0..1 how fast it's moving, charge = 0..1 attack windup.
static func animate(root: Node3D, t: float, move: float, charge: float) -> void:
	var kind: StringName = root.get_meta("kind", &"")
	var tail := root.get_node_or_null("Tail") as Node3D
	if tail:
		tail.rotation.y = sin(t * (6.0 + move * 6.0)) * (0.25 + move * 0.25)
	var puff := root.get_node_or_null("Puff") as Node3D
	if puff:
		puff.scale = Vector3.ONE * (1.0 + charge * 0.6)
	match kind:
		&"starfish":
			(root.get_node("Spin") as Node3D).rotation.y += 0.01 + charge * 0.4
		&"urchin":
			(root.get_node("Spin") as Node3D).scale = Vector3.ONE * (1.0 + sin(t * 2.0) * 0.03 + charge * 0.25)
		&"jelly":
			var bell := root.get_node("Bell") as Node3D
			var p := sin(t * 2.5)
			bell.scale = Vector3(1.0 - p * 0.08, 1.0 + p * 0.12, 1.0 - p * 0.08) * (1.0 + charge * 0.3)
			bell.position.y = sin(t * 1.2) * 0.12
			for i in 8:
				var tn := bell.get_node_or_null("Tent%d" % i) as Node3D
				if tn:
					tn.rotation.x = sin(t * 2.0 + i) * 0.25
		&"eel":
			for i in 10:
				var s := root.get_node_or_null("Seg%d" % i) as Node3D
				if s:
					s.position.x = sin(t * (5.0 + move * 5.0) - i * 0.8) * 0.045 * i * (0.6 + move)
		&"octopus":
			for i in 8:
				var arm := root.get_node_or_null("Arm%d" % i) as Node3D
				if arm:
					arm.rotation.x = sin(t * 2.0 + i * 0.8) * 0.18 - charge * 0.4
		&"ray":
			var flap := sin(t * (3.0 + move * 3.0)) * 0.35
			(root.get_node("WingL") as Node3D).rotation.z = -flap
			(root.get_node("WingR") as Node3D).rotation.z = flap


# --- Bodies ----------------------------------------------------------------------

static func _starfish(root: Node3D, c: Color, a: Color) -> void:
	var spin := Node3D.new()
	spin.name = "Spin"
	root.add_child(spin)
	var m := PartVisual.mat(c)
	PartVisual._ellipsoid(spin, Vector3(0, 0.1, 0), Vector3(0.45, 0.16, 0.45), m)
	for i in 5:
		var arm := Node3D.new()
		arm.rotation.y = TAU * i / 5.0
		arm.scale = Vector3(1, 0.55, 1)
		spin.add_child(arm)
		PartVisual._segment(arm, Vector3(0, 0.15, 0), Vector3(0, 0.08, -0.9), 0.17, 0.04, m)
		for j in 3:
			PartVisual._ellipsoid(arm, Vector3(0, 0.27 - j * 0.03, -0.25 - j * 0.2), Vector3.ONE * (0.07 - j * 0.012), PartVisual.mat(a))


static func _urchin(root: Node3D, c: Color, a: Color) -> void:
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.position.y = 0.4
	root.add_child(spin)
	PartVisual._ellipsoid(spin, Vector3.ZERO, Vector3.ONE * 0.75, PartVisual.mat(c))
	var sm := PartVisual.mat(a)
	var n := 34
	for i in n:
		var y := 1.0 - (i + 0.5) / n * 1.6   # skip the bottom
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var th := i * 2.39996
		var d := Vector3(cos(th) * r, y, sin(th) * r)
		PartVisual._segment(spin, d * 0.33, d * 0.85, 0.035, 0.0, sm)


static func _jelly(root: Node3D, c: Color, a: Color) -> void:
	var bell := Node3D.new()
	bell.name = "Bell"
	root.add_child(bell)
	PartVisual._ellipsoid(bell, Vector3.ZERO, Vector3(0.95, 0.6, 0.95), _glass(c, 0.55, 0.6))
	PartVisual._ellipsoid(bell, Vector3(0, -0.05, 0), Vector3(0.5, 0.35, 0.5), _glass(a, 0.8, 1.0))
	var tm := _glass(c, 0.45, 0.4)
	for i in 8:
		var ang := TAU * i / 8.0
		var tn := Node3D.new()
		tn.name = "Tent%d" % i
		tn.position = Vector3(cos(ang) * 0.36, -0.12, sin(ang) * 0.36)
		bell.add_child(tn)
		var p := Vector3.ZERO
		for j in 3:
			var q := p + Vector3(cos(ang) * 0.05, -0.32, sin(ang) * 0.05)
			PartVisual._segment(tn, p, q, 0.03 - j * 0.007, 0.02 - j * 0.006, tm)
			p = q


static func _eel(root: Node3D, c: Color, a: Color) -> void:
	var m := PartVisual.mat(c)
	var am := PartVisual.mat(a)
	for i in 10:
		var seg := Node3D.new()
		seg.name = "Seg%d" % i
		seg.position = Vector3(0, 0.25, -0.35 + i * 0.26)
		root.add_child(seg)
		var r := 0.26 - i * 0.018
		if i == 0:
			PartVisual._ellipsoid(seg, Vector3.ZERO, Vector3(0.36, 0.32, 0.6), m)
			PartVisual._ellipsoid(seg, Vector3(0, -0.1, -0.12), Vector3(0.3, 0.12, 0.5), am)   # jaw
			for x in [-1.0, 1.0]:
				PartVisual._ellipsoid(seg, Vector3(x * 0.15, 0.08, -0.18), Vector3.ONE * 0.08, PartVisual.mat(Color(0.95, 0.9, 0.3)))
				PartVisual._ellipsoid(seg, Vector3(x * 0.18, 0.09, -0.2), Vector3.ONE * 0.04, PartVisual.mat(Color.BLACK))
		else:
			PartVisual._ellipsoid(seg, Vector3.ZERO, Vector3(r * 1.6, r * 1.8, 0.4), m if i % 3 else am)


static func _octopus(root: Node3D, c: Color, a: Color) -> void:
	var m := PartVisual.mat(c)
	var mantle := PartVisual._ellipsoid(root, Vector3(0, 0.65, 0.1), Vector3(0.7, 0.8, 0.75), m)
	mantle.rotation.x = 0.35
	for x in [-1.0, 1.0]:
		PartVisual._ellipsoid(root, Vector3(x * 0.2, 0.55, -0.22), Vector3.ONE * 0.13, PartVisual.mat(Color(1, 0.95, 0.75)))
		PartVisual._ellipsoid(root, Vector3(x * 0.22, 0.56, -0.28), Vector3(0.05, 0.1, 0.03), PartVisual.mat(Color.BLACK))
	var am := PartVisual.mat(a)
	for i in 8:
		var arm := Node3D.new()
		arm.name = "Arm%d" % i
		arm.position = Vector3(0, 0.3, 0)
		arm.rotation.y = TAU * i / 8.0 + 0.2
		root.add_child(arm)
		var pts := [Vector3(0, 0, -0.18), Vector3(0, -0.18, -0.45), Vector3(0, -0.27, -0.75), Vector3(0, -0.2, -1.0)]
		for j in 3:
			PartVisual._segment(arm, pts[j], pts[j + 1], 0.09 - j * 0.025, 0.07 - j * 0.025, m if j < 2 else am)


static func _ray(root: Node3D, c: Color, a: Color) -> void:
	var m := PartVisual.mat(c)
	PartVisual._ellipsoid(root, Vector3(0, 0.2, 0), Vector3(0.9, 0.16, 1.1), m)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		wing.position = Vector3(side * 0.35, 0.2, 0)
		root.add_child(wing)
		PartVisual._ellipsoid(wing, Vector3(side * 0.4, 0, 0.05), Vector3(0.9, 0.08, 0.8), m)
		PartVisual._ellipsoid(root, Vector3(side * 0.15, 0.3, -0.3), Vector3.ONE * 0.08, PartVisual.mat(a))
	PartVisual._segment(root, Vector3(0, 0.2, 0.5), Vector3(0, 0.18, 1.7), 0.05, 0.015, m)
	PartVisual._segment(root, Vector3(0, 0.2, 1.3), Vector3(0, 0.24, 1.75), 0.04, 0.0, PartVisual.mat(a))


## Generic fish: body + tail + fins + eyes, with options.
static func _fish(root: Node3D, c: Color, a: Color, o: Dictionary) -> void:
	var length: float = o.get("len", 1.0)
	var h: float = o.get("h", 0.5)
	var w: float = o.get("w", 0.4)
	var m := PartVisual.mat(c)
	var am := PartVisual.mat(a)
	var puff := Node3D.new()
	puff.name = "Puff"
	root.add_child(puff)
	PartVisual._ellipsoid(puff, Vector3.ZERO, Vector3(w, h, length), m)
	if o.get("belly", false):
		PartVisual._ellipsoid(puff, Vector3(0, -h * 0.15, 0), Vector3(w * 0.85, h * 0.75, length * 0.9), PartVisual.mat(Color(0.92, 0.92, 0.9)))
	var stripes: int = o.get("stripes", 0)
	for i in stripes:
		var z := -length * 0.35 + i * length * 0.7 / maxf(stripes - 1, 1)
		var k := sqrt(maxf(0.0, 1.0 - pow(z / (length * 0.5), 2)))
		PartVisual._ellipsoid(puff, Vector3(0, 0, z), Vector3(w * k * 1.04, h * k * 1.04, 0.07), am)
	# Tail
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0, length * 0.45)
	root.add_child(tail)
	var ts: float = o.get("tail", 0.3)
	for s in [-1.0, 1.0]:
		var fin := PartVisual._ellipsoid(tail, Vector3(0, s * ts * 0.35, ts * 0.45), Vector3(0.04, ts * 0.9, ts * 0.7), am)
		fin.rotation.x = s * 0.6
	# Side fins
	for s in [-1.0, 1.0]:
		var pf := PartVisual._ellipsoid(puff, Vector3(s * w * 0.5, -h * 0.1, -length * 0.05), Vector3(0.3, 0.03, 0.18) * maxf(length, 0.8), am)
		pf.rotation.z = s * 0.4
	match String(o.get("dorsal", "")):
		"fin":
			var df := PartVisual._ellipsoid(puff, Vector3(0, h * 0.55, 0), Vector3(0.05, h * 1.0, length * 0.22), am)
			df.rotation.x = 0.35
		"spines":
			for i in 9:
				var ang := lerpf(-0.9, 0.9, i / 8.0)
				var base := Vector3(0, h * 0.4, ang * length * 0.3)
				PartVisual._segment(puff, base, base + Vector3(0, 0.45, ang * 0.25), 0.025, 0.0, am)
				PartVisual._segment(puff, Vector3(0, -h * 0.3, base.z), Vector3(signf(ang + 0.01) * 0.3, -h * 0.5 - 0.15, base.z + 0.1), 0.02, 0.0, am)
	if o.get("spikes", false):
		var n := 26
		for i in n:
			var y := 1.0 - (i + 0.5) / n * 2.0
			var r := sqrt(maxf(0.0, 1.0 - y * y))
			var th := i * 2.39996
			var d := Vector3(cos(th) * r * w, y * h, sin(th) * r * length) * 0.5
			PartVisual._segment(puff, d * 0.95, d * 1.3, 0.025, 0.0, am)
	# Eyes
	var eye: float = o.get("eye", 0.07)
	for s in [-1.0, 1.0]:
		PartVisual._ellipsoid(puff, Vector3(s * w * 0.42, h * 0.15, -length * 0.3), Vector3.ONE * eye * 2.0, PartVisual.mat(Color(0.95, 0.95, 0.9)))
		PartVisual._ellipsoid(puff, Vector3(s * w * 0.47, h * 0.15, -length * 0.32), Vector3.ONE * eye * 1.2, PartVisual.mat(Color.BLACK))
	if o.get("teeth", false):
		for i in 6:
			var x := lerpf(-w * 0.3, w * 0.3, i / 5.0)
			PartVisual._segment(puff, Vector3(x, -h * 0.05, -length * 0.47), Vector3(x, -h * 0.2, -length * 0.49), 0.025, 0.0, PartVisual.mat(Color(0.97, 0.97, 0.92)))
	if o.get("lure", false):
		var base := Vector3(0, h * 0.45, -length * 0.25)
		var mid := base + Vector3(0, 0.35, -0.1)
		var tip := mid + Vector3(0, 0.05, -0.35)
		PartVisual._segment(puff, base, mid, 0.025, 0.02, am)
		PartVisual._segment(puff, mid, tip, 0.02, 0.015, am)
		PartVisual._ellipsoid(puff, tip, Vector3.ONE * 0.16, _glass(Color(0.6, 1.0, 0.8), 0.95, 2.5))


## Translucent glowing material (jellies, lures).
static func _glass(c: Color, alpha: float, glow: float) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [c.to_html(), alpha, glow]
	if _glass_cache.has(key):
		return _glass_cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c, alpha)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = glow
	m.roughness = 0.3
	_glass_cache[key] = m
	return m
