class_name CrabSelect
extends Node3D
## Pick your crustacean. All five starters stand on the sand wearing whatever
## they're currently mutated into (saved per crab). Pick one, then the map.

const SPACING := 2.1

var crabs: Array[CrabBody] = []
var index := 0

var _cam: Camera3D
var _name_buttons: Array[Button] = []
var _name: Label
var _blurb: Label
var _stats: Label
var _continue: Button
var _new: Button
var _save_info: Label
var _confirm_new := false
var _t := 0.0


func _ready() -> void:
	var lvl := GameState.levels()[0]
	LevelBuilder._environment(self, lvl)
	LevelBuilder._floor(self, lvl)
	var d := RandomNumberGenerator.new()
	d.seed = 3
	for i in 9:
		LevelBuilder.rock(self, Vector3(-8 + i * 2.0, 0, -4.5 - d.randf() * 2.0), d.randf_range(0.8, 1.6), d, false, Color(0.35, 0.36, 0.38))
	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)
	_cam.position = Vector3(0, 3.2, 9.6)
	_cam.look_at(Vector3(0, 0.4, 0))
	_cam.make_current()
	for i in GameState.STARTERS.size():
		var body := CrabBody.new()
		add_child(body)
		body.position = Vector3((i - 2) * SPACING, 0, 0)
		_dress(body, GameState.STARTERS[i])
		crabs.append(body)
	_build_ui()
	var cur := GameState.STARTERS.find(GameState.starter)
	_set_index(cur if cur >= 0 else 0)


func _dress(body: CrabBody, id: StringName) -> void:
	var parts := GameState.loadout_for(id)
	for s in Equipment.SOCKET_COUNT:
		body.show_part(s, parts[s])


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var title := _label("Pick your crustacean", 34, Color(1, 0.85, 0.6))
	root.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	for i in GameState.STARTERS.size():
		var b := Button.new()
		b.text = GameState.starter_data(GameState.STARTERS[i]).display_name.get_slice(" ", 0)
		b.custom_minimum_size = Vector2(130, 44)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_set_index.bind(i))
		root.add_child(b)
		_name_buttons.append(b)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.07, 0.12, 0.85)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	_name = _label("", 28, Color(1, 0.7, 0.45))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_name)
	_blurb = _label("", 17, Color(0.85, 0.92, 1.0))
	_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_blurb)
	_stats = _label("", 16, Color(0.8, 0.9, 0.85))
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_stats)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var prev := _button("<", 60)
	prev.pressed.connect(func() -> void: _set_index((index + crabs.size() - 1) % crabs.size()))
	row.add_child(prev)
	_continue = _button("CONTINUE", 200)
	_continue.pressed.connect(_on_continue)
	row.add_child(_continue)
	_new = _button("NEW GAME", 200)
	_new.pressed.connect(_on_new_game)
	row.add_child(_new)
	var nxt := _button(">", 60)
	nxt.pressed.connect(func() -> void: _set_index((index + 1) % crabs.size()))
	row.add_child(nxt)
	_save_info = _label("", 15, Color(1, 0.85, 0.55))
	_save_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_save_info)


func _set_index(i: int) -> void:
	index = i
	_confirm_new = false
	var id := GameState.STARTERS[i]
	var data := GameState.starter_data(id)
	_name.text = data.display_name
	_blurb.text = data.blurb
	var parts := GameState.loadout_for(id)
	var tot := {&"max_hp": data.base_hp, &"attack": 0.0, &"defense": 0.0, &"speed": 0.0}
	for p in parts:
		if p == null:
			continue
		for st in PartData.STATS:
			tot[st] = float(tot[st]) + p.stat(st)
	_stats.text = "HP %d   ATK %d   DEF %d   SPD %.1f      Claws: %s / %s\n%s\nSpace: %s" % [
		roundi(tot[&"max_hp"]), roundi(tot[&"attack"]), roundi(tot[&"defense"]),
		maxf(1.5, Crab.BASE_SPEED + float(tot[&"speed"]) * Crab.SPEED_PER_POINT),
		CrabCombat.style_id(parts[Equipment.Socket.CLAW_L]), CrabCombat.style_id(parts[Equipment.Socket.CLAW_R]),
		"Tail " + TailBrain.info(parts[Equipment.Socket.TAIL]), ShellAbility.info(parts[Equipment.Socket.SHELL])]
	var sum := GameState.slot_summary(id)
	if sum.exists:
		_save_info.text = "Saved game: deepest depth %d, %d levels cleared, %d parts stored" % [sum.deepest, sum.cleared, sum.parts]
		_continue.disabled = false
		_new.text = "NEW GAME"
		_continue.grab_focus.call_deferred()
	else:
		_save_info.text = "No saved game yet: %s starts fresh." % data.display_name.get_slice(" ", 0)
		_continue.disabled = true
		_new.text = "START"
		_new.grab_focus.call_deferred()


## Each crab is its own saved game: pick it back up where you left off.
func _on_continue() -> void:
	GameState.choose_starter(GameState.STARTERS[index])
	GameState.go_to_map()


## New game: wipes this crab's save. If it has one, press twice to confirm.
func _on_new_game() -> void:
	var id := GameState.STARTERS[index]
	if GameState.has_save(id) and not _confirm_new:
		_confirm_new = true
		_new.text = "SURE? WIPES SAVE"
		_save_info.text = "Press again to start %s over from the beginning (gear, bag, stash and map)." % GameState.starter_data(id).display_name.get_slice(" ", 0)
		return
	GameState.new_game(id)
	GameState.go_to_map()
	GameState.choose_starter(GameState.STARTERS[index])
	GameState.go_to_map()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_set_index((index + crabs.size() - 1) % crabs.size())
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_set_index((index + 1) % crabs.size())


func _process(delta: float) -> void:
	_t += delta
	for i in crabs.size():
		var c := crabs[i]
		var target := 1.3 if i == index else 0.9
		c.scale = c.scale.lerp(Vector3.ONE * target, minf(delta * 8.0, 1.0))
		# Face the camera; the chosen one shows off a bit.
		c.rotation.y = PI - 0.55 + (sin(_t * 1.2) * 0.5 if i == index else 0.0)
		c.walk_amount = 0.6 if i == index else 0.0
		var b := _name_buttons[i]
		var sp := _cam.unproject_position(c.global_position + Vector3(0, -0.15, 0.8))
		b.position = sp - Vector2(b.size.x * 0.5, -6)
		b.modulate = Color.WHITE if i == index else Color(1, 1, 1, 0.6)


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 54)
	b.add_theme_font_size_override("font_size", 24)
	return b
