class_name WorldMap
extends Control
## The world map (main scene). Depth increases downwards: the shallows are at
## the top, the abyss at the bottom. A path runs from home (the Coke can)
## through every level. Locked levels are greyed out; clearing a level unlocks
## the next. Pick one and DIVE. No story, just drop in.

const NODE_SIZE := 64.0
const PANEL_W := 380.0

var _buttons: Dictionary = {}   # level id -> Button
var _selected: LevelData
var _title: Label
var _desc: Label
var _creatures: Label
var _status: Label
var _dive: Button
var _crab_label: Label
var _t := 0.0


func _ready() -> void:
	if GameState.starter == &"":
		GameState.go_to_select()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	resized.connect(_layout)
	_select(GameState.frontier())
	_layout()


func _build_ui() -> void:
	# Level nodes
	for l in GameState.levels():
		var b := Button.new()
		b.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		b.size = Vector2(NODE_SIZE, NODE_SIZE)
		b.text = str(l.order + 1)
		b.add_theme_font_size_override("font_size", 26)
		var unlocked := GameState.is_unlocked(l.id)
		var col := Color(0.95, 0.7, 0.3) if GameState.is_cleared(l.id) else (Color(0.2, 0.55, 0.8) if unlocked else Color(0.3, 0.33, 0.38))
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col.lightened(0.15) if st == "hover" or st == "focus" else col
			sb.set_corner_radius_all(int(NODE_SIZE * 0.5))
			sb.set_border_width_all(4 if st == "focus" else 3)
			sb.border_color = Color.WHITE if st == "focus" else Color(1, 1, 1, 0.55)
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_select.bind(l))
		add_child(b)
		var name_l := _label(l.display_name + ("  (cleared)" if GameState.is_cleared(l.id) else ""), 18, Color.WHITE if unlocked else Color(0.6, 0.65, 0.7))
		name_l.name = "Name"
		b.add_child(name_l)
		name_l.position = Vector2(NODE_SIZE * 0.5 - 100, NODE_SIZE + 4)
		name_l.size = Vector2(200, 24)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_buttons[l.id] = b
	# Home (the Coke can) = change crab
	var home := Button.new()
	home.name = "HomeButton"
	home.text = "HOME"
	home.custom_minimum_size = Vector2(96, 44)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.8, 0.08, 0.1) if st != "hover" else Color(0.9, 0.2, 0.2)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.95, 0.95, 0.95)
		home.add_theme_stylebox_override(st, sb)
	home.pressed.connect(func() -> void: GameState.go_to_select())
	add_child(home)
	# Top bar: who you're playing
	var top := HBoxContainer.new()
	top.name = "Top"
	top.position = Vector2(20, 14)
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	_crab_label = _label("Playing as %s" % GameState.starter_data().display_name, 22, Color(1, 0.8, 0.6))
	top.add_child(_crab_label)
	var change := Button.new()
	change.text = "Change crab"
	change.pressed.connect(func() -> void: GameState.go_to_select())
	top.add_child(change)
	# Info panel
	var panel := PanelContainer.new()
	panel.name = "Info"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.12, 0.85)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_title = _label("", 28, Color(1, 0.85, 0.55))
	v.add_child(_title)
	_desc = _label("", 17, Color(0.85, 0.92, 1.0))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(PANEL_W - 40, 0)
	v.add_child(_desc)
	_creatures = _label("", 15, Color(0.75, 0.85, 0.9))
	_creatures.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_creatures.custom_minimum_size = Vector2(PANEL_W - 40, 0)
	v.add_child(_creatures)
	_status = _label("", 17, Color(1, 0.75, 0.4))
	v.add_child(_status)
	_dive = Button.new()
	_dive.text = "DIVE IN"
	_dive.custom_minimum_size = Vector2(0, 60)
	_dive.add_theme_font_size_override("font_size", 26)
	_dive.pressed.connect(_on_dive)
	v.add_child(_dive)


func _layout() -> void:
	var map_w := size.x - PANEL_W - 30.0
	for l in GameState.levels():
		var b: Button = _buttons[l.id]
		b.position = Vector2(l.map_pos.x * map_w, 60.0 + l.map_pos.y * (size.y - 140.0)) - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
	var home := get_node("HomeButton") as Button
	home.position = Vector2(0.08 * map_w, 70.0)
	var panel := get_node("Info") as PanelContainer
	panel.position = Vector2(size.x - PANEL_W - 16.0, 70.0)
	panel.size = Vector2(PANEL_W, 0)
	queue_redraw()


func _select(l: LevelData) -> void:
	_selected = l
	var unlocked := GameState.is_unlocked(l.id)
	_title.text = l.display_name
	_desc.text = l.description
	var names: Array[String] = []
	for c in l.enemy_list():
		names.append(c.display_name)
	_creatures.text = "Creatures: %s\nBoss: %s\nKill %d to call the boss." % [", ".join(names), l.boss.display_name if l.boss else "-", l.kill_goal]
	if GameState.is_cleared(l.id):
		_status.text = "Cleared. Better loot the deeper you go."
	elif unlocked:
		_status.text = "Ready."
	else:
		_status.text = "Locked: clear the level before it."
	_dive.disabled = not unlocked
	if unlocked:
		_dive.grab_focus()
	queue_redraw()


func _on_dive() -> void:
	if _selected and GameState.is_unlocked(_selected.id):
		GameState.play_level(_selected.id)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Depth gradient: bright shallows at the top, black abyss at the bottom.
	var top := Color(0.2, 0.62, 0.72)
	var mid := Color(0.05, 0.25, 0.42)
	var bot := Color(0.01, 0.03, 0.08)
	var h := size.y
	var w := size.x
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.5), Vector2(0, h * 0.5)]), PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.5), Vector2(w, h * 0.5), Vector2(w, h), Vector2(0, h)]), PackedColorArray([mid, mid, bot, bot]))
	# Light rays from the surface
	for i in 6:
		var x := w * (0.08 + i * 0.13) + sin(_t * 0.3 + i) * 20.0
		draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 40, 0), Vector2(x + 140, h * 0.55), Vector2(x + 60, h * 0.55)]),
			PackedColorArray([Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)]))
	# Drifting bubbles
	for i in 24:
		var bx := fmod(i * 97.0, w)
		var by := h - fmod(_t * (12.0 + i % 5 * 6.0) + i * 53.0, h)
		draw_circle(Vector2(bx + sin(_t + i) * 6.0, by), 2.0 + i % 3, Color(1, 1, 1, 0.12))
	# The path: home -> level 1 -> level 2 ...
	var pts: Array[Vector2] = []
	var home := get_node_or_null("HomeButton") as Button
	if home:
		pts.append(home.position + home.size * 0.5)
	for l in GameState.levels():
		var b: Button = _buttons.get(l.id)
		if b:
			pts.append(b.position + b.size * 0.5)
	for i in pts.size() - 1:
		var a := pts[i]
		var c := pts[i + 1]
		var seg := c - a
		var n := int(seg.length() / 16.0)
		for j in n:
			if j % 2 == 0:
				draw_line(a + seg * (float(j) / n), a + seg * (float(j + 1) / n), Color(1, 0.95, 0.8, 0.55), 4.0)
	# Selection ring
	if _selected and _buttons.has(_selected.id):
		var b: Button = _buttons[_selected.id]
		draw_arc(b.position + b.size * 0.5, NODE_SIZE * 0.5 + 8.0 + sin(_t * 4.0) * 2.0, 0, TAU, 40, Color(1, 0.9, 0.5), 3.0)


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
