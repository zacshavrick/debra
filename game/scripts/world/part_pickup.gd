class_name PartPickup
extends Node3D
## A dropped part lying on the seafloor: the part's real model, slowly turning,
## with a light beam in its rarity colour. The player equips it from here.

var part: PartInstance

var _holder: Node3D
var _label: Label3D
var _age := 0.0
var _consumed := false
## Freshly dropped parts can't be picked for a moment (no instant re-pickup of
## the part you just took off).
var _pick_delay := 0.0


static func spawn(parent: Node, pos: Vector3, p: PartInstance, pop := true) -> PartPickup:
	var pk := PartPickup.new()
	pk.part = p
	pk._pick_delay = 0.0 if pop else 0.6
	parent.add_child(pk)
	pk.global_position = Vector3(pos.x, 0.0, pos.z)
	if pop:
		pk._holder.position.y = 1.2
	return pk


func _ready() -> void:
	add_to_group("pickups")
	var col := Rarity.color_of(part.rarity)
	_holder = Node3D.new()
	add_child(_holder)
	var vis := PartVisual.build(part, 1)
	vis.position.y = 0.5 if part.data.slot == PartData.Slot.LEGS else 0.3
	if part.data.slot == PartData.Slot.CLAW:
		vis.position.x = -0.2
	_holder.add_child(vis)
	# Beam + ground glow
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.12
	cyl.height = 1.6 + part.rarity * 0.6
	beam.mesh = cyl
	beam.position.y = cyl.height * 0.5
	beam.material_override = _glow_mat(col, 0.25)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.55
	dm.bottom_radius = 0.55
	dm.height = 0.01
	disc.mesh = dm
	disc.position.y = 0.02
	disc.material_override = _glow_mat(col, 0.3)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	_label = Label3D.new()
	_label.text = part.full_name()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.006
	_label.modulate = col
	_label.position.y = 1.25
	add_child(_label)
	set_focused(false)


func can_pick() -> bool:
	return not _consumed and _pick_delay <= 0.0


func set_focused(on: bool) -> void:
	if _label:
		_label.scale = Vector3.ONE * (1.3 if on else 0.8)
		_label.modulate.a = 1.0 if on else 0.75


## Called when the part is equipped: shrink away.
func consume() -> void:
	_consumed = true
	remove_from_group("pickups")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.15)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_age += delta
	_pick_delay -= delta
	_holder.rotation.y += delta * 1.4
	var rest := 0.15 + sin(_age * 2.5) * 0.06
	_holder.position.y = move_toward(_holder.position.y, rest, delta * 3.0) if _holder.position.y > rest + 0.1 else rest


static func _glow_mat(col: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col, alpha)
	return m
