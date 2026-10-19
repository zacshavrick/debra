class_name BubbleShot
extends Node3D
## Snapper-claw projectile: a cavitation bubble that pops on the first enemy.

var team := 0
var damage := 5.0
var knock := 2.0
var velocity := Vector3.ZERO
var max_distance := 9.0
var source: Crab

var _travelled := 0.0
static var _mesh: SphereMesh
static var _mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("projectiles")
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.18
		_mesh.height = 0.36
		_mat = StandardMaterial3D.new()
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = Color(0.7, 0.95, 1.0, 0.55)
		_mat.emission_enabled = true
		_mat.emission = Color(0.5, 0.9, 1.0)
		_mat.emission_energy_multiplier = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _mat
	add_child(mi)


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	global_position += step
	_travelled += step.length()
	scale = Vector3.ONE * (1.0 + sin(_travelled * 3.0) * 0.12)
	for n in get_tree().get_nodes_in_group("crabs"):
		var c := n as Crab
		if c == null or c.team == team or c.is_dead():
			continue
		var to := c.global_position - global_position
		to.y = 0.0
		if to.length() < c.radius() + 0.2:
			c.receive_hit(damage, global_position - velocity.normalized(), knock, source)
			_pop()
			return
	if _travelled >= max_distance:
		_pop()


func _pop() -> void:
	FX.ring(get_parent(), global_position, 0.6, Color(0.7, 0.95, 1.0))
	queue_free()
