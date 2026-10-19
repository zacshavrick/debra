class_name Minimap
extends Control
## Round minimap of the arena: home (red can), you (white arrow), creatures
## (red dots; the boss is big and purple), dropped parts (rarity colours).
## North (-Z) is up, like the camera.

const RADIUS := 66.0

var level: Level


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0 + 4.0, RADIUS * 2.0 + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _to_map(p: Vector3) -> Vector2:
	var s := RADIUS / maxf(level.level.radius, 1.0)
	var v := Vector2(p.x, p.z) * s
	if v.length() > RADIUS - 3.0:
		v = v.normalized() * (RADIUS - 3.0)
	return size * 0.5 + v


func _draw() -> void:
	if level == null or level.level == null:
		return
	var c := size * 0.5
	draw_circle(c, RADIUS, Color(0.02, 0.08, 0.14, 0.7))
	draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.0)
	var home := _to_map(level.home_position())
	draw_rect(Rect2(home - Vector2(5, 3), Vector2(10, 6)), Color(0.85, 0.1, 0.12))
	for n in get_tree().get_nodes_in_group("pickups"):
		var pk := n as PartPickup
		if pk:
			var q := _to_map(pk.global_position)
			draw_rect(Rect2(q - Vector2(2.5, 2.5), Vector2(5, 5)), Rarity.color_of(pk.part.rarity))
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Creature
		if e == null or e.is_dead():
			continue
		if e.is_boss:
			draw_circle(_to_map(e.global_position), 6.0, Color(0.85, 0.3, 0.9))
		else:
			draw_circle(_to_map(e.global_position), 3.0, Color(1, 0.35, 0.3))
	var pl := level.player
	if is_instance_valid(pl):
		var p := _to_map(pl.global_position)
		var f := Vector2(pl.facing.x, pl.facing.z).normalized()
		var side := Vector2(-f.y, f.x)
		draw_colored_polygon(PackedVector2Array([p + f * 7.0, p - f * 4.0 + side * 4.5, p - f * 4.0 - side * 4.5]), Color.WHITE)
