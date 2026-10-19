class_name CrabBody
extends Node3D
## The ONE shared crustacean rig. Every playable crab and every crustacean
## enemy uses it, so any crustacean part fits any crab.
##
##   CrabBody (origin on the ground, forward = -Z)
##     Torso (y = TORSO_Y; bobs)
##       Core            dark body mass, always present under the shell
##       Socket_Head / Socket_Shell / Socket_ClawL / Socket_ClawR / Socket_Legs
##
## Parts scale to the socket, not the other way round: a part is built in
## socket space at Debra's size, and bigger/smaller creatures scale the
## whole CrabBody. Also plays the placeholder procedural animation.

const TORSO_Y := 0.45
const SOCKET_NAMES := ["Socket_Head", "Socket_Shell", "Socket_ClawL", "Socket_ClawR", "Socket_Legs", "Socket_Tail"]
const SOCKET_POS := [
	Vector3(0, 0.08, -0.42),
	Vector3(0, 0, 0),
	Vector3(-0.42, -0.02, -0.28),
	Vector3(0.42, -0.02, -0.28),
	Vector3(0, 0.02, 0.05),
	Vector3(0, -0.02, 0.36),
]

## 0..1, how fast the crab is walking (set by Crab each frame).
var walk_amount := 0.0
## Permanent overlay (champion / dark-water glow); hit flashes return to it.
var base_overlay: Material
var torso: Node3D
var sockets: Array[Marker3D] = []

var _t := 0.0
var _dead := false
var _flash_left := 0.0
static var _flash_mat: StandardMaterial3D


func _init() -> void:
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position.y = TORSO_Y
	add_child(torso)
	var core := MeshInstance3D.new()
	core.name = "Core"
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	core.mesh = m
	core.scale = Vector3(0.78, 0.3, 0.7)
	core.material_override = PartVisual.mat(Color(0.18, 0.12, 0.12))
	torso.add_child(core)
	for i in SOCKET_NAMES.size():
		var s := Marker3D.new()
		s.name = SOCKET_NAMES[i]
		s.position = SOCKET_POS[i]
		torso.add_child(s)
		sockets.append(s)


func get_socket(socket: int) -> Marker3D:
	return sockets[socket]


## Replaces the look in one socket. null leaves the socket empty.
func show_part(socket: int, part: PartInstance) -> void:
	var s := sockets[socket]
	for c in s.get_children():
		s.remove_child(c)
		c.queue_free()
	if part == null:
		return
	var v := PartVisual.build(part, -1 if socket == Equipment.Socket.CLAW_L else 1)
	s.add_child(v)
	if base_overlay:
		_set_overlay(v, base_overlay)
	if is_inside_tree():
		v.scale = Vector3.ONE * 1.35
		create_tween().tween_property(v, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Claw strike: lunge the socket and snap the jaw. `windup` = time before the hit lands.
func play_attack(socket: int, style: StringName, windup: float) -> void:
	var s := sockets[socket]
	var rest: Vector3 = SOCKET_POS[socket]
	var jaw := s.find_child("Jaw", true, false) as Node3D
	var lunge := 0.32 if style == &"crush" else (-0.1 if style == &"snap" else 0.2)
	var tw := create_tween()
	tw.tween_property(s, "position", rest + Vector3(0, 0.05, 0.08), maxf(windup, 0.04))
	tw.tween_property(s, "position", rest + Vector3(0, 0, -lunge), 0.06)
	tw.tween_property(s, "position", rest, 0.18)
	if jaw:
		var sign_: float = jaw.get_meta("open_sign", 1.0)
		var prop := "rotation:x" if jaw.get_meta("open_axis", "y") == "x" else "rotation:y"
		var jt := create_tween()
		jt.tween_property(jaw, prop, sign_ * 0.7, maxf(windup, 0.04))
		jt.tween_property(jaw, prop, 0.0, 0.05)


## Brief white flash when hit.
func flash() -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.albedo_color = Color(1, 1, 1, 0.65)
	_set_overlay(self, _flash_mat)
	_flash_left = 0.08


func play_death() -> void:
	_dead = true
	var tw := create_tween().set_parallel()
	tw.tween_property(torso, "rotation:z", PI, 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_property(torso, "position:y", TORSO_Y + 0.25, 0.35)


func reset_pose() -> void:
	_dead = false
	torso.rotation = Vector3.ZERO
	torso.position.y = TORSO_Y


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_overlay(self, base_overlay)
	if _dead:
		return
	_t += delta
	var walk := clampf(walk_amount, 0.0, 1.0)
	torso.position.y = TORSO_Y + sin(_t * 2.0) * 0.012 + absf(sin(_t * 14.0)) * 0.025 * walk
	var leg_socket := sockets[Equipment.Socket.LEGS]
	var legs: Node = leg_socket.get_child(0) if leg_socket.get_child_count() > 0 else null
	if legs:
		for leg in legs.get_children():
			if not leg.has_meta("leg_index"):
				continue
			var i: int = leg.get_meta("leg_index")
			var phase := _t * 14.0 + (PI if (i % 2 == 0) != ((i / 2) % 2 == 0) else 0.0)
			var leg3 := leg as Node3D
			leg3.rotation.y = sin(phase) * 0.35 * walk
			leg3.rotation.z = maxf(0.0, cos(phase)) * 0.25 * walk * float(leg.get_meta("side", 1.0))
	for side in [Equipment.Socket.CLAW_L, Equipment.Socket.CLAW_R]:
		var c := sockets[side]
		c.rotation.x = sin(_t * 1.7 + side) * 0.06


func _set_overlay(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = m
	for c in n.get_children():
		_set_overlay(c, m)
