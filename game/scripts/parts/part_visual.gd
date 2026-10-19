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
	if s.get("pearl", false):
		_ellipsoid(root, Vector3(0, 0.05 + h * 0.55, 0), Vector3.ONE * 0.16, mat(Color(1, 0.97, 0.95), r, 0.3, 0.15))


static func _build_claw(root: Node3D, d: PartData, s: Dictionary, r: int, side: int) -> void:
	var col := mat(d.color, r)
	var acc := mat(d.accent, r)
	var kind := String(s.get("kind", "pincer"))
	var k: float = s.get("arm", 0.32) / 0.32
	var size: float = s.get("size", 0.26)
	var thick := 0.06 if kind == "crusher" else 0.045
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
		_:  # pincer
			_ellipsoid(hand, Vector3(0, 0, -size * 0.4), Vector3(size * 0.75, size * 0.55, size * 1.0), col)
			_segment(hand, Vector3(x * size * 0.15, 0, -size * 0.8), Vector3(x * size * 0.04, 0, -size * 1.65), size * 0.17, size * 0.02, acc)
			jaw.position = Vector3(-x * size * 0.15, 0.02, -size * 0.75)
			_segment(jaw, Vector3.ZERO, Vector3(x * size * 0.14, 0, -size * 0.85), size * 0.15, size * 0.02, acc)
	hand.add_child(jaw)


static func _build_legs(root: Node3D, d: PartData, s: Dictionary, r: int) -> void:
	var col := mat(d.color, r)
	var acc := mat(d.accent, r)
	var reach: float = s.get("length", 1.0)
	var thick: float = s.get("thick", 0.035)
	var spiky: bool = s.get("spiky", false)
	var paddle: bool = s.get("paddle", false)
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
