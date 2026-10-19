class_name HUD
extends CanvasLayer
## Prototype HUD: HP + stats (top-left), what Debra is wearing (top-right),
## the part under your feet with a stat comparison (bottom-centre), toasts.

var player: PlayerCrab

var _hp_bar: ProgressBar
var _hp_label: Label
var _stats: Label
var _kills: Label
var _slots: Array[Label] = []
var _prompt_panel: PanelContainer
var _prompt: RichTextLabel
var _toast: Label
var _toast_left := 0.0


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top-left: HP and stats
	var tl := VBoxContainer.new()
	tl.position = Vector2(20, 16)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	tl.add_child(_label("DEBRA", 22, Color(1, 0.62, 0.4)))
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(260, 22)
	_hp_bar.show_percentage = false
	_hp_bar.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.5)))
	_hp_bar.add_theme_stylebox_override("fill", _box(Color(0.9, 0.3, 0.3)))
	tl.add_child(_hp_bar)
	_hp_label = _label("", 16, Color.WHITE)
	_hp_bar.add_child(_hp_label)
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats = _label("", 18, Color(0.85, 0.95, 1.0))
	tl.add_child(_stats)
	_kills = _label("", 16, Color(0.75, 0.85, 0.9))
	tl.add_child(_kills)

	# Top-right: equipped parts
	var tr := VBoxContainer.new()
	root.add_child(tr)
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in Equipment.SOCKET_COUNT:
		var l := _label("", 16, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tr.add_child(l)
		_slots.append(l)

	# Centre column: toast at the top, part-under-your-feet panel at the bottom
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	col.offset_top = 64
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

	player.equipped.connect(_on_equipped)
	player.respawned.connect(func() -> void: toast("Back home.", Color(0.7, 0.9, 1.0)))
	player.died.connect(func(_c: Crab) -> void: toast("Debra got cracked...", Color(1, 0.5, 0.4)))


func toast(text: String, col := Color.WHITE, sec := 2.2) -> void:
	_toast.text = text
	_toast.modulate = col
	_toast_left = sec


func _on_equipped(socket: int, part: PartInstance) -> void:
	toast("%s: %s" % [Equipment.SOCKET_NAMES[socket], part.display_name()], Rarity.color_of(part.rarity))


func _process(delta: float) -> void:
	if player == null:
		return
	var h := player.health
	_hp_bar.max_value = h.max_hp
	_hp_bar.value = h.hp
	_hp_label.text = "%d / %d" % [ceili(h.hp), roundi(h.max_hp)]
	_stats.text = "ATK %d   DEF %d   SPD %.1f" % [roundi(player.equipment.total(&"attack")), roundi(h.defense), player.move_speed]
	_kills.text = "Kills: %d" % player.kills
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


func _box(col: Color, pad := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(pad)
	return sb
