class_name FollowCamera
extends Camera3D
## Fixed-angle ARPG camera (no rotation), so "up on the stick" is always
## "up the screen" = world -Z. Closer on phones. Shakes on big hits
## (FX.shake calls the "follow_camera" group).

@export var pitch_deg := 56.0
@export var distance := 10.5

var target: Node3D
var _shake := 0.0


func _ready() -> void:
	add_to_group("follow_camera")
	fov = 45.0
	if Platform.is_mobile:
		distance *= 0.85
	rotation_degrees = Vector3(-pitch_deg, 0, 0)
	snap()


func _offset() -> Vector3:
	var p := deg_to_rad(pitch_deg)
	return Vector3(0, sin(p), cos(p)) * distance


func snap() -> void:
	if target:
		global_position = target.global_position + _offset()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position + _offset(), minf(delta * 6.0, 1.0))
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 1.8, 0.0)
		h_offset = randf_range(-1.0, 1.0) * _shake * 0.35
		v_offset = randf_range(-1.0, 1.0) * _shake * 0.35
	else:
		h_offset = 0.0
		v_offset = 0.0
