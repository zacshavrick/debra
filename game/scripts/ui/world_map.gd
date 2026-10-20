class_name WorldMap
extends Control
## The world map (main scene): an endless, branching depth chart that scrolls
## down. Every depth has 1-3 levels; routes fork and rejoin, and a level unlocks
## when any level leading to it is cleared, so you pick your way down.
## The water darkens with depth; cliffs, kelp, coral, glowing specks and whale
## bones line the chart. HOME = change crab, STASH = your stored parts.

const NODE_SIZE := 60.0
const PANEL_W := 390.0
const SPACING := 140.0
const TOP := 120.0
const LOOKAHEAD := 2
const MOD_COLORS := {&"swarm": Color(1, 0.5, 0.3), &"armored": Color(0.6, 0.7, 0.8), &"venom": Color(0.5, 1, 0.3),
	&"dark": Color(0.3, 0.3, 0.6), &"treasure": Color(1, 0.85, 0.2), &"champions": Color(1, 0.7, 0.2),
	&"riptide": Color(0.3, 0.8, 1), &"frenzy": Color(1, 0.3, 0.3)}

var _buttons: Dictionary = {}   # Vector2i(depth, branch) -> Button
var _selected: LevelData
var _scroll: ScrollContainer
var _chart: Control
var _home: Button
var _title: Label
var _desc: Label
var _rules: Label
var _creatures: Label
var _status: Label
var _dive: Button
var _dev_skip: Button
var _inventory: InventoryUI
var _t := 0.0


func _ready() -> void:
	if GameState.starter == &"":
		GameState.go_to_select()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	resized.connect(_layout)
	_layout()
	_select(GameState.frontier())
	_scroll_to.call_deferred(_selected.depth)


func _max_depth() -> int:
	return GameState.frontier_depth() + LOOKAHEAD


func _key(l: LevelData) -> Vector2i:
	return Vector2i(l.depth, l.branch)


func _build_ui() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_chart = Control.new()
	_chart.mouse_filter = Control.MOUSE_FILTER_PASS
	_chart.draw.connect(_draw_chart)
	_scroll.add_child(_chart)
	for depth in range(1, _max_depth() + 1):
		for branch in GameState.branch_count(depth):
			var l := GameState.level_at(depth, branch)
			var b := Button.new()
			b.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
			b.size = Vector2(NODE_SIZE, NODE_SIZE)
			b.text = str(depth)
			b.add_theme_font_size_override("font_size", 22 if depth < 100 else 16)
			var unlocked := GameState.is_unlocked(l.id)
			var cleared := GameState.is_cleared(l.id)
			var fill := l.ambient.lerp(l.sand_a, 0.3).darkened(0.15)
			if not unlocked:
				fill = fill.lerp(Color(0.2, 0.22, 0.26), 0.75)
			var border := Color(1.0, 0.8, 0.3) if cleared else (Color.WHITE if unlocked else Color(0.45, 0.48, 0.52))
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				var sb := StyleBoxFlat.new()
				sb.bg_color = fill.lightened(0.15) if st == "hover" or st == "focus" else fill
				sb.set_corner_radius_all(int(NODE_SIZE * 0.5))
				sb.set_border_width_all(5 if st == "focus" or cleared else 3)
				sb.border_color = border
				sb.shadow_color = Color(0, 0, 0, 0.4)
				sb.shadow_size = 6
				b.add_theme_stylebox_override(st, sb)
			b.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.6, 0.62, 0.66))
			b.pressed.connect(_select.bind(l))
			_chart.add_child(b)
			var nm := l.display_name.get_slice(": ", 1) if l.display_name.contains(": ") else l.display_name
			var name_l := _label(nm + (" (clear)" if cleared else ""), 14, Color.WHITE if unlocked else Color(0.6, 0.65, 0.7))
			b.add_child(name_l)
			name_l.position = Vector2(NODE_SIZE * 0.5 - 100, NODE_SIZE + 2)
			name_l.size = Vector2(200, 20)
			name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_buttons[Vector2i(depth, branch)] = b
	_home = Button.new()
	_home.text = "HOME"
	_home.custom_minimum_size = Vector2(96, 44)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.8, 0.08, 0.1) if st != "hover" else Color(0.9, 0.2, 0.2)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.95, 0.95, 0.95)
		_home.add_theme_stylebox_override(st, sb)
	_home.pressed.connect(func() -> void: GameState.go_to_select())
	_chart.add_child(_home)
	# Top bar: who you're playing, your stash, your record.
	var top := HBoxContainer.new()
	top.name = "Top"
	top.position = Vector2(20, 14)
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	top.add_child(_label("Playing as %s" % GameState.starter_data().display_name, 22, Color(1, 0.8, 0.6)))
	var change := Button.new()
	change.text = "Change crab"
	change.pressed.connect(func() -> void: GameState.go_to_select())
	top.add_child(change)
	var stash := Button.new()
	stash.text = "STASH / BAG"
	stash.pressed.connect(_open_stash)
	top.add_child(stash)
	top.add_child(_label("Deepest: %d" % GameState.deepest_cleared(), 18, Color(0.75, 0.9, 1.0)))
	# Info panel (fixed on the right)
	var panel := PanelContainer.new()
	panel.name = "Info"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.12, 0.9)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_title = _label("", 25, Color(1, 0.85, 0.55))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(PANEL_W - 36, 0)
	v.add_child(_title)
	_desc = _wrap(16, Color(0.85, 0.92, 1.0))
	v.add_child(_desc)
	_rules = _wrap(15, Color(1, 0.8, 0.55))
	v.add_child(_rules)
	_creatures = _wrap(14, Color(0.75, 0.85, 0.9))
	v.add_child(_creatures)
	_status = _label("", 16, Color(0.6, 1.0, 0.7))
	v.add_child(_status)
	_dive = Button.new()
	_dive.text = "DIVE IN"
	_dive.custom_minimum_size = Vector2(0, 58)
	_dive.add_theme_font_size_override("font_size", 26)
	_dive.pressed.connect(_on_dive)
	v.add_child(_dive)
	if GameState.dev_mode:
		_dev_skip = Button.new()
		_dev_skip.text = "DEV: mark cleared (skip)"
		_dev_skip.pressed.connect(_on_dev_skip)
		v.add_child(_dev_skip)


func _node_pos(depth: int, branch: int, map_w: float) -> Vector2:
	var l := GameState.level_at(depth, branch)
	var jitter := (l.map_pos.x - 0.5) * 70.0 if depth > 1 else 0.0
	var x := 70.0 + GameState.branch_x(depth, branch) * (map_w - 140.0) + jitter
	return Vector2(x, TOP + (depth - 1) * SPACING + 30.0)


func _layout() -> void:
	var map_w := size.x - PANEL_W - 40.0
	_scroll.position = Vector2.ZERO
	_scroll.size = Vector2(map_w + 10.0, size.y)
	_chart.custom_minimum_size = Vector2(map_w, TOP + (_max_depth() - 1) * SPACING + 180.0)
	for k in _buttons:
		var b: Button = _buttons[k]
		b.position = _node_pos(k.x, k.y, map_w) - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
	_home.position = Vector2(map_w * 0.5 - 48.0, 30.0)
	var panel := get_node("Info") as PanelContainer
	panel.position = Vector2(size.x - PANEL_W - 16.0, 64.0)
	panel.size = Vector2(PANEL_W, 0)
	_chart.queue_redraw()


func _scroll_to(depth: int) -> void:
	_scroll.scroll_vertical = int(maxf(TOP + (depth - 1) * SPACING - size.y * 0.4, 0.0))


func _select(l: LevelData) -> void:
	_selected = l
	var unlocked := GameState.is_unlocked(l.id)
	_title.text = l.display_name if l.display_name.begins_with("Depth") else "Depth %d: %s" % [l.depth, l.display_name]
	_desc.text = l.description
	var rules: Array[String] = [l.objective_text()]
	for m in l.modifiers:
		rules.append(String(LevelGenerator.MODIFIERS.get(m, String(m))))
	_rules.text = "\n".join(rules)
	var names: Array[String] = []
	for c in l.enemy_list():
		names.append(c.display_name + (" (lots)" if c == l.featured else ""))
	var boss_line := "Boss: %s" % (l.boss_name if l.boss_name != "" else (l.boss.display_name if l.boss else "-"))
	if not l.boss_traits.is_empty():
		var t: Array[String] = []
		for trait_id in l.boss_traits:
			t.append(String(BossBrain.TRAITS.get(trait_id, String(trait_id))).get_slice(":", 0))
		boss_line += " (%s)" % ", ".join(t)
	_creatures.text = "Creatures: %s\n%s\nParts drop at level %d." % [", ".join(names), boss_line, l.depth]
	if GameState.is_cleared(l.id):
		_status.text = "Cleared. Dive again for more loot."
	elif unlocked:
		_status.text = "Ready."
	else:
		_status.text = "Locked: clear a level that leads here."
	_dive.disabled = not unlocked
	if _dev_skip:
		_dev_skip.disabled = not unlocked or GameState.is_cleared(l.id)
	if unlocked:
		_dive.grab_focus()
	_chart.queue_redraw()


func _on_dive() -> void:
	if _selected and GameState.is_unlocked(_selected.id):
		GameState.play_level(_selected.id)


func _on_dev_skip() -> void:
	if _selected and GameState.is_unlocked(_selected.id):
		GameState.mark_cleared(_selected.id)
		GameState.go_to_map()   # rebuild the chart


func _open_stash() -> void:
	if is_instance_valid(_inventory):
		return
	_inventory = InventoryUI.new()
	_inventory.at_home = true
	_inventory.starter_id = GameState.starter
	add_child(_inventory)


func _process(delta: float) -> void:
	_t += delta
	_chart.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.07))


func _depth_color(depth: float) -> Color:
	var stops := [Color(0.2, 0.62, 0.72), Color(0.05, 0.3, 0.48), Color(0.03, 0.12, 0.25), Color(0.02, 0.04, 0.1), Color(0.01, 0.01, 0.04)]
	var f := clampf(depth / 6.0, 0.0, stops.size() - 1.001)
	var i := int(f)
	var c0: Color = stops[i]
	var c1: Color = stops[i + 1]
	return c0.lerp(c1, f - i)


## A wobbly cliff edge: x offset at height y (same every frame).
func _cliff(y: float, side: float) -> float:
	return maxf(36.0 + 20.0 * sin(y * 0.013 + side * 2.0) + 10.0 * sin(y * 0.041 + side * 5.0) + 6.0 * sin(y * 0.11 + side), 6.0)


func _draw_chart() -> void:
	var w := _chart.size.x
	var h := _chart.size.y
	if w < 50.0 or h < 50.0:		return
	var bands := _max_depth() + 2
	# Water: one gradient band per depth.
	for i in bands:
		var y0 := TOP + (i - 1.5) * SPACING
		var c0 := _depth_color(i - 1)
		var c1 := _depth_color(i)
		_chart.draw_polygon(PackedVector2Array([Vector2(0, maxf(y0, 0)), Vector2(w, maxf(y0, 0)), Vector2(w, y0 + SPACING), Vector2(0, y0 + SPACING)]),
			PackedColorArray([c0, c0, c1, c1]))
	# Surface light rays
	for i in 6:
		var x := w * (0.08 + i * 0.15) + sin(_t * 0.3 + i) * 20.0
		_chart.draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 40, 0), Vector2(x + 140, 650), Vector2(x + 60, 650)]),
			PackedColorArray([Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	# Cliff walls down both sides.
	for side in [0.0, 1.0]:
		var pts := PackedVector2Array()
		var step := 24.0
		var y := 0.0
		while y <= h + step:
			var off := _cliff(y, side)
			pts.append(Vector2(off if side == 0.0 else w - off, y))
			y += step
		pts.append(Vector2(0.0 if side == 0.0 else w, h + step))
		pts.append(Vector2(0.0 if side == 0.0 else w, 0.0))
		_chart.draw_colored_polygon(pts, Color(0.02, 0.05, 0.08, 0.75))
	# Depth decorations along the cliffs.
	for d in range(1, _max_depth() + 2):
		var y := TOP + (d - 1) * SPACING
		for side in [0.0, 1.0]:
			var x := _cliff(y, side)
			x = x + 10.0 if side == 0.0 else w - x - 10.0
			var dir := 1.0 if side == 0.0 else -1.0
			if d <= 2:   # kelp
				for k in 3:
					var pts := PackedVector2Array()
					for j in 9:
						var yy := y + 40.0 - j * 12.0
						pts.append(Vector2(x + dir * (k * 9.0 + sin(_t * 1.2 + j * 0.6 + k) * 6.0), yy))
					_chart.draw_polyline(pts, Color(0.25, 0.6, 0.3, 0.8), 4.0)
			elif d <= 5:   # coral
				for k in 4:
					_chart.draw_circle(Vector2(x + dir * k * 10.0, y + 20.0 + (k % 2) * 8.0), 7.0 - k, Color(0.95, 0.4 + k * 0.1, 0.5, 0.75))
			else:   # glowing specks
				for k in 5:
					var a := 0.4 + 0.4 * sin(_t * 2.0 + d + k)
					_chart.draw_circle(Vector2(x + dir * (k * 9.0), y + k * 11.0), 2.5, Color(0.4, 0.9, 1.0, a))
	# A whale fall far down, if the chart reaches it.
	if _max_depth() >= 8:
		var c := Vector2(w * 0.5, TOP + 7.5 * SPACING)
		for i in 9:
			var x := c.x - 120.0 + i * 30.0
			_chart.draw_arc(Vector2(x, c.y), 26.0, PI, TAU, 10, Color(0.85, 0.82, 0.74, 0.12), 3.0)
		_chart.draw_line(c - Vector2(130, 0), c + Vector2(130, 0), Color(0.85, 0.82, 0.74, 0.12), 4.0)
	# Drifting bubbles
	for i in 40:
		var bx := fmod(i * 97.0, w)
		var by := h - fmod(_t * (12.0 + i % 5 * 6.0) + i * 113.0, h)
		_chart.draw_circle(Vector2(bx + sin(_t + i) * 6.0, by), 2.0 + i % 3, Color(1, 1, 1, 0.1))
	# Where the hand-made sea ends.
	var y_gen := TOP + (GameState.handmade_count() - 0.5) * SPACING + 30.0
	_chart.draw_dashed_line(Vector2(60, y_gen), Vector2(w - 60, y_gen), Color(0.7, 0.6, 1.0, 0.45), 2.0, 10.0)
	_chart.draw_string(get_theme_default_font(), Vector2(64, y_gen - 8), "the endless dive", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.65, 1.0, 0.8))
	# Routes: curved links from each level to the ones below it.
	var c_home := _home.position + _home.size * 0.5
	_curve(c_home, _center(Vector2i(1, 0)), Color(1, 0.95, 0.8, 0.55))
	for k in _buttons:
		var depth: int = k.x
		if depth <= 1:
			continue
		var child := GameState.level_at(depth, k.y)
		for p in GameState.parents(depth, k.y):
			var parent := GameState.level_at(depth - 1, p)
			var col := Color(1, 0.85, 0.4, 0.8) if GameState.is_cleared(parent.id) and GameState.is_cleared(child.id) \
				else (Color(1, 0.95, 0.8, 0.55) if GameState.is_cleared(parent.id) else Color(1, 1, 1, 0.16))
			_curve(_center(Vector2i(depth - 1, p)), _center(k), col)
	# Modifier dots around each node, selection ring.
	for k in _buttons:
		var l := GameState.level_at(k.x, k.y)
		var c := _center(k)
		for i in l.modifiers.size():
			var a := -PI * 0.75 + i * 0.45
			_chart.draw_circle(c + Vector2(cos(a), sin(a)) * (NODE_SIZE * 0.5 + 9.0), 5.0, MOD_COLORS.get(l.modifiers[i], Color.WHITE))
	if _selected and _buttons.has(_key(_selected)):
		_chart.draw_arc(_center(_key(_selected)), NODE_SIZE * 0.5 + 9.0 + sin(_t * 4.0) * 2.0, 0, TAU, 40, Color(1, 0.9, 0.5), 3.0)


func _center(k: Vector2i) -> Vector2:
	var b: Button = _buttons.get(k)
	return b.position + b.size * 0.5 if b else Vector2.ZERO


func _curve(a: Vector2, b: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	var c1 := a + Vector2(0, (b.y - a.y) * 0.55)
	var c2 := b - Vector2(0, (b.y - a.y) * 0.55)
	for i in 17:
		var t := i / 16.0
		var u := 1.0 - t
		pts.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)
	_chart.draw_polyline(pts, col, 4.0, true)


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(fs: int, col: Color) -> Label:
	var l := _label("", fs, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_W - 36, 0)
	return l
