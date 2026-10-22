class_name InventoryUI
extends CanvasLayer
## The inventory: what you're wearing (and your set progress), your bag, and
## (at home) your stash. Pick a part to see it compared with what you wear,
## then equip it, move it between bag and stash, or drop it.
## Opens in a level (I / Tab / Back / INV; the stash only at the Coke can) and
## on the map (STASH). Pauses the game while open.

signal closed

const CARD := Vector2(134, 60)

## In a level: the player. On the map: null (we edit the saved loadout).
var player: PlayerCrab
var at_home := false
var starter_id: StringName

var _eq: Equipment
var _own_eq := false
var _worn_box: VBoxContainer
var _sets: Label
var _bag_grid: GridContainer
var _stash_grid: GridContainer
var _bag_title: Label
var _stash_title: Label
var _detail_title: Label
var _detail: RichTextLabel
var _actions: HBoxContainer
var _msg: Label
var _selected: PartInstance
var _selected_worn := -1


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if player:
		_eq = player.equipment
		starter_id = player.creature.id
	else:
		_eq = Equipment.new()
		_own_eq = true
		add_child(_eq)
		var parts := GameState.loadout_for(starter_id)
		for s in Equipment.SOCKET_COUNT:
			_eq.equip(s, parts[s])
	if is_inside_tree() and player:
		get_tree().paused = true
	_build()
	_refresh()


func close() -> void:
	if player:
		get_tree().paused = false
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0.03, 0.06, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 18)
	add_child(root)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)

	# Left: wearing + sets
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	cols.add_child(left)
	left.add_child(_label("WEARING", 22, Color(1, 0.8, 0.55)))
	_worn_box = VBoxContainer.new()
	_worn_box.add_theme_constant_override("separation", 4)
	left.add_child(_worn_box)
	left.add_child(_label("SETS", 18, Color(1, 0.8, 0.55)))
	_sets = _label("", 13, Color(0.85, 0.92, 1.0))
	_sets.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sets.custom_minimum_size = Vector2(280, 0)
	left.add_child(_sets)

	# Middle: bag + stash
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	mid.add_child(scroll)
	var lists := VBoxContainer.new()
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lists)
	_bag_title = _label("", 20, Color(1, 0.8, 0.55))
	lists.add_child(_bag_title)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 4
	lists.add_child(_bag_grid)
	_stash_title = _label("", 20, Color(1, 0.8, 0.55))
	lists.add_child(_stash_title)
	_stash_grid = GridContainer.new()
	_stash_grid.columns = 4
	lists.add_child(_stash_grid)

	# Right: details
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	var close_b := _button("Close  [I]", 0)
	close_b.pressed.connect(close)
	right.add_child(close_b)
	_detail_title = _label("Pick a part", 20, Color.WHITE)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.custom_minimum_size = Vector2(300, 0)
	right.add_child(_detail_title)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.custom_minimum_size = Vector2(300, 0)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("normal_font_size", 15)
	right.add_child(_detail)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	right.add_child(_actions)
	_msg = _label("", 14, Color(1, 0.7, 0.5))
	right.add_child(_msg)


func _refresh() -> void:
	for c in _worn_box.get_children():
		c.queue_free()
	for s in Equipment.SOCKET_COUNT:
		var p := _eq.get_part(s)
		var row := HBoxContainer.new()
		var name_l := _label(Equipment.SOCKET_NAMES[s], 13, Color(0.7, 0.8, 0.9))
		name_l.custom_minimum_size = Vector2(80, 0)
		row.add_child(name_l)
		var b := _card(p)
		b.custom_minimum_size = Vector2(190, 44)
		b.pressed.connect(_select.bind(p, s))
		row.add_child(b)
		_worn_box.add_child(row)
	# Sets
	var lines: Array[String] = []
	var prog := Sets.progress(_eq)
	for id in prog:
		var row: Dictionary = prog[id]
		var done := int(row.good) >= int(row.need)
		lines.append("%s  %d/%d%s\n   %s" % [Sets.title_of(id), row.have, row.need,
			"  ACTIVE" if done else "  (need all at %s+)" % Rarity.name_of(Sets.required_tier(id)), Sets.describe(id)])
	if lines.is_empty():
		lines.append("Wear every piece of one crustacean's set, all Epic or better, for a set bonus.\nDebra's set at Gold is the best gear in the sea.")
	if player:
		var mods: Array[String] = []
		for m in player.active_mods:
			mods.append(Mods.short_name(m) + (" x%d" % player.active_mods[m] if int(player.active_mods[m]) > 1 else ""))
		if not mods.is_empty():
			lines.append("Active mods: " + ", ".join(mods))
	_sets.text = "\n".join(lines)
	_fill(_bag_grid, GameState.bag)
	_bag_title.text = "BAG  %d / %d" % [GameState.bag.size(), GameState.BAG_SIZE]
	_stash_title.visible = at_home
	_stash_grid.visible = at_home
	if at_home:
		_fill(_stash_grid, GameState.stash)
		_stash_title.text = "STASH (home)  %d / %d" % [GameState.stash.size(), GameState.STASH_SIZE]
	_show_detail()


func _fill(grid: GridContainer, parts: Array[PartInstance]) -> void:
	for c in grid.get_children():
		c.queue_free()
	for p in parts:
		var b := _card(p)
		b.pressed.connect(_select.bind(p, -1))
		grid.add_child(b)
	if parts.is_empty():
		grid.add_child(_label("(empty)", 14, Color(0.6, 0.65, 0.7)))


func _card(p: PartInstance) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 13)
	if p == null:
		b.text = "-"
		b.disabled = true
		return b
	b.text = "%s\nLv %d%s" % [p.data.display_name, p.level, "  " + Mods.short_name(p.mod) if p.mod != &"" else ""]
	var col := Rarity.color_of(p.rarity)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.darkened(0.75), 0.95) if st == "normal" else Color(col.darkened(0.55), 0.95)
		sb.set_border_width_all(3 if st == "focus" or p == _selected else 2)
		sb.border_color = Color.WHITE if st == "focus" or p == _selected else col
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", col.lightened(0.3))
	return b


func _select(p: PartInstance, worn_socket: int) -> void:
	_selected = p
	_selected_worn = worn_socket
	_msg.text = ""
	_refresh()


func _show_detail() -> void:
	for c in _actions.get_children():
		c.queue_free()
	var p := _selected
	if p == null:
		_detail_title.text = "Pick a part"
		_detail.text = "[color=#9ab]Each crab has its own bag and stash (its own saved game). The stash lives at home: stand by the Coke can in a level, or use STASH on the map.[/color]"
		return
	_detail_title.text = p.full_name()
	_detail_title.add_theme_color_override("font_color", Rarity.color_of(p.rarity))
	var t := "[color=#9ab]%s%s[/color]\n" % [PartData.slot_name(p.data.slot), ("  ·  " + Sets.title_of(p.data.set_id)) if p.data.set_id != &"" else ""]
	if p.data.description != "":
		t += "[i]%s[/i]\n" % p.data.description
	match p.data.slot:
		PartData.Slot.CLAW:
			t += "[color=#ffe0a0]%s[/color]\n" % CrabCombat.style_info(p)
		PartData.Slot.SHELL:
			t += "[color=#a0d8ff]Space: %s[/color]\n" % ShellAbility.info(p)
		PartData.Slot.TAIL:
			t += "[color=#a0ffd0]%s[/color]\n" % TailBrain.info(p)
	if p.mod != &"":
		t += "[color=#%s]%s[/color]\n" % [Rarity.color_of(p.rarity).to_html(false), Mods.info(p.mod)]
	for st in PartData.STATS:
		var v := p.stat(st)
		if absf(v) > 0.05:
			t += "%s %s\n" % [PartData.STAT_LABELS[st], ("+%.1f" % v) if v > 0 else ("%.1f" % v)]
	if _selected_worn < 0:
		for s in Equipment.sockets_for(p.data.slot):
			t += "vs %s: %s\n" % [Equipment.SOCKET_NAMES[s], _diff(p, _eq.get_part(s))]
	_detail.text = t
	if _selected_worn >= 0:
		return   # worn parts are swapped out by equipping something else
	if p.data.slot == PartData.Slot.CLAW:
		_action("Equip L", func() -> void: _equip(Equipment.Socket.CLAW_L))
		_action("Equip R", func() -> void: _equip(Equipment.Socket.CLAW_R))
	else:
		_action("Equip", func() -> void: _equip(Equipment.sockets_for(p.data.slot)[0]))
	if at_home:
		if GameState.bag.has(p):
			_action("To stash", func() -> void: _move(true))
		else:
			_action("To bag", func() -> void: _move(false))
	_action("Drop" if player else "Scrap", _drop)


func _diff(new_part: PartInstance, old: PartInstance) -> String:
	var bits: Array[String] = []
	for st in PartData.STATS:
		var d := new_part.stat(st) - (old.stat(st) if old else 0.0)
		if absf(d) >= 0.05:
			bits.append("[color=%s]%s%.1f %s[/color]" % ["#7f7" if d > 0 else "#f77", "+" if d > 0 else "", d, PartData.STAT_LABELS[st]])
	return " ".join(bits) if not bits.is_empty() else "[color=#9ab]same stats[/color]"


func _equip(socket: int) -> void:
	var p := _selected
	if player:
		player.equip_from_storage(socket, p)
	else:
		var old := _eq.get_part(socket)
		GameState.remove_part(p)
		_eq.equip(socket, p)
		if old and not GameState.add_to_bag(old):
			GameState.stash.append(old)
		GameState.store_loadout(starter_id, _eq)
	_selected = null
	_msg.text = "Equipped."
	_refresh()


func _move(to_stash: bool) -> void:
	if not GameState.move_part(_selected, to_stash):
		_msg.text = "No room there."
		return
	_refresh()


func _drop() -> void:
	var p := _selected
	GameState.remove_part(p)
	if player:
		PartPickup.spawn(player.get_parent(), player.global_position + player.facing * 1.2, p, false)
	_selected = null
	_msg.text = "Dropped." if player else "Scrapped."
	_refresh()


func _action(text: String, cb: Callable) -> void:
	var b := _button(text, 0)
	b.pressed.connect(cb)
	_actions.add_child(b)
	if _actions.get_child_count() == 1:
		b.grab_focus.call_deferred()


func _button(text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 46)
	b.add_theme_font_size_override("font_size", 17)
	return b


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
