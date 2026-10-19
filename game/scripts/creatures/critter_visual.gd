class_name CritterVisual
extends RefCounted
## Procedural placeholder bodies for non-crustacean sea creatures.
## Forward = -Z, built at "size 1"; the Critter scales and hovers the result.
## Each body has named nodes that animate() moves (Tail, Spin, Bell, Seg_i, Arm_i, WingL/R, Puff).

const KINDS: Array[StringName] = [&"starfish", &"urchin", &"jelly", &"eel", &"puffer", &"shark", &"angler", &"octopus", &"ray", &"lionfish",
	&"torpedo", &"seasnake", &"barracuda", &"hammerhead", &"swordfish", &"squid", &"nautilus", &"horseshoe", &"clam", &"manowar", &"cucumber"]

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
			_ray(root, c, a, false)
		&"torpedo":
			_ray(root, c, a, true)
		&"seasnake":
			_eel(root, c, a, true)
		&"barracuda":
			_fish(root, c, a, {"len": 1.9, "h": 0.32, "w": 0.28, "tail": 0.35, "teeth": true, "eye": 0.05, "dorsal": "fin"})
		&"hammerhead":
			_fish(root, c, a, {"len": 2.3, "h": 0.6, "w": 0.6, "tail": 0.6, "dorsal": "fin", "eye": 0.0, "belly": true, "hammer": true})
		&"swordfish":
			_fish(root, c, a, {"len": 1.7, "h": 0.5, "w": 0.4, "tail": 0.5, "dorsal": "sail", "eye": 0.07, "bill": true})
		&"squid":
			_squid(root, c, a)
		&"nautilus":
			_nautilus(root, c, a)
		&"horseshoe":
			_horseshoe(root, c, a)
		&"clam":
			_clam(root, c, a)
		&"manowar":
			_manowar(root, c, a)
		&"cucumber":
			_cucumber(root, c, a)
		_:
			PartVisual._ellipsoid(root, Vector3(0, 0.3, 0), Vector3.ONE * 0.6, PartVisual.mat(c))
	return root


## Idle/move animation. t = time, move = 0..1 how fast it's moving, charge = 0..1 attack windup.
## Generic: animates whatever named nodes a body has (Tail, Puff, Spin, Bell/Tent_i,
## Seg_i, Arm_i, WingL/R, Lid, Squish), so new bodies animate for free.
static func animate(root: Node3D, t: float, move: float, charge: float) -> void:
	var kind: StringName = root.get_meta("kind", &"")
	var tail := root.get_node_or_null("Tail") as Node3D
	if tail:
		tail.rotation.y = sin(t * (6.0 + move * 6.0)) * (0.25 + move * 0.25)
	var puff := root.get_node_or_null("Puff") as Node3D
	if puff:
		puff.scale = Vector3.ONE * (1.0 + charge * (0.6 if kind == &"puffer" else 0.15))
	var spin := root.get_node_or_null("Spin") as Node3D
	if spin:
		if kind == &"starfish":
			spin.rotation.y += 0.01 + charge * 0.4
		else:
			spin.scale = Vector3.ONE * (1.0 + sin(t * 2.0) * 0.03 + charge * 0.25)
	var bell := root.get_node_or_null("Bell") as Node3D
	if bell:
		var p := sin(t * 2.5)
		bell.scale = Vector3(1.0 - p * 0.08, 1.0 + p * 0.12, 1.0 - p * 0.08) * (1.0 + charge * 0.3)
		bell.position.y = sin(t * 1.2) * 0.12
		for i in 10:
			var tn := bell.get_node_or_null("Tent%d" % i) as Node3D
			if tn:
				tn.rotation.x = sin(t * 2.0 + i) * 0.25
	for i in 12:
		var s := root.get_node_or_null("Seg%d" % i) as Node3D
		if s == null:
			break
		s.position.x = sin(t * (5.0 + move * 5.0) - i * 0.8) * 0.045 * i * (0.6 + move)
	for i in 10:
		var arm := root.get_node_or_null("Arm%d" % i) as Node3D
		if arm == null:
			break
		arm.rotation.x = sin(t * 2.0 + i * 0.8) * 0.18 - charge * 0.4
	var wl := root.get_node_or_null("WingL") as Node3D
	if wl:
		var flap := sin(t * (3.0 + move * 3.0)) * (0.35 if kind == &"ray" else 0.15)
		wl.rotation.z = -flap
		(root.get_node("WingR") as Node3D).rotation.z = flap
	var lid := root.get_node_or_null("Lid") as Node3D
	if lid:   # clams gape slowly, snap open wide when attacking
		lid.rotation.x = -0.15 - (sin(t * 0.8) * 0.5 + 0.5) * 0.25 - charge * 0.6
	var squish := root.get_node_or_null("Squish") as Node3D
	if squish:
		squish.scale = Vector3(1.0 + sin(t * 3.0) * 0.06, 1.0 - sin(t * 3.0) * 0.06, 1.0 + charge * 0.3)


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


static func _eel(root: Node3D, c: Color, a: Color, thin := false) -> void:
	var m := PartVisual.mat(c)
	var am := PartVisual.mat(a)
	for i in 10:
		var seg := Node3D.new()
		seg.name = "Seg%d" % i
		seg.position = Vector3(0, 0.25, -0.35 + i * 0.26)
		root.add_child(seg)
		var r := (0.26 - i * 0.018) * (0.6 if thin else 1.0)
		if thin and i > 0:   # sea snake: bold bands, paddle tail
			PartVisual._ellipsoid(seg, Vector3.ZERO, Vector3(r * 1.6, r * 1.8, 0.4), m if i % 2 else am)
			if i == 9:
				PartVisual._ellipsoid(seg, Vector3(0, 0, 0.2), Vector3(0.04, 0.3, 0.3), am)
			continue
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


## Stingray, or (round = true) a torpedo ray: round body, stubby finned tail, glowing organs.
static func _ray(root: Node3D, c: Color, a: Color, round: bool) -> void:
	var m := PartVisual.mat(c)
	PartVisual._ellipsoid(root, Vector3(0, 0.2, 0), Vector3(1.0, 0.18, 1.0) if round else Vector3(0.9, 0.16, 1.1), m)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		wing.position = Vector3(side * 0.35, 0.2, 0)
		root.add_child(wing)
		if round:
			PartVisual._ellipsoid(wing, Vector3(side * 0.3, 0, 0.05), Vector3(0.6, 0.08, 0.85), m)
		else:
			PartVisual._ellipsoid(wing, Vector3(side * 0.4, 0, 0.05), Vector3(0.9, 0.08, 0.8), m)
		PartVisual._ellipsoid(root, Vector3(side * 0.15, 0.3, -0.3), Vector3.ONE * 0.08, PartVisual.mat(a))
		if round:   # electric organs
			PartVisual._ellipsoid(root, Vector3(side * 0.28, 0.29, 0.0), Vector3(0.22, 0.04, 0.32), _glass(a, 0.9, 1.8))
	if round:
		var tail := Node3D.new()
		tail.name = "Tail"
		tail.position = Vector3(0, 0.2, 0.5)
		root.add_child(tail)
		PartVisual._segment(tail, Vector3.ZERO, Vector3(0, 0, 0.6), 0.09, 0.05, m)
		PartVisual._ellipsoid(tail, Vector3(0, 0.05, 0.7), Vector3(0.05, 0.3, 0.25), PartVisual.mat(a))
	else:
		PartVisual._segment(root, Vector3(0, 0.2, 0.5), Vector3(0, 0.18, 1.7), 0.05, 0.015, m)
		PartVisual._segment(root, Vector3(0, 0.2, 1.3), Vector3(0, 0.24, 1.75), 0.04, 0.0, PartVisual.mat(a))


static func _squid(root: Node3D, c: Color, a: Color) -> void:   # cuttlefish
	var m := PartVisual.mat(c)
	var am := PartVisual.mat(a)
	var puff := Node3D.new()
	puff.name = "Puff"
	root.add_child(puff)
	PartVisual._ellipsoid(puff, Vector3(0, 0, 0.15), Vector3(0.6, 0.42, 1.1), m)
	for i in 5:   # zebra stripes
		PartVisual._ellipsoid(puff, Vector3(0, 0.12, -0.2 + i * 0.18), Vector3(0.5, 0.25, 0.06), am)
	for side in [-1.0, 1.0]:
		var fin := Node3D.new()
		fin.name = "WingL" if side < 0 else "WingR"
		fin.position = Vector3(side * 0.28, -0.02, 0.15)
		root.add_child(fin)
		PartVisual._ellipsoid(fin, Vector3(side * 0.1, 0, 0), Vector3(0.22, 0.03, 1.0), am)
		PartVisual._ellipsoid(puff, Vector3(side * 0.24, 0.08, -0.32), Vector3.ONE * 0.13, PartVisual.mat(Color(0.95, 0.9, 0.6)))
		PartVisual._ellipsoid(puff, Vector3(side * 0.28, 0.08, -0.36), Vector3(0.04, 0.09, 0.04), PartVisual.mat(Color.BLACK))
	for i in 8:
		var arm := Node3D.new()
		arm.name = "Arm%d" % i
		arm.position = Vector3(lerpf(-0.18, 0.18, i / 7.0), -0.05, -0.38)
		root.add_child(arm)
		var reach := 0.65 if i == 3 or i == 4 else 0.35   # the two long hunting tentacles
		PartVisual._segment(arm, Vector3.ZERO, Vector3(0, -0.05, -reach), 0.035, 0.012, m)


static func _nautilus(root: Node3D, c: Color, a: Color) -> void:
	var puff := Node3D.new()
	puff.name = "Puff"
	root.add_child(puff)
	for i in 7:   # coiled, striped shell
		var t := i / 6.0
		var r := 0.42 * (1.0 - t * 0.7)
		var ang := t * 4.0
		var p := Vector3(0, sin(ang) * 0.25 * (1.0 - t), 0.1 + cos(ang) * 0.25 * (1.0 - t))
		PartVisual._ellipsoid(puff, p, Vector3(0.55 * (1.0 - t * 0.5), r * 2.0, r * 2.0), PartVisual.mat(c if i % 2 == 0 else a))
	PartVisual._ellipsoid(puff, Vector3(0, -0.05, -0.28), Vector3(0.4, 0.3, 0.2), PartVisual.mat(Color(0.8, 0.6, 0.55)))
	for side in [-1.0, 1.0]:
		PartVisual._ellipsoid(puff, Vector3(side * 0.16, 0.0, -0.36), Vector3.ONE * 0.08, PartVisual.mat(Color.BLACK))
	for i in 8:
		var arm := Node3D.new()
		arm.name = "Arm%d" % i
		arm.position = Vector3(lerpf(-0.15, 0.15, i / 7.0), -0.12, -0.36)
		root.add_child(arm)
		PartVisual._segment(arm, Vector3.ZERO, Vector3(lerpf(-0.1, 0.1, i / 7.0), -0.08, -0.3), 0.02, 0.01, PartVisual.mat(Color(0.85, 0.7, 0.6)))


static func _horseshoe(root: Node3D, c: Color, a: Color) -> void:
	var m := PartVisual.mat(c, 0, 0.3, 0.35)
	PartVisual._ellipsoid(root, Vector3(0, 0.15, -0.1), Vector3(1.2, 0.3, 1.0), m)                  # helmet
	PartVisual._ellipsoid(root, Vector3(0, 0.12, 0.45), Vector3(0.7, 0.22, 0.45), PartVisual.mat(a))  # rear plate
	for side in [-1.0, 1.0]:
		PartVisual._ellipsoid(root, Vector3(side * 0.3, 0.29, -0.15), Vector3(0.1, 0.05, 0.14), PartVisual.mat(Color(0.1, 0.1, 0.1)))
		for i in 3:
			PartVisual._segment(root, Vector3(side * 0.3, 0.12, 0.38 + i * 0.07), Vector3(side * 0.42, 0.12, 0.4 + i * 0.07), 0.02, 0.0, PartVisual.mat(a))
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.12, 0.65)
	root.add_child(tail)
	PartVisual._segment(tail, Vector3.ZERO, Vector3(0, 0.03, 1.0), 0.05, 0.0, PartVisual.mat(a))


static func _clam(root: Node3D, c: Color, a: Color) -> void:
	var shell_m := PartVisual.mat(c)
	var rib_m := PartVisual.mat(c.darkened(0.2))
	PartVisual._ellipsoid(root, Vector3(0, 0.22, 0), Vector3(1.6, 0.45, 1.1), shell_m)   # bottom valve
	PartVisual._ellipsoid(root, Vector3(0, 0.35, -0.05), Vector3(1.4, 0.18, 0.9), PartVisual.mat(a))   # mantle
	PartVisual._ellipsoid(root, Vector3(0, 0.45, -0.05), Vector3.ONE * 0.22, _glass(Color(1, 0.95, 0.9), 0.95, 0.6))   # pearl
	var lid := Node3D.new()   # top valve, hinged at the back
	lid.name = "Lid"
	lid.position = Vector3(0, 0.42, 0.5)
	root.add_child(lid)
	PartVisual._ellipsoid(lid, Vector3(0, 0.05, -0.5), Vector3(1.6, 0.4, 1.1), shell_m)
	for i in 5:
		var x := lerpf(-0.55, 0.55, i / 4.0)
		PartVisual._segment(lid, Vector3(x * 0.3, 0.24, -0.05), Vector3(x, 0.12, -0.95), 0.04, 0.03, rib_m)


static func _manowar(root: Node3D, c: Color, a: Color) -> void:
	var bell := Node3D.new()
	bell.name = "Bell"
	root.add_child(bell)
	PartVisual._ellipsoid(bell, Vector3.ZERO, Vector3(0.55, 0.45, 1.0), _glass(c, 0.6, 0.7))   # float
	PartVisual._ellipsoid(bell, Vector3(0, 0.22, 0), Vector3(0.12, 0.3, 0.9), _glass(a, 0.75, 1.0))  # crest
	var tm := _glass(a, 0.5, 0.6)
	for i in 10:
		var tn := Node3D.new()
		tn.name = "Tent%d" % i
		tn.position = Vector3(lerpf(-0.18, 0.18, (i % 3) / 2.0), -0.18, lerpf(-0.35, 0.35, i / 9.0))
		bell.add_child(tn)
		var p := Vector3.ZERO
		for j in 4:
			var q := p + Vector3(0, -0.32, 0.04)
			PartVisual._segment(tn, p, q, 0.022, 0.014, tm)
			p = q


static func _cucumber(root: Node3D, c: Color, a: Color) -> void:
	var squish := Node3D.new()
	squish.name = "Squish"
	root.add_child(squish)
	var m := PartVisual.mat(c, 0, 0.0, 0.85)
	for i in 5:
		PartVisual._ellipsoid(squish, Vector3(0, 0.22, -0.5 + i * 0.25), Vector3(0.5, 0.42, 0.45) * (1.0 - absf(i - 2) * 0.08), m)
	for i in 14:
		var ang := i * 2.39996
		PartVisual._ellipsoid(squish, Vector3(cos(ang) * 0.2, 0.32 + sin(ang) * 0.08, -0.5 + (i % 7) * 0.17), Vector3.ONE * 0.09, PartVisual.mat(a))
	for i in 6:   # feeding tentacles
		var ang := TAU * i / 6.0
		PartVisual._segment(squish, Vector3(cos(ang) * 0.1, 0.24 + sin(ang) * 0.1, -0.68), Vector3(cos(ang) * 0.22, 0.24 + sin(ang) * 0.22, -0.85), 0.03, 0.015, PartVisual.mat(a))


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
	if String(o.get("dorsal", "")) == "sail":   # swordfish: tall sail fin
		var sail := PartVisual._ellipsoid(puff, Vector3(0, h * 0.75, -length * 0.05), Vector3(0.04, h * 1.6, length * 0.55), am)
		sail.rotation.x = 0.15
	if o.get("bill", false):   # swordfish bill
		PartVisual._segment(puff, Vector3(0, 0.02, -length * 0.45), Vector3(0, 0.0, -length * 0.45 - 1.1), 0.06, 0.0, am)
	if o.get("hammer", false):   # hammerhead: a wide flat head with eyes at the tips
		PartVisual._ellipsoid(puff, Vector3(0, 0.0, -length * 0.45), Vector3(1.3, 0.14, 0.32), PartVisual.mat(c))
		for s in [-1.0, 1.0]:
			PartVisual._ellipsoid(puff, Vector3(s * 0.62, 0.02, -length * 0.45), Vector3.ONE * 0.11, PartVisual.mat(Color(0.95, 0.9, 0.5)))
			PartVisual._ellipsoid(puff, Vector3(s * 0.66, 0.02, -length * 0.46), Vector3.ONE * 0.06, PartVisual.mat(Color.BLACK))
	# Eyes
	var eye: float = o.get("eye", 0.07)
	for s in ([-1.0, 1.0] if eye > 0.0 else []):
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
