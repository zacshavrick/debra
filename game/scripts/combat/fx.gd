class_name FX
extends RefCounted
## Cheap one-shot effects (all Compatibility-renderer safe).


## Floating damage number.
static func number(parent: Node, pos: Vector3, value: float, col: Color) -> void:
	if parent == null:
		return
	var l := Label3D.new()
	l.text = str(roundi(value))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 56
	l.outline_size = 12
	l.pixel_size = 0.008
	l.modulate = col
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0, 0)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position:y", pos.y + 0.9, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)


## Flat fading arc on the ground showing a melee swing.
static func slash(parent: Node, pos: Vector3, dir: Vector3, reach: float, arc_deg: float, col: Color) -> void:
	if parent == null:
		return
	var im := ImmediateMesh.new()
	var half := deg_to_rad(arc_deg) * 0.5
	var base := atan2(dir.x, dir.z)
	var steps := 12
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in steps + 1:
		var a := base - half + 2.0 * half * i / steps
		var d := Vector3(sin(a), 0, cos(a))
		im.surface_add_vertex(d * reach * 0.45)
		im.surface_add_vertex(d * reach)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col, 0.55)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(mi.queue_free)


## Expanding, fading ring (impacts, pops).
static func ring(parent: Node, pos: Vector3, radius: float, col: Color) -> void:
	if parent == null:
		return
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 6
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(col, 0.7)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 0.3
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.25)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(mi.queue_free)
