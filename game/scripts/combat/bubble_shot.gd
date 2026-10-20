class_name BubbleShot
extends Node3D
## A projectile: snapper bubbles, critter spit, urchin spines.
## Pops on the first enemy it touches or after max_distance.

var team := 0
var damage := 5.0
var knock := 2.0
var velocity := Vector3.ZERO
var max_distance := 9.0
var source: Creature
var color := Color(0.7, 0.95, 1.0)
var radius := 0.18
var poison_dps := 0.0
## > 1 = an elongated spine pointing along its flight.
var stretch := 1.0

var _mi: MeshInstance3D


var _travelled := 0.0
static var _mesh: SphereMesh
static var _mats: Dictionary = {}


func _ready() -> void:
	add_to_group("projectiles")
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.5
		_mesh.height = 1.0
		_mesh.radial_segments = 10
		_mesh.rings = 5
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(color, 0.6)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.6
		_mats[key] = m
	_mi = MeshInstance3D.new()
	var mi := _mi
	mi.mesh = _mesh
	mi.material_override = _mats[key]
	mi.scale = Vector3(1, 1, stretch) * radius * 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if not Platform.is_low():   # bubbly trail left in the water
		var trail := CPUParticles3D.new()
		trail.local_coords = false
		trail.amount = 10
		trail.lifetime = 0.35
		trail.direction = Vector3.UP
		trail.spread = 180.0
		trail.initial_velocity_min = 0.1
		trail.initial_velocity_max = 0.4
		trail.gravity = Vector3.ZERO
		trail.scale_amount_min = 0.3
		trail.scale_amount_max = 0.7
		var tm := SphereMesh.new()
		tm.radius = radius * 0.5
		tm.height = radius
		tm.radial_segments = 6
		tm.rings = 3
		tm.material = _mats[key]
		trail.mesh = tm
		add_child(trail)


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	global_position += step
	_travelled += step.length()
	_mi.scale = Vector3(1, 1, stretch) * radius * 2.0
	if stretch > 1.0:
		if velocity.length() > 0.01:
			look_at(global_position + velocity, Vector3.UP)
	else:
		scale = Vector3.ONE * (1.0 + sin(_travelled * 3.0) * 0.12)
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.team == team or c.is_dead():
			continue
		var to := c.global_position - global_position
		to.y = 0.0
		if to.length() < c.radius() + radius and c.reflecting:   # bounced off a deflector
			velocity = -velocity
			team = c.team
			source = c
			_travelled = 0.0
			FX.ring(get_parent(), global_position, 0.5, Color(0.6, 0.9, 1.0))
			return
		if to.length() < c.radius() + radius:
			c.receive_hit(damage, global_position - velocity.normalized(), knock, source if is_instance_valid(source) else null)
			if poison_dps > 0.0:
				c.poison(poison_dps, 3.0)
			_pop()
			return
	if _travelled >= max_distance:
		_pop()


func _pop() -> void:
	FX.ring(get_parent(), global_position, 0.6, color)
	queue_free()


## Fires a shot from `from` along `dir` (helper for critters).
static func fire(owner_: Creature, from: Vector3, dir: Vector3, dmg: float, speed: float, dist: float, col: Color, r := 0.18) -> BubbleShot:
	var s := BubbleShot.new()
	s.team = owner_.team
	s.damage = dmg
	s.velocity = dir.normalized() * speed
	s.max_distance = dist
	s.source = owner_
	s.color = col
	s.radius = r
	owner_.get_parent().add_child(s)
	s.global_position = from
	return s
