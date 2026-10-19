class_name WorldMap
extends Control
## The world map (main scene): an endless depth chart that scrolls down.
## Depths 1-5 are hand-made; everything below is generated and goes on
## forever. You can see two locked depths past your frontier. The water gets
## darker the deeper you go. A path runs from home (the Coke can) down
## through every depth. Pick one and DIVE.

const NODE_SIZE := 64.0
const PANEL_W := 390.0
const SPACING := 130.0
const TOP := 110.0
const LOOKAHEAD := 2

var _buttons: Dictionary = {}   # depth -> Button
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
		var l := GameState.level_at_depth(depth)
		var b := Button.new()
		b.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		b.size = Vector2(NODE_SIZE, NODE_SIZE)
		b.text = str(depth)
		b.add_theme_font_size_override("font_size", 24 if depth < 100 else 18)
		var unlocked := GameState.is_unlocked(l.id)
		var cleared := GameState.is_cleared(l.id)
		var col := Color(0.95, 0.7, 0.3) if cleared else (Color(0.2, 0.55, 0.8) if unlocked else Color(0.3, 0.33, 0.38))
		if depth > GameState.handmade_count() and not cleared and unlocked:
			col = Color(0.45, 0.35, 0.85)   # generated depths glow purple
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col.lightened(0.15) if st == "hover" or st == "focus" else col
			sb.set_corner_radius_all(int(NODE_SIZE * 0.5))
			sb.set_border_width_all(4 if st == "focus" else 3)
			sb.border_color = Color.WHITE if st == "focus" else Color(1, 1, 1, 0.55)
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_select.bind(l))
		_chart.add_child(b)
		var name_l := _label(l.display_name.get_slice(": ", 1) if depth > GameState.handmade_count() else l.display_name, 16,
			Color.WHITE if unlocked else Color(0.6, 0.65, 0.7))
		b.add_child(name_l)
		name_l.position = Vector2(NODE_SIZE * 0.5 - 110, NODE_SIZE + 2)
		name_l.size = Vector2(220, 22)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_buttons[depth] = b
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
	# Top bar: who you're playing and your record.
	var top := HBoxContainer.new()
	top.name = "Top"
	top.position = Vector2(20, 14)
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	top.add_child(_label("Playing as %s" % GameState.starter_data().display_name, 22, Color(1, 0.8, 0.6)))
	var change := Button.new()
	change.text = "Change crab"
	change.pressed.connect(func() -> void: GameState.go_to_select())
	top.add_child(change)
	top.add_child(_label("Deepest cleared: %d" % GameState.deepest_cleared(), 18, Color(0.75, 0.9, 1.0)))
	# Info panel (fixed on the right)
	var panel := PanelContainer.new()
	panel.name = "Info"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.12, 0.88)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_title = _label("", 26, Color(1, 0.85, 0.55))
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


func _layout() -> void:
	var map_w := size.x - PANEL_W - 40.0
	_scroll.position = Vector2.ZERO
	_scroll.size = Vector2(map_w + 10.0, size.y)
	_chart.custom_minimum_size = Vector2(map_w, TOP + (_max_depth() - 1) * SPACING + 160.0)
	for depth in _buttons:
		var l := GameState.level_at_depth(depth)
		var b: Button = _buttons[depth]
		b.position = Vector2(60.0 + l.map_pos.x * (map_w - 120.0), TOP + (depth - 1) * SPACING) - Vector2(NODE_SIZE, NODE_SIZE) * 0.5 + Vector2(0, 30)
	_home.position = Vector2(0.06 * map_w, 50.0)
	var panel := get_node("Info") as PanelContainer
	panel.position = Vector2(size.x - PANEL_W - 16.0, 64.0)
	panel.size = Vector2(PANEL_W, 0)
	_chart.queue_redraw()


func _scroll_to(depth: int) -> void:
	var y := TOP + (depth - 1) * SPACING - size.y * 0.4
	_scroll.scroll_vertical = int(maxf(y, 0.0))


func _select(l: LevelData) -> void:
	_selected = l
	var unlocked := GameState.is_unlocked(l.id)
	_title.text = l.display_name if l.depth > GameState.handmade_count() else "Depth %d: %s" % [l.depth, l.display_name]
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
		_status.text = "Locked: clear depth %d first." % (l.depth - 1)
	_dive.disabled = not unlocked
	if unlocked:
		_dive.grab_focus()
	_chart.queue_redraw()


func _on_dive() -> void:
	if _selected and GameState.is_unlocked(_selected.id):
		GameState.play_level(_selected.id)


func _process(delta: float) -> void:
	_t += delta
	_chart.queue_redraw()
	queue_redraw()


## The fixed backdrop behind the scrolling chart.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.07))


func _depth_color(depth: float) -> Color:
	var stops := [Color(0.2, 0.62, 0.72), Color(0.05, 0.3, 0.48), Color(0.03, 0.12, 0.25), Color(0.02, 0.04, 0.1), Color(0.01, 0.01, 0.04)]
	var f := clampf(depth / 6.0, 0.0, stops.size() - 1.001)
	var i := int(f)
	var c0: Color = stops[i]
	var c1: Color = stops[i + 1]
	return c0.lerp(c1, f - i)


func _draw_chart() -> void:
	var w := _chart.size.x
	var h := _chart.size.y
	# Depth gradient: one band per depth.
	var bands := _max_depth() + 2
	for i in bands:
		var y0 := TOP + (i - 1.5) * SPACING
		var c0 := _depth_color(i - 1)
		var c1 := _depth_color(i)
		_chart.draw_polygon(PackedVector2Array([Vector2(0, maxf(y0, 0)), Vector2(w, maxf(y0, 0)), Vector2(w, y0 + SPACING), Vector2(0, y0 + SPACING)]),
			PackedColorArray([c0, c0, c1, c1]))
	# Surface light rays
	for i in 6:
		var x := w * (0.08 + i * 0.15) + sin(_t * 0.3 + i) * 20.0
		_chart.draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 40, 0), Vector2(x + 140, 600), Vector2(x + 60, 600)]),
			PackedColorArray([Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	# Drifting bubbles
	for i in 40:
		var bx := fmod(i * 97.0, w)
		var by := h - fmod(_t * (12.0 + i % 5 * 6.0) + i * 113.0, h)
		_chart.draw_circle(Vector2(bx + sin(_t + i) * 6.0, by), 2.0 + i % 3, Color(1, 1, 1, 0.1))
	# Divider where the hand-made sea ends and the endless dive begins.
	var y_gen := TOP + (GameState.handmade_count() - 0.5) * SPACING + 30.0
	_chart.draw_dashed_line(Vector2(20, y_gen), Vector2(w - 20, y_gen), Color(0.7, 0.6, 1.0, 0.5), 2.0, 10.0)
	_chart.draw_string(get_theme_default_font(), Vector2(24, y_gen - 8), "the endless dive", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.65, 1.0, 0.8))
	# The path: home -> depth 1 -> depth 2 ...
	var pts: Array[Vector2] = [_home.position + _home.size * 0.5]
	for depth in range(1, _max_depth() + 1):
		var b: Button = _buttons[depth]
		pts.append(b.position + b.size * 0.5)
	for i in pts.size() - 1:
		var a := pts[i]
		var c := pts[i + 1]
		var locked := i >= GameState.frontier_depth()
		_chart.draw_dashed_line(a, c, Color(1, 0.95, 0.8, 0.25 if locked else 0.55), 4.0, 12.0)
	# Selection ring
	if _selected and _buttons.has(_selected.depth):
		var b: Button = _buttons[_selected.depth]
		_chart.draw_arc(b.position + b.size * 0.5, NODE_SIZE * 0.5 + 8.0 + sin(_t * 4.0) * 2.0, 0, TAU, 40, Color(1, 0.9, 0.5), 3.0)


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
