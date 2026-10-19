class_name HUD
extends CanvasLayer
## In-level HUD: HP + stats + level progress (top-left), minimap and what
## you're wearing (top-right), boss bar (top-centre), the part under your
## feet with a stat comparison (bottom-centre), toasts, and the clear panel.

var player: PlayerCrab
var level: Level

var _hp_bar: ProgressBar
var _hp_label: Label
var _stats: Label
var _progress: Label
var _slots: Array[Label] = []
var _prompt_panel: PanelContainer
var _prompt: RichTextLabel
var _toast: Label
var _toast_left := 0.0
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _clear_panel: PanelContainer
var _clear_text: Label
var _minimap: Minimap


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top-left: name, HP, stats, level progress, MAP button
	var tl := VBoxContainer.new()
	tl.position = Vector2(20, 16)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	tl.add_child(_label(player.display_name.to_upper(), 20, Color(1, 0.62, 0.4)))
	_hp_bar = _bar(Color(0.9, 0.3, 0.3), Vector2(260, 22))
	tl.add_child(_hp_bar)
	_hp_label = _label("", 16, Color.WHITE)
	_hp_bar.add_child(_hp_label)
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats = _label("", 17, Color(0.85, 0.95, 1.0))
	tl.add_child(_stats)
	_progress = _label("", 16, Color(1, 0.9, 0.7))
	tl.add_child(_progress)
	var map_btn := Button.new()
	map_btn.text = "MAP"
	map_btn.custom_minimum_size = Vector2(90, 40)
	map_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	map_btn.focus_mode = Control.FOCUS_NONE
	map_btn.pressed.connect(func() -> void: GameState.go_to_map())
	tl.add_child(map_btn)

	# Top-right: minimap + equipped parts
	var tr := VBoxContainer.new()
	root.add_child(tr)
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap = Minimap.new()
	_minimap.level = level
	_minimap.size_flags_horizontal = Control.SIZE_SHRINK_END
	tr.add_child(_minimap)
	for s in Equipment.SOCKET_COUNT:
		var l := _label("", 14, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tr.add_child(l)
		_slots.append(l)

	# Centre column: boss bar + toast at the top, part panel at the bottom
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	col.offset_top = 14
	col.offset_left = 300
	col.offset_right = -300
	_boss_box = VBoxContainer.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	col.add_child(_boss_box)
	_boss_name = _label("", 20, Color(1, 0.55, 0.45))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Color(0.75, 0.25, 0.6), Vector2(0, 16))
	_boss_box.add_child(_boss_bar)
	_toast = _label("", 26, Color.WHITE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_toast)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.add_theme_stylebox_override("panel", _box(Color(0.02, 0.08, 0.14, 0.82), 10))
	_prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_panel.custom_minimum_size = Vector2(420, 0)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_prompt_panel)
	_prompt = RichTextLabel.new()
	_prompt.bbcode_enabled = true
	_prompt.fit_content = true
	_prompt.scroll_active = false
	_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt.add_theme_font_size_override("normal_font_size", 17)
	_prompt.add_theme_font_size_override("bold_font_size", 20)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_child(_prompt)

	# Level clear panel (centre)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clear_panel = PanelContainer.new()
	_clear_panel.add_theme_stylebox_override("panel", _box(Color(0.02, 0.08, 0.14, 0.92), 22))
	_clear_panel.visible = false
	center.add_child(_clear_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	_clear_panel.add_child(cv)
	var title := _label("LEVEL CLEAR", 34, Color(1, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(title)
	_clear_text = _label("", 18, Color(0.85, 0.95, 1.0))
	_clear_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(_clear_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	cv.add_child(row)
	var to_map := _button("Back to map")
	to_map.pressed.connect(func() -> void: GameState.go_to_map())
	row.add_child(to_map)
	var keep := _button("Keep fighting")
	keep.pressed.connect(func() -> void: _clear_panel.visible = false)
	row.add_child(keep)

	player.equipped.connect(_on_equipped)
	player.respawned.connect(func() -> void: toast("Back home.", Color(0.7, 0.9, 1.0)))
	player.died.connect(func(_c: Creature) -> void: toast("%s got cracked..." % player.display_name.get_slice(" ", 0), Color(1, 0.5, 0.4)))
	if level:
		level.boss_spawned.connect(_on_boss_spawned)
		level.cleared.connect(_on_cleared)


func toast(text: String, col := Color.WHITE, sec := 2.2) -> void:
	_toast.text = text
	_toast.modulate = col
	_toast_left = sec


func _on_equipped(socket: int, part: PartInstance) -> void:
	toast("%s: %s" % [Equipment.SOCKET_NAMES[socket], part.display_name()], Rarity.color_of(part.rarity))


func _on_boss_spawned(b: Creature) -> void:
	_boss_box.visible = true
	_boss_name.text = b.display_name


func _on_cleared(unlocked_next: bool) -> void:
	var next: LevelData = GameState.next_level(level.level.id) if level.level else null
	if unlocked_next and next:
		_clear_text.text = "%s unlocked on the map." % next.display_name
	elif next == null:
		_clear_text.text = "You cleared the deepest part of the sea. For now."
	else:
		_clear_text.text = "Cleared again. The loot doesn't care."
	_clear_panel.visible = true
	toast("Level clear!", Color(1, 0.85, 0.4), 3.0)


func _process(delta: float) -> void:
	if player == null:
		return
	var h := player.health
	_hp_bar.max_value = h.max_hp
	_hp_bar.value = h.hp
	_hp_label.text = "%d / %d" % [ceili(h.hp), roundi(h.max_hp)]
	_stats.text = "ATK %d   DEF %d   SPD %.1f" % [roundi(player.equipment.total(&"attack")), roundi(h.defense), player.move_speed]
	if level and level.level:
		var l := level.level
		if level.is_cleared:
			_progress.text = "%s  ·  cleared" % l.display_name
		elif is_instance_valid(level.boss):
			_progress.text = "%s  ·  boss!" % l.display_name
		else:
			_progress.text = "%s  ·  %d / %d" % [l.display_name, mini(level.kills, l.kill_goal), l.kill_goal]
		var b := level.boss
		if is_instance_valid(b) and not b.is_dead():
			_boss_bar.max_value = b.health.max_hp
			_boss_bar.value = b.health.hp
		elif _boss_box.visible:
			_boss_box.visible = false
	for s in Equipment.SOCKET_COUNT:
		var p := player.equipment.get_part(s)
		_slots[s].text = "%s  ·  %s" % [p.display_name() if p else "-", Equipment.SOCKET_NAMES[s]]
		_slots[s].modulate = Rarity.color_of(p.rarity) if p else Color(1, 1, 1, 0.4)
	_update_prompt()
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)


func _update_prompt() -> void:
	var pk := player.focused_pickup
	_prompt_panel.visible = is_instance_valid(pk)
	if not _prompt_panel.visible:
		return
	var part := pk.part
	var col := Rarity.color_of(part.rarity).to_html(false)
	var t := "[center][b][color=#%s]%s[/color][/b]  [color=#9ab]%s[/color]\n" % [col, part.display_name(), PartData.slot_name(part.data.slot)]
	if part.data.slot == PartData.Slot.CLAW:
		t += "[color=#ffe0a0]%s[/color]\n" % CrabCombat.style_info(part)
		t += "Left: %s\n" % _diff(part, player.equipment.get_part(Equipment.Socket.CLAW_L))
		t += "Right: %s\n" % _diff(part, player.equipment.get_part(Equipment.Socket.CLAW_R))
		t += _keys("Equip left", "Equip right")
	else:
		var socket: int = Equipment.sockets_for(part.data.slot)[0]
		t += _diff(part, player.equipment.get_part(socket)) + "\n"
		t += _keys("Equip", "")
	_prompt.text = t + "[/center]"


func _keys(main: String, alt: String) -> String:
	var k := PlayerInput.hint(false)
	if k == "":
		return "[color=#8cf]Tap a button to equip[/color]"
	var s := "[color=#8cf][%s] %s[/color]" % [k, main]
	if alt != "":
		s += "   [color=#8cf][%s] %s[/color]" % [PlayerInput.hint(true), alt]
	return s


## "+4 ATK  -2 SPD" comparing a new part against what's equipped.
func _diff(new_part: PartInstance, old: PartInstance) -> String:
	var bits: Array[String] = []
	for st in PartData.STATS:
		var d := new_part.stat(st) - (old.stat(st) if old else 0.0)
		if absf(d) >= 0.05:
			bits.append("[color=%s]%s%s %s[/color]" % ["#7f7" if d > 0 else "#f77", "+" if d > 0 else "", _num(d), PartData.STAT_LABELS[st]])
	if new_part.data.slot == PartData.Slot.CLAW and old and CrabCombat.style_id(old) != CrabCombat.style_id(new_part):
		bits.append("[color=#ffe0a0]%s → %s[/color]" % [CrabCombat.style_id(old), CrabCombat.style_id(new_part)])
	return "  ".join(bits) if not bits.is_empty() else "[color=#9ab]no stat change[/color]"


func _num(v: float) -> String:
	return str(roundi(v)) if absf(v - roundf(v)) < 0.05 else "%.1f" % v


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = col
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(col: Color, min_size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = min_size
	b.show_percentage = false
	b.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.5)))
	b.add_theme_stylebox_override("fill", _box(col))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 52)
	b.add_theme_font_size_override("font_size", 20)
	return b


func _box(col: Color, pad := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(pad)
	return sb
