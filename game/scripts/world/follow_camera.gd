class_name FollowCamera
extends Camera3D
## Fixed-angle ARPG camera (no rotation), so "up on the stick" is always
## "up the screen" = world -Z. Closer on phones.

@export var pitch_deg := 56.0
@export var distance := 10.5

var target: Node3D


func _ready() -> void:
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


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position + _offset(), minf(delta * 6.0, 1.0))
