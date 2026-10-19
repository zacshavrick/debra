class_name PartVisual
extends RefCounted
## Builds the look of a part as a Node3D whose origin is the attach point,
## so it snaps onto a CrabBody socket with no offset math.
##
## Placeholder parts are procedural (primitive meshes driven by PartData.shape).
## A part with `visual_scene` set uses that model instead. Claws are built for
## the right side; `side` = -1 mirrors one for the left socket.
##
## Rig contract (see docs/ARCHITECTURE.md): leg feet reach FOOT_Y below the
## legs socket; the moving pincer finger is a node named "Jaw"; each walking
## leg is a node with meta "leg_index".

## Ground height relative to the legs socket (-(TORSO_Y + socket y)), feet dug in a hair.
const FOOT_Y := -0.46

static var _materials: Dictionary = {}


static func build(part: PartInstance, side := 1) -> Node3D:
	var d := part.data
	var root: Node3D
	if d.visual_scene:
		root = d.visual_scene.instantiate() as Node3D
		if side < 0:
			root.scale.x = -1.0
	else:
		root = Node3D.new()
		var s := d.shape
		match d.slot:
			PartData.Slot.HEAD:
				_build_head(root, d, s, part.rarity)
			PartData.Slot.SHELL:
				_build_shell(root, d, s, part.rarity)
			PartData.Slot.CLAW:
				_build_claw(root, d, s, part.rarity, signi(side))
			PartData.Slot.LEGS:
				_build_legs(root, d, s, part.rarity)
			PartData.Slot.TAIL:
				_build_tail(root, d, s, part.rarity)
	root.name = String(d.id)
	root.set_meta("part_id", d.id)
	return root


# --- Slots -----------------------------------------------------------------------

static func _build_head(root: Node3D, d: PartData, s: Dictionary, r: int) -> void:
	var col := mat(d.color, r)
	var acc := mat(d.accent, r)
	var stalk: float = s.get("stalk", 0.22)
	var eye: float = s.get("eye", 0.075)
	var spread: float = s.get("spread", 0.11)
	var stretch: float = s.get("eye_stretch", 1.0)
	var antennae: int = s.get("antennae", 2)
	var antenna_len: float = s.get("antenna_len", 0.35)
	_ellipsoid(root, Vector3(0, 0, 0), Vector3(0.34, 0.12, 0.16), col)   # face plate
	for x in [-1.0, 1.0]:
		var base := Vector3(x * spread, 0.03, -0.02)
		var tip := base + Vector3(x * 0.04, stalk, -0.05)
		_segment(root, base, tip, 0.028, 0.022, col)
		_ellipsoid(root, tip, Vector3(eye * 2.0 * stretch, eye * 2.0, eye * 2.0), acc)
		_ellipsoid(root, tip + Vector3(x * eye * 0.25, eye * 0.45, -eye * 0.6), Vector3.ONE * eye * 0.6, mat(Color.WHITE))
	for i in antennae:
		var x := -1.0 if i % 2 == 0 else 1.0
		var base := Vector3(x * 0.05, 0.0, -0.08)
		var tip := base + Vector3(x * (0.12 + 0.05 * (i / 2)), antenna_len * 0.35, -antenna_len)
		_segment(root, base, tip, 0.014, 0.006, acc)
	match String(s.get("extra", "")):
		"crown":   # king crab: a ring of spikes
			for i in 7:
				var a := lerpf(-1.2, 1.2, i / 6.0)
				var base := Vector3(sin(a) * 0.16, 0.06, 0.02 - cos(a) * 0.05)
				var tip := base + Vector3(sin(a) * 0.06, 0.2 + (0.1 if i == 3 else 0.0), 0.0)
				_segment(root, base, tip, 0.035, 0.0, acc)
		"lure":    # angler: a stalk with a glowing bulb
			var b0 := Vector3(0, 0.06, 0.02)
			var b1 := Vector3(0, 0.34, -0.05)
			var b2 := Vector3(0, 0.36, -0.3)
			_segment(root, b0, b1, 0.022, 0.018, col)
			_segment(root, b1, b2, 0.018, 0.012, col)
			_ellipsoid(root, b2, Vector3.ONE * 0.14, CritterVisual._glass(d.accent, 0.95, 2.5))
		"crest":   # lionfish: a fan of venomous spines
			for i in 9:
				var a := lerpf(-1.1, 1.1, i / 8.0)
				var base := Vector3(sin(a) * 0.1, 0.06, 0.04)
				_segment(root, base, base + Vector3(sin(a) * 0.25, 0.32 * cos(a * 0.6), 0.12), 0.02, 0.0, col if i % 2 else acc)
		"hammer":  # hammerhead: a wide bar with eyes on the ends
			_ellipsoid(root, Vector3(0, 0.06, -0.06), Vector3(0.9, 0.1, 0.22), col)
			for x in [-1.0, 1.0]:
				_ellipsoid(root, Vector3(x * 0.43, 0.08, -0.06), Vector3.ONE * 0.09, mat(Color(0.95, 0.9, 0.5), r))
				_ellipsoid(root, Vector3(x * 0.46, 0.08, -0.08), Vector3.ONE * 0.05, mat(Color.BLACK))
		"float":   # man o' war: a translucent sail-crested bladder
			_ellipsoid(root, Vector3(0, 0.2, 0.05), Vector3(0.3, 0.3, 0.55), CritterVisual._glass(d.color, 0.6, 0.7))
			_ellipsoid(root, Vector3(0, 0.36, 0.05), Vector3(0.07, 0.2, 0.5), CritterVisual._glass(d.accent, 0.75, 1.0))
		"jelly":   # a glowing jelly cap with dangling bits
			var g := CritterVisual._glass(d.color, 0.6, 0.8)
			_ellipsoid(root, Vector3(0, 0.17, 0.02), Vector3(0.42, 0.3, 0.36), g)
			for i in 5:
				var x := lerpf(-0.14, 0.14, i / 4.0)
				_segment(root, Vector3(x, 0.06, -0.14), Vector3(x * 1.2, -0.1, -0.2), 0.015, 0.008, g)


static func _build_shell(root: Node3D, d: PartData, s: Dictionary, r: int) -> void:
	var col := mat(d.color, r, s.get("metallic", 0.0), s.get("roughness", 0.6))
	var acc := mat(d.accent, r)
	var w: float = s.get("width", 1.0)
	var h: float = s.get("height", 0.32)
	var l: float = s.get("length", 0.85)
	match String(s.get("kind", "dome")):
		"spiral":   # hermit conch sitting on a smaller carapace
			_ellipsoid(root, Vector3(0, 0.04, 0), Vector3(w * 0.8, h, l * 0.8), acc)
			for i in 6:
				var t := i / 5.0
				var rad := 0.36 * (1.0 - t * 0.75)
				var pos := Vector3(sin(t * 5.0) * 0.12, 0.14 + t * 0.5, 0.12 + t * 0.12)
				_ellipsoid(root, pos, Vector3.ONE * rad * 2.0, mat(d.color.lerp(d.accent, t * 0.6), r))
		"slim":     # segmented mantis carapace
			for i in 4:
				var c := col if i % 2 == 0 else acc
				_ellipsoid(root, Vector3(0, 0.04, -0.27 + i * 0.19), Vector3(w * (1.0 - i * 0.1), h, 0.32), c)
		"lobster":  # long carapace (the tail itself is a Tail part)
			_ellipsoid(root, Vector3(0, 0.05, -0.05), Vector3(w * 0.85, h, l * 0.9), col)
			_ellipsoid(root, Vector3(0, 0.03, l * 0.38), Vector3(w * 0.6, h * 0.75, 0.24), acc)
		"star":     # starfish on your back
			_ellipsoid(root, Vector3(0, 0.08, 0), Vector3(0.45, h, 0.45), col)
			for i in 5:
				var arm := Node3D.new()
				arm.rotation.y = TAU * i / 5.0 + PI
				arm.scale = Vector3(1, 0.5, 1)
				root.add_child(arm)
				_segment(arm, Vector3(0, 0.15, 0), Vector3(0, 0.1, -0.55 * w), 0.15, 0.04, col)
				_ellipsoid(arm, Vector3(0, 0.26, -0.22), Vector3.ONE * 0.07, acc)
		"urchin":   # dome bristling with spines
			_ellipsoid(root, Vector3(0, 0.05, 0), Vector3(w * 0.9, h * 1.1, l * 0.9), col)
			for i in 26:
				var y := 1.0 - (i + 0.5) / 26.0
				var rr := sqrt(maxf(0.0, 1.0 - y * y))
				var th := i * 2.39996
				var dn := Vector3(cos(th) * rr * w * 0.45, y * h * 0.55, sin(th) * rr * l * 0.45)
				_segment(root, dn + Vector3(0, 0.05, 0), dn * 1.9 + Vector3(0, 0.05, 0), 0.03, 0.0, acc)
		"puffer":   # a round, spiky ball
			_ellipsoid(root, Vector3(0, 0.12, 0), Vector3(w * 0.95, h * 1.6, l * 0.95), col)
			for i in 20:
				var y := 1.0 - (i + 0.5) / 20.0
				var rr := sqrt(maxf(0.0, 1.0 - y * y))
				var th := i * 2.39996
				var dn := Vector3(cos(th) * rr * w * 0.47, y * h * 0.8, sin(th) * rr * l * 0.47)
				_segment(root, dn + Vector3(0, 0.12, 0), dn * 1.3 + Vector3(0, 0.12, 0), 0.025, 0.0, acc)
		"fin":      # shark fin carapace
			_ellipsoid(root, Vector3(0, 0.05, 0), Vector3(w, h, l), col)
			var df := _ellipsoid(root, Vector3(0, h * 0.5 + 0.18, 0.08), Vector3(0.05, 0.55, 0.36), acc)
			df.rotation.x = 0.4
		"isopod":   # armoured bands
			for i in 6:
				_ellipsoid(root, Vector3(0, 0.05, -0.38 + i * 0.15), Vector3(w * (1.0 - absf(i - 2.5) * 0.08), h, 0.2), col if i % 2 == 0 else acc)
		"horseshoe": # smooth helmet + rear plate
			_ellipsoid(root, Vector3(0, 0.05, -0.05), Vector3(w * 1.1, h * 0.8, l * 0.95), mat(d.color, r, 0.3, 0.35))
			_ellipsoid(root, Vector3(0, 0.04, l * 0.42), Vector3(w * 0.65, h * 0.6, 0.35), acc)
		"clam":     # two ribbed valves, slightly open
			_ellipsoid(root, Vector3(0, 0.0, 0), Vector3(w * 1.05, h * 0.6, l), col)
			var top := _ellipsoid(root, Vector3(0, 0.14, 0.04), Vector3(w * 1.05, h * 0.6, l), col)
			top.rotation.x = -0.18
			for i in 5:
				var x := lerpf(-0.4, 0.4, i / 4.0) * w
				_segment(root, Vector3(x * 0.3, h * 0.45, l * 0.35), Vector3(x, h * 0.3, -l * 0.4), 0.025, 0.02, acc)
		"cucumber": # lumpy, squishy hide
			for i in 3:
				_ellipsoid(root, Vector3(0, 0.05, -0.25 + i * 0.25), Vector3(w * 0.9, h, 0.45), col)
			for i in 10:
				var ang := i * 2.39996
				_ellipsoid(root, Vector3(cos(ang) * w * 0.3, 0.05 + h * 0.45, -0.3 + (i % 5) * 0.15), Vector3.ONE * 0.08, acc)
		"decorator": # dome wearing bits of the seafloor
			_ellipsoid(root, Vector3(0, 0.05, 0), Vector3(w, h, l), col)
			var bits := [Color(0.3, 0.7, 0.3), Color(0.9, 0.35, 0.35), Color(0.95, 0.8, 0.3), Color(0.4, 0.55, 0.9), Color(0.7, 0.4, 0.8)]
			for i in 9:
				var a := TAU * i / 9.0 + 0.3
				var p := Vector3(cos(a) * w * 0.28, 0.05 + h * 0.42, sin(a) * l * 0.28)
				if i % 3 == 0:
					_segment(root, p, p + Vector3(0, 0.22, 0), 0.025, 0.012, mat(bits[i % bits.size()], r))
				else:
					_ellipsoid(root, p, Vector3(0.12, 0.08, 0.12), mat(bits[i % bits.size()], r))
		_:          # dome
			_ellipsoid(root, Vector3(0, 0.05, 0), Vector3(w, h, l), col)
	var spikes: int = s.get("spikes", 0)
	for i in spikes:
		var a := deg_to_rad(lerpf(-70.0, 70.0, (i + 0.5) / spikes)) if spikes > 1 else 0.0
		var base := Vector3(sin(a) * w * 0.47, 0.06, -cos(a) * l * 0.47)
		var out := Vector3(sin(a), 0.25, -cos(a)).normalized()
		_segment(root, base, base + out * 0.14, 0.045, 0.0, acc)
	var spots: int = s.get("spots", 0)
	for i in spots:
		var a := TAU * i / spots
		_ellipsoid(root, Vector3(cos(a) * w * 0.2, 0.05 + h * 0.48, sin(a) * l * 0.2), Vector3(0.1, 0.03, 0.1), acc)
	if s.get("hairy", false):   # yeti crab fuzz
		for i in 24:
			var ang := i * 2.39996
			var rr := sqrt((i + 0.5) / 24.0)
			var p := Vector3(cos(ang) * rr * w * 0.45, 0.05 + h * 0.5 * (1.0 - rr * rr * 0.8), sin(ang) * rr * l * 0.45)
			_segment(root, p, p + Vector3(0, 0.12, 0) + p.normalized() * 0.05, 0.012, 0.004, acc)
	if s.get("pearl", false):
		_ellipsoid(root, Vector3(0, 0.05 + h * 0.55, 0), Vector3.ONE * 0.16, mat(Color(1, 0.97, 0.95), r, 0.3, 0.15))


static func _build_claw(root: Node3D, d: PartData, s: Dictionary, r: int, side: int) -> void:
	var col := mat(d.color, r)
	var acc := mat(d.accent, r)
	var kind := String(s.get("kind", "pincer"))
	var k: float = s.get("arm", 0.32) / 0.32
	var size: float = s.get("size", 0.26)
	var thick := 0.06 if kind == "crusher" else (0.035 if kind == "lash" else 0.045)
	var x := float(side)
	var elbow := Vector3(x * 0.2, 0.06, -0.1) * k
	var wrist := elbow + Vector3(-x * 0.02, 0.0, -0.22) * k
	_segment(root, Vector3.ZERO, elbow, thick, thick * 0.9, col)
	_segment(root, elbow, wrist, thick * 0.9, thick * 0.8, col)
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = wrist
	root.add_child(hand)
	var jaw := Node3D.new()
	jaw.name = "Jaw"
	jaw.set_meta("open_sign", -x)
	match kind:
		"crusher":
			_ellipsoid(hand, Vector3(0, 0, -size * 0.45), Vector3(size * 1.1, size * 0.85, size * 1.2), col)
			_segment(hand, Vector3(x * size * 0.2, 0, -size * 0.9), Vector3(x * size * 0.12, 0, -size * 1.45), size * 0.24, size * 0.12, acc)
			jaw.position = Vector3(-x * size * 0.25, 0.02, -size * 0.85)
			_segment(jaw, Vector3.ZERO, Vector3(x * size * 0.08, 0, -size * 0.55), size * 0.22, size * 0.1, acc)
		"snapper":
			_ellipsoid(hand, Vector3(0, 0, -size * 0.5), Vector3(size * 0.55, size * 0.55, size * 1.3), col)
			_ellipsoid(hand, Vector3(0, 0.02, -size * 1.1), Vector3.ONE * size * 0.6, acc)
			jaw.position = Vector3(-x * size * 0.12, 0.05, -size * 0.6)
			_segment(jaw, Vector3.ZERO, Vector3(x * size * 0.05, 0, -size * 0.75), size * 0.12, size * 0.04, col)
		"cutter":   # slim, long, fast pincer
			_ellipsoid(hand, Vector3(0, 0, -size * 0.6), Vector3(size * 0.5, size * 0.4, size * 1.4), col)
			_segment(hand, Vector3(x * size * 0.08, 0, -size * 1.2), Vector3(x * size * 0.02, 0, -size * 2.1), size * 0.1, size * 0.01, acc)
			jaw.position = Vector3(-x * size * 0.1, 0.02, -size * 1.15)
			_segment(jaw, Vector3.ZERO, Vector3(x * size * 0.08, 0, -size * 0.9), size * 0.09, size * 0.01, acc)
		"lash":     # long thin forearm ending in a hook
			var fore := Vector3(x * 0.05, 0, -0.35) * k
			var tip := fore + Vector3(x * 0.03, 0, -0.3) * k
			_segment(hand, Vector3.ZERO, fore, thick * 0.8, thick * 0.6, col)
			_segment(hand, fore, tip, thick * 0.6, thick * 0.4, acc)
			jaw.position = tip
			_segment(jaw, Vector3.ZERO, Vector3(-x * 0.09, 0, -0.07), 0.02, 0.0, acc)
		"jaw":      # shark / moray jaws: upper jaw + biting lower jaw, with teeth
			var tooth := mat(Color(0.97, 0.97, 0.92), r)
			_ellipsoid(hand, Vector3(0, 0.05, -size * 0.6), Vector3(size * 1.0, size * 0.45, size * 1.3), col)
			for i in 5:
				var tx := lerpf(-size * 0.35, size * 0.35, i / 4.0)
				var tz := -size * 1.1 + absf(tx) * 0.6
				_segment(hand, Vector3(tx, 0.0, tz), Vector3(tx, -size * 0.22, tz), size * 0.07, 0.0, tooth)
			jaw.position = Vector3(0, -size * 0.15, -size * 0.1)
			jaw.set_meta("open_axis", "x")
			jaw.set_meta("open_sign", 0.6)
			_ellipsoid(jaw, Vector3(0, 0, -size * 0.55), Vector3(size * 0.9, size * 0.3, size * 1.1), acc)
			for i in 4:
				var tx := lerpf(-size * 0.28, size * 0.28, i / 3.0)
				var tz := -size * 0.95 + absf(tx) * 0.6
				_segment(jaw, Vector3(tx, 0.0, tz), Vector3(tx, size * 0.2, tz), size * 0.06, 0.0, tooth)
		"pom":      # boxer crab: holding a stinging anemone
			_segment(hand, Vector3.ZERO, Vector3(0, 0.02, -size * 0.6), size * 0.1, size * 0.08, col)
			jaw.position = Vector3(0, 0.02, -size * 0.6)
			_ellipsoid(jaw, Vector3(0, 0.02, -size * 0.35), Vector3.ONE * size * 0.7, mat(d.accent, r))
			for i in 14:
				var ang := i * 2.39996
				var dn := Vector3(cos(ang) * 0.8, 0.5 + (i % 3) * 0.25, sin(ang) * 0.8).normalized()
				_segment(jaw, Vector3(0, 0.02, -size * 0.35) + dn * size * 0.3, Vector3(0, 0.02, -size * 0.35) + dn * size * 0.6, size * 0.05, size * 0.02, CritterVisual._glass(d.accent, 0.85, 0.6))
		"bill":     # swordfish bill: one long thrusting spike
			_ellipsoid(hand, Vector3(0, 0, -size * 0.2), Vector3(size * 0.6, size * 0.5, size * 0.8), col)
			_segment(hand, Vector3(0, 0, -size * 0.5), Vector3(x * 0.02, 0, -size * 3.0), size * 0.12, 0.0, acc)
			jaw.position = Vector3(0, -0.03, -size * 0.45)
			_segment(jaw, Vector3.ZERO, Vector3(0, 0, -size * 0.4), size * 0.08, size * 0.02, col)
		"stinger":  # long barbed spike
			_segment(hand, Vector3.ZERO, Vector3(x * 0.02, 0, -size * 2.4), size * 0.14, 0.0, acc)
			for i in 3:
				var p := Vector3(0, 0, -size * (0.8 + i * 0.5))
				for sx in [-1.0, 1.0]:
					_segment(hand, p, p + Vector3(sx * size * 0.22, 0, size * 0.2), 0.012, 0.0, acc)
			jaw.position = Vector3(0, 0.02, -size * 0.3)
			_segment(jaw, Vector3.ZERO, Vector3(0, 0.06, -0.05), 0.02, 0.0, col)
		_:  # pincer
			_ellipsoid(hand, Vector3(0, 0, -size * 0.4), Vector3(size * 0.75, size * 0.55, size * 1.0), col)
			_segment(hand, Vector3(x * size * 0.15, 0, -size * 0.8), Vector3(x * size * 0.04, 0, -size * 1.65), size * 0.17, size * 0.02, acc)
			jaw.position = Vector3(-x * size * 0.15, 0.02, -size * 0.75)
			_segment(jaw, Vector3.ZERO, Vector3(x * size * 0.14, 0, -size * 0.85), size * 0.15, size * 0.02, acc)
	if s.get("hairy", false):   # yeti crab: fuzzy claws
		for i in 16:
			var ang := i * 2.39996
			var p := Vector3(cos(ang) * size * 0.3, sin(ang) * size * 0.25, -size * (0.1 + (i % 8) * 0.12))
			_segment(hand, p, p * 1.6 + Vector3(0, 0.05, 0), 0.01, 0.004, acc)
	hand.add_child(jaw)


static func _build_legs(root: Node3D, d: PartData, s: Dictionary, r: int) -> void:
	var col := mat(d.color, r)
	var acc := mat(d.accent, r)
	var reach: float = s.get("length", 1.0)
	var thick: float = s.get("thick", 0.035)
	var spiky: bool = s.get("spiky", false)
	var paddle: bool = s.get("paddle", false)
	if String(s.get("kind", "")) == "tentacle":   # octopus arms instead of legs
		for i in 8:
			var ang := TAU * i / 8.0 + 0.2
			var dir := Vector3(cos(ang), 0, sin(ang))
			var leg := Node3D.new()
			leg.name = "Leg%d" % i
			leg.set_meta("leg_index", i)
			leg.set_meta("side", signf(dir.x) if absf(dir.x) > 0.01 else 1.0)
			root.add_child(leg)
			var pts := [dir * 0.12, dir * 0.3 + Vector3(0, -0.2, 0), dir * 0.5 * reach + Vector3(0, FOOT_Y + 0.02, 0), dir * 0.78 * reach + Vector3(0, FOOT_Y + 0.12, 0)]
			for j in 3:
				_segment(leg, pts[j], pts[j + 1], thick * (1.6 - j * 0.45), thick * (1.2 - j * 0.4), col if j < 2 else acc)
		return
	for i in 3:
		for x in [-1.0, 1.0]:
			var leg := Node3D.new()
			leg.name = "Leg%d%s" % [i, "L" if x < 0 else "R"]
			leg.set_meta("leg_index", i * 2 + (0 if x < 0 else 1))
			leg.set_meta("side", x)
			var hip := Vector3(x * 0.3, 0.0, -0.18 + i * 0.2)
			leg.position = hip
			root.add_child(leg)
			var spread := (i - 1) * 0.12
			var knee := Vector3(x * 0.26 * reach, 0.17, spread * 0.6)
			var foot := Vector3(x * 0.46 * reach, FOOT_Y - hip.y, spread)
			_segment(leg, Vector3.ZERO, knee, thick, thick * 0.9, col)
			_segment(leg, knee, foot, thick * 0.9, thick * 0.35, col if i % 2 == 0 else acc)
			if spiky:
				_segment(leg, knee, knee + Vector3(x * 0.03, 0.09, 0), thick * 0.6, 0.0, acc)
			if paddle and i == 2:
				_ellipsoid(leg, foot + Vector3(0, 0.05, 0), Vector3(0.14, 0.02, 0.1), acc)
			if s.get("hairy", false):
				for j in 4:
					var p := knee.lerp(foot, 0.15 + j * 0.2)
					_segment(leg, p, p + Vector3(x * 0.06, 0.03, 0.03), 0.01, 0.003, acc)


## Tails grow backwards (+Z) from the tail socket. The swinging part is a node
## named "Swing" (TailBrain and CrabBody animate it).
static func _build_tail(root: Node3D, d: PartData, s: Dictionary, r: int) -> void:
	var col := mat(d.color, r)
	var acc := mat(d.accent, r)
	var swing := Node3D.new()
	swing.name = "Swing"
	root.add_child(swing)
	var w: float = s.get("width", 0.5)
	var length: float = s.get("length", 1.0)
	match String(s.get("kind", "tucked")):
		"fan":     # lobster / shrimp: segments ending in a tail fan
			var z := 0.0
			for i in 4:
				var sz := 1.0 - i * 0.14
				_ellipsoid(swing, Vector3(0, -0.01 - i * 0.03, z + 0.1), Vector3(w * sz, 0.2 * sz, 0.24 * length), col if i % 2 == 0 else acc)
				z += 0.17 * length
			for j in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				var fan := _ellipsoid(swing, Vector3(j * 0.14, -0.1, z + 0.12 - absf(j) * 0.04), Vector3(0.13, 0.025, 0.26), acc)
				fan.rotation.y = -j * 0.5
		"spike":   # horseshoe crab: a long straight spike
			_ellipsoid(swing, Vector3(0, 0, 0.06), Vector3(w * 0.5, 0.14, 0.2), col)
			_segment(swing, Vector3(0, 0, 0.1), Vector3(0, 0.05, 0.1 + 0.9 * length), 0.05, 0.0, acc)
		"whip":    # stingray: a thin whip with a barb
			_segment(swing, Vector3.ZERO, Vector3(0, 0.02, 1.0 * length), 0.04, 0.015, col)
			_segment(swing, Vector3(0, 0.02, 0.7 * length), Vector3(0, 0.08, 1.05 * length), 0.03, 0.0, acc)
		"fin":     # shark / fish tail fin
			_segment(swing, Vector3.ZERO, Vector3(0, 0, 0.4 * length), 0.12, 0.06, col)
			for sy in [-1.0, 1.0]:
				var f := _ellipsoid(swing, Vector3(0, sy * 0.14, 0.52 * length), Vector3(0.04, 0.36, 0.22), acc)
				f.rotation.x = sy * 0.6
		"lure":    # angler: a curling stalk with a glowing bulb
			_segment(swing, Vector3.ZERO, Vector3(0, 0.35, 0.3 * length), 0.03, 0.02, col)
			_segment(swing, Vector3(0, 0.35, 0.3 * length), Vector3(0, 0.55, 0.05), 0.02, 0.015, col)
			_ellipsoid(swing, Vector3(0, 0.56, 0.02), Vector3.ONE * 0.14, CritterVisual._glass(d.accent, 0.95, 2.5))
		"spiny":   # lionfish: a fan of venom spines
			_ellipsoid(swing, Vector3(0, 0, 0.1), Vector3(w * 0.6, 0.16, 0.26), col)
			for i in 7:
				var a := lerpf(-1.0, 1.0, i / 6.0)
				_segment(swing, Vector3(0, 0.02, 0.15), Vector3(sin(a) * 0.35, 0.18 + cos(a) * 0.1, 0.15 + cos(a) * 0.4 * length), 0.02, 0.0, acc if i % 2 else col)
		"zap":     # torpedo ray: a stubby tail with glowing electric nubs
			_segment(swing, Vector3.ZERO, Vector3(0, 0, 0.6 * length), 0.08, 0.04, col)
			for i in 3:
				_ellipsoid(swing, Vector3(0, 0.06, 0.15 + i * 0.17 * length), Vector3.ONE * 0.08, CritterVisual._glass(d.accent, 0.95, 2.0))
		_:         # tucked: crabs keep their tail folded under
			_ellipsoid(swing, Vector3(0, -0.1, -0.05), Vector3(w * 0.7, 0.06, 0.24), col)


# --- Primitives ---------------------------------------------------------------------

static func _ellipsoid(parent: Node3D, pos: Vector3, dims: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	mi.mesh = sphere
	mi.material_override = m
	mi.position = pos
	mi.scale = dims
	parent.add_child(mi)
	return mi


## A tapered cylinder (or cone, when r_b = 0) from a to b.
static func _segment(parent: Node3D, a: Vector3, b: Vector3, r_a: float, r_b: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var dir := b - a
	cyl.height = maxf(dir.length(), 0.001)
	cyl.bottom_radius = r_a
	cyl.top_radius = r_b
	cyl.radial_segments = 8
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = m
	mi.position = (a + b) * 0.5
	var n := dir.normalized()
	if n.dot(Vector3.UP) < -0.999:
		mi.basis = Basis(Vector3.RIGHT, PI)
	elif n.dot(Vector3.UP) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, n))
	parent.add_child(mi)
	return mi


## Shared materials. Rare and better parts get a faint glow in their rarity colour.
static func mat(c: Color, rarity := 0, metallic := 0.0, roughness := 0.6) -> StandardMaterial3D:
	var key := "%s|%d|%.2f|%.2f" % [c.to_html(), rarity, metallic, roughness]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	if rarity >= Rarity.Tier.RARE:
		m.emission_enabled = true
		m.emission = Rarity.color_of(rarity)
		m.emission_energy_multiplier = 0.25 if rarity == Rarity.Tier.RARE else 0.45
	_materials[key] = m
	return m
