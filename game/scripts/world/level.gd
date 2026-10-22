class_name Level
extends Node3D
## A playable level (scenes/level.tscn). Reads GameState.current_level (a
## hand-made level or a generated depth) and GameState.starter, builds the
## arena, and runs the loop:
##   objective (cull / waves / hunt) -> the boss arrives -> beat it ->
##   a portal back to the map opens (take it whenever) and the next depth unlocks.
## Modifiers change the rules (swarm, armored, venom, dark, treasure,
## champions, riptide, frenzy). Home is a Coke can at the north edge.
##
## Dev keys (prototype): F1 random part, F2 spawn a creature, F3 heal, F4 summon the boss.

signal progress_changed
signal boss_spawned(boss: Creature)
signal cleared(unlocked_next: bool)
signal announce(text: String)

const RESPAWN_DELAY := 2.5
const CHAMPION_CHANCE := 0.2

## Set before adding to the tree to override GameState (tests, screenshots).
var level: LevelData
var starter: CreatureData
var persist := true

var rng := RandomNumberGenerator.new()
var player: PlayerCrab
var camera: FollowCamera
var hud: HUD
var auto_spawn := true
var kills := 0
var boss: Creature
var boss_brain: BossBrain
var is_cleared := false
var portal: Portal
## Waves objective: current wave (1-based once started).
var wave := 0
## Hunt objective: marked champions still alive.
var marked_left := 0

var _boss_called := false
var _spawn_timer := 1.0
var _wave_timer := 2.0
var _home_pos := Vector3.ZERO
var _riptide_angle := 0.0
var touch: TouchControls
var inventory: InventoryUI


func _ready() -> void:
	rng.randomize()
	if level == null:
		level = GameState.level(GameState.current_level)
	if level == null:
		level = GameState.level_at_depth(1)
	if starter == null:
		starter = GameState.starter_data(GameState.starter if GameState.starter != &"" else &"debra")
	Creature.water_current = Vector3.ZERO
	_home_pos = Vector3(0, 0, -(level.radius - 6.5))
	var start := _home_pos + Vector3(0, 0, 3.0)
	var keep_clear: Array[Vector3] = [_home_pos, start, Vector3.ZERO, Vector3(0, 0, level.radius * 0.5)]
	LevelBuilder.build(self, level, keep_clear)
	LevelBuilder.home_can(self, _home_pos)
	player = PlayerCrab.new()
	player.creature = starter
	player.persist = persist
	player.home_position = start
	add_child(player)
	player.global_position = start
	camera = FollowCamera.new()
	camera.target = player
	add_child(camera)
	camera.make_current()
	player.camera = camera
	hud = HUD.new()
	hud.player = player
	hud.level = self
	add_child(hud)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 10
	add_child(touch_layer)
	touch = TouchControls.new()
	touch_layer.add_child(touch)
	PlayerInput.debug_pressed.connect(_on_debug)
	PlayerInput.menu_pressed.connect(back_to_map)
	PlayerInput.inventory_pressed.connect(open_inventory)
	match level.objective:
		&"hunt":
			marked_left = level.objective_count
			for i in level.objective_count:
				var a := TAU * i / level.objective_count + 0.5
				spawn_enemy(_pick_creature(), Vector3(cos(a), 0, sin(a)) * level.radius * 0.6, true, {"marked": true})
			for i in 2:
				spawn_enemy(_pick_creature(), spawn_point())
		&"waves":
			pass   # the first wave arrives after a short breather
		_:
			for i in 3:
				spawn_enemy(_pick_creature(), spawn_point())
	_riptide_angle = rng.randf() * TAU
	hud.toast(level.display_name, Color(1, 0.85, 0.6), 3.0)


func _exit_tree() -> void:
	Creature.water_current = Vector3.ZERO
	if PlayerInput.debug_pressed.is_connected(_on_debug):
		PlayerInput.debug_pressed.disconnect(_on_debug)
	if PlayerInput.inventory_pressed.is_connected(open_inventory):
		PlayerInput.inventory_pressed.disconnect(open_inventory)
	get_tree().paused = false
	if PlayerInput.menu_pressed.is_connected(back_to_map):
		PlayerInput.menu_pressed.disconnect(back_to_map)


## The inventory (I / Tab / Back / INV). The stash is only reachable at home.
func open_inventory() -> void:
	if is_instance_valid(inventory) or player.is_dead():
		return
	inventory = InventoryUI.new()
	inventory.player = player
	inventory.at_home = player.global_position.distance_to(player.home_position) < PlayerCrab.HOME_RADIUS + 1.0
	add_child(inventory)


## Dev: finish the level right now (clears it and opens the portal).
func dev_skip() -> void:
	if is_cleared:
		return
	if not _boss_called:
		spawn_boss()
	if is_instance_valid(boss):
		boss.damage_taken_mult = 1.0
		while not boss.is_dead():
			boss.receive_hit(1.0e9, boss.global_position, 0.0, null)


func back_to_map() -> void:
	if is_instance_valid(inventory):
		return
	GameState.go_to_map()


## Short status for the HUD ("Kills 4 / 12", "Wave 2 / 5", "Marked 1 / 3").
func objective_status() -> String:
	if is_cleared:
		return "cleared · portal open"
	if _boss_called:
		return "boss!"
	match level.objective:
		&"waves":
			return "wave %d / %d" % [maxi(wave, 0), level.objective_count] if wave > 0 else "waves incoming"
		&"hunt":
			return "marked %d / %d" % [level.objective_count - marked_left, level.objective_count]
	return "%d / %d" % [mini(kills, level.objective_count), level.objective_count]


func _process(_delta: float) -> void:
	if touch and is_instance_valid(player):
		touch.ability_ready = player.shell_ability.ready_fraction()


func _physics_process(delta: float) -> void:
	if level.has_mod(&"riptide"):
		_riptide_angle += delta * 0.15
		Creature.water_current = Vector3(cos(_riptide_angle), 0, sin(_riptide_angle)) * 1.6
	if not auto_spawn:
		return
	var alive := _alive_regulars()
	if level.objective == &"waves" and not _boss_called and not is_cleared:
		if alive == 0:
			_wave_timer -= delta
			if _wave_timer <= 0.0:
				_wave_timer = 2.5
				if wave >= level.objective_count:
					spawn_boss()
				else:
					_start_wave()
		return
	var cap := level.max_alive * (2 if level.has_mod(&"swarm") else 1)
	if is_instance_valid(boss) and not boss.is_dead():
		cap = maxi(cap / 2, 2)
	if alive < cap:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = RESPAWN_DELAY * (0.5 if level.has_mod(&"swarm") else 1.0)
			spawn_enemy(_pick_creature(), spawn_point())


func _alive_regulars() -> int:
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var c := e as Creature
		if not c.is_dead() and not c.is_boss:
			alive += 1
	return alive


func _start_wave() -> void:
	wave += 1
	var n := 3 + wave * 2 + level.depth / 4
	if level.has_mod(&"swarm"):
		n *= 2
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.2, 0.2)
		var p := player.global_position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(8.0, 11.0)
		if p.length() > level.radius - 2.0:
			p = p.normalized() * (level.radius - 2.0)
		var e := spawn_enemy(_pick_creature(), p)
		e.alert()
	announce.emit("Wave %d!" % wave)
	hud.toast("Wave %d / %d" % [wave, level.objective_count], Color(1, 0.8, 0.5))
	progress_changed.emit()


## track = false: not counted towards the objective (tests, summons, debug).
## opts: {"marked": true} hunt target, {"champion": true}, {"boss": true}, {"split": true}.
func spawn_enemy(creature: CreatureData, pos: Vector3, track := true, opts := {}) -> Creature:
	var e: Creature
	var stolen: Array[PartData] = []
	if creature.is_crustacean():
		var c := EnemyCrab.new()
		c.creature = creature
		c.rng = rng
		c.difficulty = level.difficulty
		c.loot_luck = level.rarity_luck + (1.5 if level.has_mod(&"treasure") else 0.0)
		e = c
	else:
		var k := Critter.new()
		k.creature = creature
		k.rng = rng
		k.difficulty = level.difficulty
		k.loot_luck = level.rarity_luck + (1.5 if level.has_mod(&"treasure") else 0.0)
		e = k
	e.drop_level = level.depth
	e.position = pos
	if level.has_mod(&"swarm"):
		e.hp_mult *= 0.5
	if level.has_mod(&"armored"):
		e.damage_taken_mult = 0.65
	e.venom = creature.venom * level.difficulty * 0.5 + (1.5 * level.difficulty if level.has_mod(&"venom") else 0.0)
	var is_boss_spawn: bool = opts.get("boss", false)
	var champion: bool = opts.get("champion", false) or opts.get("marked", false) or opts.get("split", false)
	if track and not is_boss_spawn and level.has_mod(&"champions") and rng.randf() < CHAMPION_CHANCE:
		champion = true
	if opts.get("split", false):
		e.not_boss = true
		e.size_mult = 0.55
		e.hp_mult = 0.18
		e.display_name = creature.display_name + " (half)"
	if champion:
		stolen = _steal_parts(creature, 1 + rng.randi() % 2)
		e.make_champion(Color(0.9, 0.3, 1.0) if opts.get("marked", false) else Color(1.0, 0.8, 0.2))
		e.is_marked = opts.get("marked", false)
		if e.display_name == "":
			e.display_name = "Champion " + creature.display_name
	elif level.has_mod(&"dark"):
		e.glow_overlay = Creature.glow_material(Color(0.4, 0.9, 1.0))
	if is_boss_spawn:
		e.boss_pace = early_boss_pace(level.depth)
		e.windup_mult = sqrt(e.boss_pace)
		if level.boss_name != "":
			e.display_name = level.boss_name
		for p in level.boss_parts:
			stolen.append(p if p is PartData else null)
	if e is EnemyCrab:
		var parts: Array[PartData] = [null, null, null, null, null, null]
		for i in mini(stolen.size(), 6):
			parts[i] = stolen[i]
		(e as EnemyCrab).extra_parts = parts
	elif e is Critter:
		for p in stolen:
			if p != null:
				(e as Critter).stolen.append(p)
	add_child(e)
	if level.has_mod(&"frenzy"):
		e.move_speed *= 1.25
		e.cooldown_mult *= 0.7
	if e.is_marked:
		_add_marker(e)
	if is_boss_spawn:
		boss_brain = BossBrain.new()
		boss_brain.name = "BossBrain"
		boss_brain.boss = e
		boss_brain.level = self
		boss_brain.traits = level.boss_traits.duplicate()
		boss_brain.announce.connect(func(t: String) -> void: hud.toast(t, Color(1, 0.6, 0.45), 2.5))
		e.add_child(boss_brain)
	if track or is_boss_spawn:
		e.died.connect(_on_enemy_died)
	return e


## Crustacean champions wear 1-2 parts stolen from other creatures at this depth.
func _steal_parts(creature: CreatureData, n: int) -> Array[PartData]:
	var out: Array[PartData] = [null, null, null, null, null, null]
	var loot: Array[PartData] = []
	for c in level.enemy_list():
		for p in c.drop_pool():
			if not p.special and not loot.has(p):
				loot.append(p)
	if loot.is_empty():
		return out
	if not creature.is_crustacean():
		out[0] = loot[rng.randi() % loot.size()]
		return out
	for i in n:
		var s := rng.randi() % Equipment.SOCKET_COUNT
		var fits := loot.filter(func(p: PartData) -> bool: return Equipment.accepts(s, p.slot))
		if not fits.is_empty():
			out[s] = fits[rng.randi() % fits.size()]
	return out


func _add_marker(e: Creature) -> void:
	var l := Label3D.new()
	l.text = "!"
	l.font_size = 72
	l.outline_size = 14
	l.modulate = Color(0.95, 0.4, 1.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.008
	l.position.y = 1.6 * e.size + 0.6
	e.add_child(l)
	l.create_tween().set_loops().tween_property(l, "position:y", l.position.y + 0.25, 0.5).set_trans(Tween.TRANS_SINE)


## Bosses in the first depths leave more time between attacks (and wind up
## a little longer), so new players can learn them: x2 at depth 1, x1.7 at 2, x1.4 at 3.
static func early_boss_pace(depth: int) -> float:
	match depth:
		1:
			return 2.0
		2:
			return 1.7
		3:
			return 1.4
	return 1.0


func spawn_boss() -> Creature:
	_boss_called = true
	var pos := Vector3(0, 0, level.radius * 0.5)
	boss = spawn_enemy(level.boss, pos, false, {"boss": true})
	boss_spawned.emit(boss)
	hud.toast("%s appears!" % boss.display_name, Color(1, 0.5, 0.4), 3.0)
	FX.shockwave(self, pos, 5.0, Color(1, 0.4, 0.3))
	progress_changed.emit()
	return boss


func _on_enemy_died(c: Creature) -> void:
	if c.is_boss:
		_on_boss_died(c)
		return
	kills += 1
	if c.is_marked:
		marked_left = maxi(marked_left - 1, 0)
	progress_changed.emit()
	if _boss_called or is_cleared:
		return
	match level.objective:
		&"hunt":
			if marked_left == 0:
				spawn_boss()
		&"waves":
			pass   # handled when the wave is empty
		_:
			if kills >= level.objective_count:
				spawn_boss()


func _on_boss_died(b: Creature) -> void:
	var first := not is_cleared
	is_cleared = true
	var unlocked := false
	if persist:
		unlocked = GameState.mark_cleared(level.id)
	progress_changed.emit()
	if first:
		open_portal(b.global_position)
		cleared.emit(unlocked)


## A portal back to the map. It stays open; walk in whenever you're done looting.
func open_portal(at: Vector3) -> void:
	if is_instance_valid(portal):
		return
	portal = Portal.new()
	var p := Vector3(at.x, 0, at.z)
	if p.length() > level.radius - 3.0:
		p = p.normalized() * (level.radius - 3.0)
	add_child(portal)
	portal.global_position = p
	portal.entered.connect(back_to_map)


func _pick_creature() -> CreatureData:
	var list := level.enemy_list()
	var w := PackedFloat32Array()
	for c in list:
		w.append(c.spawn_weight * (3.0 if c == level.featured else 1.0))
	return list[rng.rand_weighted(w)]


func spawn_point() -> Vector3:
	var p := Vector3.ZERO
	for i in 20:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (level.radius - 4.0)
		p = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var far_from_player := player == null or p.distance_to(player.global_position) > 9.0
		if far_from_player and p.distance_to(_home_pos) > 7.0:
			break
	return p


func home_position() -> Vector3:
	return _home_pos


func _on_debug(key: int) -> void:
	match key:
		KEY_F1:
			var parts := PartCatalog.all_parts()
			var part := PartInstance.roll(parts[rng.randi() % parts.size()], rng, 1.0, level.depth)
			PartPickup.spawn(self, player.global_position + player.facing * 1.2, part)
		KEY_F2:
			spawn_enemy(_pick_creature(), player.global_position + player.facing * 6.0)
		KEY_F3:
			player.health.fill()
		KEY_F5:
			if GameState.dev_mode:
				dev_skip()
		KEY_F4:
			if not _boss_called:
				spawn_boss()
