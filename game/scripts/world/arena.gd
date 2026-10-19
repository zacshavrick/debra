class_name Arena
extends Node3D
## Test arena (main scene): a round patch of seafloor with Debra's home
## (a Coke can), rocks, kelp and drifting bubbles. Keeps a few creatures
## alive by respawning them away from the player.
##
## Dev keys (any build, prototype only): F1 drop a random part, F2 spawn a
## creature, F3 heal.

const RADIUS := 22.0
const HOME_POS := Vector3(0, 0, -15.5)
const PLAYER_START := Vector3(0, 0, -12.5)
const RESPAWN_DELAY := 2.5

@export var player_creature: StringName = &"debra"

var rng := RandomNumberGenerator.new()
var player: PlayerCrab
var camera: FollowCamera
var hud: HUD
var max_enemies := 5
## Tests turn this off to control spawns themselves.
var auto_spawn := true

var _spawn_timer := 1.0
var _creatures: Array[CreatureData] = []


func _ready() -> void:
	rng.randomize()
	max_enemies = 4 if Platform.is_low() else 5
	for c in PartCatalog.all_creatures():
		if not c.playable:
			_creatures.append(c)
	_build_environment()
	_build_floor()
	_build_home()
	_build_decor()
	player = PlayerCrab.new()
	player.creature = PartCatalog.creature(player_creature)
	player.home_position = PLAYER_START
	add_child(player)
	player.global_position = PLAYER_START
	camera = FollowCamera.new()
	camera.target = player
	add_child(camera)
	camera.make_current()
	player.camera = camera
	hud = HUD.new()
	hud.player = player
	add_child(hud)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 10
	add_child(touch_layer)
	touch_layer.add_child(TouchControls.new())
	PlayerInput.debug_pressed.connect(_on_debug)
	for i in 3:
		spawn_enemy(_pick_creature(), _spawn_point())
	hud.toast("Kill things. Wear them.", Color(1, 0.8, 0.6), 3.5)


func _physics_process(delta: float) -> void:
	if not auto_spawn:
		return
	if get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return not (e as Crab).is_dead()).size() < max_enemies:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = RESPAWN_DELAY
			spawn_enemy(_pick_creature(), _spawn_point())


func spawn_enemy(creature: CreatureData, pos: Vector3) -> EnemyCrab:
	var e := EnemyCrab.new()
	e.creature = creature
	e.rng = rng
	e.position = pos
	add_child(e)
	return e


func _pick_creature() -> CreatureData:
	var w := PackedFloat32Array()
	for c in _creatures:
		w.append(c.spawn_weight)
	return _creatures[rng.rand_weighted(w)]


func _spawn_point() -> Vector3:
	var p := Vector3.ZERO
	for i in 20:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (RADIUS - 4.0)
		p = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var far_from_player := player == null or p.distance_to(player.global_position) > 9.0
		if far_from_player and p.distance_to(HOME_POS) > 7.0:
			break
	return p


func _on_debug(key: int) -> void:
	match key:
		KEY_F1:
			var parts := PartCatalog.all_parts()
			var part := PartInstance.new(parts[rng.randi() % parts.size()], Rarity.roll(rng, 1.0))
			PartPickup.spawn(self, player.global_position + player.facing * 1.2, part)
		KEY_F2:
			spawn_enemy(_pick_creature(), player.global_position + player.facing * 6.0)
		KEY_F3:
			player.health.fill()


# --- World building ----------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.16, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.5, 0.65)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.24, 0.34)
	env.fog_density = 0.03
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 25, 0)
	sun.light_color = Color(0.72, 0.9, 1.0)
	sun.light_energy = 0.95
	sun.shadow_enabled = not Platform.is_low()
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 2, 120)
	cs.shape = box
	cs.position.y = -1.0
	body.add_child(cs)
	add_child(body)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	mi.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/seafloor.gdshader")
	mi.material_override = m
	add_child(mi)
	# Arena wall: an invisible ring of boxes behind the rock ring.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	add_child(wall)
	for i in 32:
		var a := TAU * i / 32.0
		var w := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(5.0, 4.0, 1.0)
		w.shape = b
		w.position = Vector3(cos(a), 0, sin(a)) * (RADIUS + 0.5) + Vector3(0, 2, 0)
		w.rotation.y = -a + PI * 0.5
		wall.add_child(w)


func _build_home() -> void:
	# Debra's home: a Coke can on its side at the north edge (behind Debra as the camera sees it).
	var home := Node3D.new()
	home.name = "Home"
	home.position = HOME_POS
	home.rotation_degrees.y = 180   # open end faces the arena centre
	add_child(home)
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
	var label := Label3D.new()
	label.text = "HOME"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 12
	label.pixel_size = 0.01
	label.modulate = Color(1, 0.9, 0.7, 0.8)
	label.position.y = 2.9
	home.add_child(label)
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


func _build_decor() -> void:
	var low := Platform.is_low()
	var d := RandomNumberGenerator.new()
	d.seed = 7   # same layout every run
	# Rock ring at the edge, plus a few boulders inside (with collision).
	for i in 40:
		var a := TAU * i / 40.0 + d.randf_range(-0.05, 0.05)
		var r := RADIUS + d.randf_range(0.5, 2.5)
		_rock(Vector3(cos(a) * r, 0, sin(a) * r), d.randf_range(1.2, 2.6), d, false)
	for p in [Vector3(-8, 0, -4), Vector3(9, 0, 2), Vector3(-3, 0, -13), Vector3(12, 0, -10), Vector3(-13, 0, 6)]:
		_rock(p, d.randf_range(0.9, 1.4), d, true)
	# Kelp
	var kelp_shader: Shader = load("res://shaders/kelp.gdshader")
	var count := 22 if low else 45
	for i in count:
		var a := d.randf() * TAU
		var r := d.randf_range(RADIUS - 3.0, RADIUS + 3.0) if i % 3 != 0 else d.randf_range(6.0, RADIUS - 4.0)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		if base.distance_to(HOME_POS) < 4.0 or base.distance_to(PLAYER_START) < 3.0:
			continue
		var h := d.randf_range(2.5, 6.0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, h, 0.05)
		bm.subdivide_height = 6
		mi.mesh = bm
		var m := ShaderMaterial.new()
		m.shader = kelp_shader
		m.set_shader_parameter("tint", Color(0.18, 0.5, 0.22).lerp(Color(0.45, 0.55, 0.15), d.randf()))
		m.set_shader_parameter("phase", d.randf() * TAU)
		m.set_shader_parameter("height", h)
		mi.material_override = m
		mi.position = base + Vector3(0, h * 0.5, 0)
		mi.rotation.y = d.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# Drifting bubbles
	var bubbles := CPUParticles3D.new()
	bubbles.amount = 25 if low else 60
	bubbles.lifetime = 7.0
	bubbles.preprocess = 7.0
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(RADIUS, 0.1, RADIUS)
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
	add_child(bubbles)


func _rock(pos: Vector3, s: float, d: RandomNumberGenerator, solid: bool) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = PartVisual.mat(Color(0.32, 0.34, 0.36).lerp(Color(0.4, 0.36, 0.3), d.randf()), 0, 0.0, 0.9)
	mi.scale = Vector3(s * d.randf_range(1.0, 1.6), s * d.randf_range(0.6, 1.0), s * d.randf_range(1.0, 1.5))
	mi.position = pos + Vector3(0, s * 0.15, 0)
	mi.rotation.y = d.randf() * TAU
	add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = s * 0.6
		cyl.height = 2.0
		cs.shape = cyl
		body.position = pos + Vector3(0, 1, 0)
		body.add_child(cs)
		add_child(body)
