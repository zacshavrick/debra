class_name Portal
extends Node3D
## Opens where the boss died. Walk into it to go back to the map, whenever
## you like: no prompt, no rush, finish looting first.

signal entered

const RADIUS := 1.1

var _t := 0.0
var _ring: MeshInstance3D
var _swirl: MeshInstance3D
var _armed := 1.0   ## seconds before it accepts you (so it can't grab you mid-fight)
var _used := false


func _ready() -> void:
	add_to_group("portals")
	var glow := CritterVisual._glass(Color(0.45, 0.85, 1.0), 0.9, 2.2)
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.1
	t.rings = 32
	t.ring_segments = 8
	_ring.mesh = t
	_ring.material_override = glow
	_ring.rotation_degrees.x = 90
	_ring.position.y = 1.3
	add_child(_ring)
	_swirl = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.92
	c.bottom_radius = 0.92
	c.height = 0.02
	c.radial_segments = 32
	_swirl.mesh = c
	_swirl.material_override = CritterVisual._glass(Color(0.3, 0.55, 1.0), 0.45, 1.2)
	_swirl.rotation_degrees.x = 90
	_swirl.position.y = 1.3
	add_child(_swirl)
	var pad := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 1.3
	pc.bottom_radius = 1.3
	pc.height = 0.02
	pad.mesh = pc
	pad.material_override = CritterVisual._glass(Color(0.45, 0.85, 1.0), 0.3, 1.0)
	pad.position.y = 0.02
	add_child(pad)
	var sparks := CPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 1.2
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 1.0
	sparks.direction = Vector3.UP
	sparks.gravity = Vector3(0, 1.0, 0)
	sparks.initial_velocity_min = 0.2
	sparks.initial_velocity_max = 0.6
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = glow
	sparks.mesh = sm
	sparks.position.y = 1.3
	add_child(sparks)
	var l := Label3D.new()
	l.text = "Portal: back to the map"
	l.font_size = 40
	l.outline_size = 10
	l.pixel_size = 0.007
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.7, 0.95, 1.0)
	l.position.y = 2.8
	add_child(l)
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_armed -= delta
	_swirl.rotation.y += delta * 2.5
	_ring.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.04)
	if _used or _armed > 0.0:
		return
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Creature
		if p and not p.is_dead() and Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length() < RADIUS:
			_used = true
			FX.ring(get_parent(), global_position + Vector3(0, 1.3, 0), 3.0, Color(0.5, 0.9, 1.0), 0.4)
			entered.emit()
