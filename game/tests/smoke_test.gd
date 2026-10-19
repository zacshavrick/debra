extends Node
## Headless smoke test. Exit code 0 = pass.
##   godot --headless --path game res://tests/smoke_test.tscn
## Covers the prototype "done when" list, milestone 2 (levels, map, starters,
## sea creatures) and milestone 3 (endless generator, objectives, modifiers,
## chimera bosses + adaptive tactics, tails, part levels, portal).
## Uses a throwaway save file.

const TEST_SAVE := "user://smoke_test_save.json"
const BEHAVIOURS := [&"melee", &"ranged", &"charger", &"drifter", &"turret", &"ambusher"]

var _failures: Array[String] = []
var level: Level
var player: PlayerCrab


func _ready() -> void:
	GameState.use_save_file(TEST_SAVE)
	_test_data()
	_test_part_levels()
	_test_generator()
	await _test_sockets_and_alignment()

	level = _open_level(GameState.level(&"shallows"), &"debra")
	player = level.player
	await _frames(5)
	_check(player.display_name == "Debra the Lobster", "Debra is the lobster (%s)" % player.display_name)
	_check(player.equipment.get_part(Equipment.Socket.TAIL) != null, "Debra has a tail")

	await _test_movement()
	await _test_every_creature()
	await _test_equip_changes_look_and_stats()
	await _test_claw_styles()
	await _test_tails()
	await _test_enemies_fight_back()
	await _test_level_flow_and_portal()
	await _test_death_and_respawn()
	_test_save_roundtrip()
	_test_rarity_roll()
	level.queue_free()
	await _frames(3)
	await _test_objectives()
	await _test_boss_brain()
	await _test_modifiers()
	await _test_screens()

	DirAccess.remove_absolute(TEST_SAVE)
	for f in _failures:
		printerr("FAIL: ", f)
	print("SMOKE TEST %s (%d failures)" % ["PASSED" if _failures.is_empty() else "FAILED", _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _open_level(l: LevelData, starter: StringName, clear := true) -> Level:
	var lv: Level = load("res://scenes/level.tscn").instantiate()
	lv.level = l
	lv.starter = GameState.starter_data(starter)
	add_child(lv)
	lv.auto_spawn = false
	lv.rng.seed = 1234
	for e in (get_tree().get_nodes_in_group("enemies") if clear else []):
		e.remove_from_group("enemies")
		e.queue_free()
	return lv


func _test_data() -> void:
	var parts := PartCatalog.all_parts()
	_check(parts.size() >= 100, "part catalog loads (%d parts)" % parts.size())
	var ids := {}
	var tails := 0
	for p in parts:
		_check(not ids.has(p.id), "part id unique: %s" % p.id)
		ids[p.id] = true
		if p.slot == PartData.Slot.CLAW:
			_check(CrabCombat.STYLES.has(p.ability), "claw %s has a known attack style (%s)" % [p.id, p.ability])
		if p.slot == PartData.Slot.TAIL:
			tails += 1
			_check(TailBrain.TAILS.has(p.ability), "tail %s has a known behaviour (%s)" % [p.id, p.ability])
	_check(tails >= 12, "lots of tails (%d)" % tails)
	var creatures := PartCatalog.all_creatures()
	_check(creatures.size() >= 40, "creatures load (%d)" % creatures.size())
	var critters := 0
	for c in creatures:
		if c.is_crustacean():
			var lo := c.loadout()
			for s in Equipment.SOCKET_COUNT:
				if s == Equipment.Socket.TAIL and lo[s] == null:
					continue   # crabs may keep their tail tucked away
				_check(lo[s] != null and Equipment.accepts(s, lo[s].slot), "%s loadout fits socket %s" % [c.id, Equipment.SOCKET_NAMES[s]])
		else:
			critters += 1
			_check(CritterVisual.KINDS.has(c.body_kind), "%s has a known body (%s)" % [c.id, c.body_kind])
			_check(CritterAttack.ATTACKS.has(c.attack), "%s has a known attack (%s)" % [c.id, c.attack])
			_check(BEHAVIOURS.has(c.behaviour), "%s has a known behaviour (%s)" % [c.id, c.behaviour])
			_check(c.drops.size() >= 1 and c.drops.size() <= 2, "%s drops 1-2 parts (%d)" % [c.id, c.drops.size()])
			_check(c.playable == false, "%s (non-crustacean) is not playable" % c.id)
		for sp in c.special_drops:
			_check(sp is PartData and (sp as PartData).special, "%s special drop is flagged special" % c.id)
	_check(critters >= 20, "at least 20 non-crustacean creatures (%d)" % critters)
	for id in GameState.STARTERS:
		var s := GameState.starter_data(id)
		_check(s != null and s.playable and s.is_crustacean() and s.tail != null, "starter %s exists, is a crustacean, has a tail" % id)
	var levels := GameState.levels()
	_check(levels.size() == 5, "5 hand-made levels (%d)" % levels.size())
	for i in levels.size():
		var l := levels[i]
		_check(l.depth == i + 1, "level %s is depth %d" % [l.id, l.depth])
		_check(not l.enemy_list().is_empty(), "level %s has creatures" % l.id)
		_check(l.boss != null and l.boss.boss, "level %s has a boss" % l.id)
	_check(GameState.is_unlocked(&"shallows") and not GameState.is_unlocked(&"kelp"), "fresh save: only depth 1 unlocked")


func _test_part_levels() -> void:
	var claw := PartCatalog.by_id(&"shore_pincer")
	var lo := PartInstance.new(claw, Rarity.Tier.COMMON, 1)
	var hi := PartInstance.new(claw, Rarity.Tier.COMMON, 20)
	_check(hi.stat(&"attack") > lo.stat(&"attack") * 2.5, "level 20 part is much stronger (%.1f vs %.1f)" % [hi.stat(&"attack"), lo.stat(&"attack")])
	var heavy := PartInstance.new(PartCatalog.by_id(&"hermit_shell"), Rarity.Tier.EPIC, 30)
	_check(heavy.stat(&"speed") == PartCatalog.by_id(&"hermit_shell").speed, "penalties don't scale")
	var back := PartInstance.from_dict(hi.to_dict())
	_check(back.level == 20, "part level survives the save format")


func _test_generator() -> void:
	var names := {}
	var biomes := {}
	var layouts := {}
	var objectives := {}
	var mods := {}
	for depth in range(6, 61):
		var l := GameState.level_at_depth(depth)
		_check(l != null and l.depth == depth, "depth %d generates" % depth)
		_check(String(l.id) == "depth_%d" % depth, "depth %d id" % depth)
		_check(l.enemy_list().size() >= 5, "depth %d has creatures" % depth)
		for e in l.enemy_list():
			_check(e.min_depth <= depth and not e.playable and not e.boss, "depth %d creature %s allowed" % [depth, e.id])
		_check(l.boss != null and l.boss.boss and l.boss_name != "", "depth %d has a named boss" % depth)
		for s in l.boss_parts.size():
			var p = l.boss_parts[s]
			if p != null and l.boss.is_crustacean():
				_check(Equipment.accepts(s, (p as PartData).slot), "depth %d chimera part fits socket %d" % [depth, s])
		_check(not l.modifiers.is_empty(), "depth %d has modifiers" % depth)
		_check(l.difficulty > GameState.level_at_depth(depth - 1).difficulty, "depth %d is harder than %d" % [depth, depth - 1])
		names[l.boss_name] = true
		biomes[l.decor] = true
		layouts[l.layout] = true
		objectives[l.objective] = true
		for m in l.modifiers:
			mods[m] = true
	_check(names.size() > 30, "bosses have varied names (%d unique)" % names.size())
	_check(biomes.size() >= 8, "biomes vary (%d)" % biomes.size())
	_check(layouts.size() == LevelGenerator.LAYOUTS.size(), "all layouts show up (%d)" % layouts.size())
	_check(objectives.size() == 3, "all objectives show up")
	_check(mods.size() == LevelGenerator.MODIFIERS.size(), "all modifiers show up (%d)" % mods.size())
	var a := GameState.level_at_depth(23)
	LevelGenerator._cache.clear()
	var b := GameState.level_at_depth(23)
	_check(a != b and a.boss_name == b.boss_name and a.decor == b.decor and a.modifiers == b.modifiers, "the same depth always generates the same level")
	_check(GameState.level_at_depth(500) != null, "depth 500 exists")


## Every part in every socket that accepts it: snaps to the socket origin, has
## geometry, stays near its socket, and legs reach the ground.
func _test_sockets_and_alignment() -> void:
	var body := CrabBody.new()
	add_child(body)
	body.global_position = Vector3(100, 0, 100)
	for i in Equipment.SOCKET_COUNT:
		_check(body.get_socket(i) != null and body.get_socket(i).name == CrabBody.SOCKET_NAMES[i], "rig has %s" % CrabBody.SOCKET_NAMES[i])
	for p in PartCatalog.all_parts():
		for socket in Equipment.sockets_for(p.slot):
			body.show_part(socket, PartInstance.new(p, Rarity.Tier.EPIC))
			await _seconds(0.27)   # let the equip "pop" tween settle
			var sock := body.get_socket(socket)
			_check(sock.get_child_count() == 1, "%s: one visual in %s" % [p.id, sock.name])
			var v := sock.get_child(0) as Node3D
			_check(v.position.is_zero_approx(), "%s snaps to socket origin" % p.id)
			var box := _aabb(v)
			_check(box.size.length() > 0.05, "%s has geometry" % p.id)
			var local_center := box.get_center() - sock.global_position
			_check(local_center.length() < 0.9, "%s stays near its socket (%.2f)" % [p.id, local_center.length()])
			_check(box.position.y > -0.08, "%s doesn't sink into the floor (min y %.2f)" % [p.id, box.position.y])
			if p.slot == PartData.Slot.LEGS:
				_check(absf(box.position.y) < 0.06, "%s feet touch the ground (min y %.2f)" % [p.id, box.position.y])
			if p.slot == PartData.Slot.CLAW:
				_check(v.find_child("Jaw", true, false) != null, "%s has a Jaw node" % p.id)
				var cx := box.get_center().x - body.global_position.x
				_check(signf(cx) == signf(sock.position.x), "%s mirrored onto the %s side" % [p.id, "left" if sock.position.x < 0 else "right"])
			if p.slot == PartData.Slot.TAIL:
				_check(v.get_node_or_null("Swing") != null, "%s has a Swing node" % p.id)
				_check(box.get_center().z - body.global_position.z > 0.0, "%s points backwards" % p.id)
	body.queue_free()


func _test_movement() -> void:
	var start := player.global_position
	PlayerInput.set_override(Vector2(0, -1))   # down the screen, away from home
	await _seconds(0.8)
	PlayerInput.set_override(null)
	var moved := player.global_position.distance_to(start)
	_check(moved > 2.0, "player moves (%.2f)" % moved)
	_check(player.global_position.y > -0.3, "player stays on the floor (y %.2f)" % player.global_position.y)


## Every creature (including bosses) spawns, can be killed, and drops from its own pool.
func _test_every_creature() -> void:
	player.global_position = Vector3(0, 0, 0)
	for c in PartCatalog.all_creatures():
		if c.playable:
			continue
		var before := get_tree().get_nodes_in_group("pickups").size()
		var e := level.spawn_enemy(c, Vector3(0, 0, -9), false)
		await _frames(4)
		_check(is_instance_valid(e) and not e.is_dead(), "%s spawns alive" % c.id)
		if not c.is_crustacean():
			_check((e as Critter).visual != null and (e as Critter).visual.get_child_count() > 0, "%s has a body" % c.id)
		var guard := 0
		while not e.is_dead() and guard < 100:
			e.receive_hit(1000.0, player.global_position, 0.0, player)
			guard += 1
		await _frames(3)
		var pickups := get_tree().get_nodes_in_group("pickups")
		var expected := 2 if c.boss else 1
		_check(pickups.size() == before + expected, "%s drops %d part(s) (%d -> %d)" % [c.id, expected, before, pickups.size()])
		var pool := c.drop_pool()
		for i in range(before, pickups.size()):
			var pk := pickups[i] as PartPickup
			_check(pool.has(pk.part.data), "%s drops its own parts (%s)" % [c.id, pk.part.data.id])
			_check(pk.part.level == level.level.depth, "%s drop is level %d (got %d)" % [c.id, level.level.depth, pk.part.level])
		for i in range(before, pickups.size()):
			pickups[i].remove_from_group("pickups")
			pickups[i].queue_free()
		player.health.fill()
	await _seconds(1.8)
	_clear_enemies()
	_check(player.kills > 35, "kills counted (%d)" % player.kills)


func _test_equip_changes_look_and_stats() -> void:
	player.global_position = Vector3(0, 0, 0)
	var conch := PartInstance.new(PartCatalog.by_id(&"hermit_shell"), Rarity.Tier.EPIC, 3)
	var pk := PartPickup.spawn(level, player.global_position + player.facing * 0.5, conch, false)
	await _seconds(0.7)
	_check(player.focused_pickup == pk, "standing on a part focuses it")
	var hp_before := player.health.max_hp
	var def_before := player.health.defense
	PlayerInput.interact_pressed.emit(false)
	await _frames(2)
	_check(player.equipment.get_part(Equipment.Socket.SHELL) == conch, "interact equips the part")
	var shell_socket := player.body.get_socket(Equipment.Socket.SHELL)
	_check(shell_socket.get_child(shell_socket.get_child_count() - 1).name == "hermit_shell", "shell socket shows the new look")
	_check(player.health.max_hp > hp_before, "max HP went up (%.0f -> %.0f)" % [hp_before, player.health.max_hp])
	_check(player.health.defense > def_before, "DEF went up (%.1f -> %.1f)" % [def_before, player.health.defense])
	var saved := GameState.loadout_for(&"debra")[Equipment.Socket.SHELL]
	_check(saved.data.id == &"hermit_shell" and saved.level == 3, "mutation (with its level) saved for Debra")


func _test_claw_styles() -> void:
	player.global_position = Vector3(0, 0, 0)
	player.face_now(Vector3.FORWARD)
	var claws := {&"pinch": &"saul_pincer", &"crush": &"hermit_crusher", &"snap": &"mantis_snapper", &"cut": &"lobster_cutter",
		&"bite": &"shark_jaw", &"lash": &"spider_arm", &"sting": &"ray_stinger", &"rake": &"yeti_claw"}
	for style in claws:
		player.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(claws[style])))
		await _seconds(0.3)
		var dist := 5.0 if style == &"snap" else 1.6
		var dummy := level.spawn_enemy(PartCatalog.creature(&"giant_isopod"), player.global_position + Vector3(0, 0, -dist), false)
		dummy.lock_ai(30.0)
		await _frames(2)
		player.health.hp = player.health.max_hp * 0.5
		var shots := get_tree().get_nodes_in_group("projectiles").size()
		var hp0 := dummy.health.hp
		var my_hp := player.health.hp
		PlayerInput.set_override(Vector2.ZERO, Vector3.FORWARD)
		PlayerInput.press_claw(PlayerInput.Claw.LEFT, 0.05)
		await _seconds(0.12)
		_check(player.combat.last_style[0] == style, "%s claw uses %s (got %s)" % [claws[style], style, player.combat.last_style[0]])
		if style == &"snap":
			_check(get_tree().get_nodes_in_group("projectiles").size() > shots, "snap fires a bubble")
		await _seconds(0.5)
		_check(dummy.health.hp < hp0, "%s hits the target (%.0f -> %.0f)" % [style, hp0, dummy.health.hp])
		if style == &"bite":
			_check(player.health.hp > my_hp, "bite heals (%.1f -> %.1f)" % [my_hp, player.health.hp])
		if style == &"sting":
			var after := dummy.health.hp
			await _seconds(1.2)
			_check(dummy.health.hp < after, "sting poisons over time (%.1f -> %.1f)" % [after, dummy.health.hp])
		PlayerInput.set_override(null)
		dummy.queue_free()
		await _seconds(0.9)
	player.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(&"spider_arm")))
	player.equip_part(Equipment.Socket.CLAW_R, PartInstance.new(PartCatalog.by_id(&"saul_pincer")))
	_check(player.combat.attack_range(0) > player.combat.attack_range(1) * 1.5, "lash reaches further than a pincer")
	player.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(&"hermit_crusher")))
	_check(player.combat.damage_for(0) > player.combat.damage_for(1), "crusher hits harder than a pincer")
	player.equip_part(Equipment.Socket.CLAW_R, PartInstance.new(PartCatalog.by_id(&"saul_pincer"), Rarity.Tier.COMMON, 15))
	var lv15 := player.combat.damage_for(1)
	player.equip_part(Equipment.Socket.CLAW_R, PartInstance.new(PartCatalog.by_id(&"saul_pincer"), Rarity.Tier.COMMON, 1))
	_check(lv15 > player.combat.damage_for(1) * 1.8, "a level 15 claw hits much harder")
	_clear_enemies()


## Tails act on their own: stab and zap tails hit nearby enemies without any input.
func _test_tails() -> void:
	for t in [&"horseshoe_tail", &"torpedo_tail"]:
		player.global_position = Vector3(0, 0, 0)
		player.equip_part(Equipment.Socket.TAIL, PartInstance.new(PartCatalog.by_id(t)))
		var dummy := level.spawn_enemy(PartCatalog.creature(&"giant_isopod"), Vector3(0, 0, 1.6), false)
		dummy.lock_ai(30.0)
		var hp0 := dummy.health.hp
		await _seconds(5.5)
		_check(dummy.health.hp < hp0, "%s attacks on its own (%.0f -> %.0f)" % [t, hp0, dummy.health.hp])
		dummy.queue_free()
		await _frames(2)
	# Spines tail fires when you're hit.
	player.equip_part(Equipment.Socket.TAIL, PartInstance.new(PartCatalog.by_id(&"lionfish_tail")))
	var fired := false
	for i in 8:
		var before := get_tree().get_nodes_in_group("projectiles").size()
		player.receive_hit(1.0, player.global_position + Vector3.FORWARD, 0.0, null)
		await _frames(2)
		if get_tree().get_nodes_in_group("projectiles").size() > before:
			fired = true
			break
		await _seconds(1.1)
	_check(fired, "spines tail fires when you're hit")
	# Lure tail calls creatures over.
	player.equip_part(Equipment.Socket.TAIL, PartInstance.new(PartCatalog.by_id(&"angler_tail")))
	var far := level.spawn_enemy(PartCatalog.creature(&"shore_crab"), Vector3(14, 0, 0), false)
	far.creature.aggro_range = 2.0
	player.tail._timer = 0.0
	await _seconds(2.5)
	_check(far.global_position.distance_to(player.global_position) < 13.0, "lure tail draws creatures in")
	far.creature.aggro_range = 7.0
	player.equip_part(Equipment.Socket.TAIL, PartInstance.new(PartCatalog.by_id(&"debra_tail")))
	_clear_enemies()
	player.health.fill()


func _test_enemies_fight_back() -> void:
	for id in [&"shore_crab", &"octopus", &"moray_eel", &"jellyfish", &"torpedo_ray", &"cuttlefish", &"barracuda"]:
		player.global_position = Vector3(0, 0, 3)
		player.health.fill()
		var e := level.spawn_enemy(PartCatalog.creature(id), player.global_position + Vector3(2.5, 0, 0), false)
		var hp := player.health.hp
		await _seconds(4.0)
		_check(player.health.hp < hp, "%s fights back (%.0f -> %.0f)" % [id, hp, player.health.hp])
		e.queue_free()
		_clear_projectiles()
		await _frames(2)
	player.health.fill()


func _test_level_flow_and_portal() -> void:
	_check(not GameState.is_unlocked(&"kelp"), "kelp locked before the clear")
	level.kills = level.level.objective_count - 1
	var e := level.spawn_enemy(PartCatalog.creature(&"shore_crab"), Vector3(6, 0, 6))
	await _frames(2)
	e.receive_hit(1000.0, Vector3.ZERO, 0.0, player)
	await _frames(3)
	_check(is_instance_valid(level.boss), "reaching the kill goal brings the boss")
	if is_instance_valid(level.boss):
		_check(level.boss.is_boss and level.boss.size > 1.5, "the boss is big")
		_check(level.boss.get_node_or_null("BossBrain") != null, "the boss has a boss brain")
		while not level.boss.is_dead():
			level.boss.receive_hit(1000.0, Vector3.ZERO, 0.0, player)
		await _frames(3)
	_check(level.is_cleared, "beating the boss clears the level")
	_check(GameState.is_cleared(&"shallows"), "clear is saved")
	_check(GameState.is_unlocked(&"kelp"), "clearing depth 1 unlocks depth 2")
	_check(not GameState.is_unlocked(&"reef"), "depth 3 still locked")
	_check(is_instance_valid(level.portal), "a portal opens where the boss died")
	if is_instance_valid(level.portal):
		level.portal.entered.disconnect(level.back_to_map)
		var used := [false]
		level.portal.entered.connect(func() -> void: used[0] = true)
		await _seconds(1.2)
		_check(not used[0], "the portal waits for you")
		player.global_position = level.portal.global_position
		await _seconds(0.3)
		_check(used[0], "walking into the portal takes it")
	await _seconds(1.8)
	_clear_enemies()


func _test_death_and_respawn() -> void:
	player.global_position = Vector3(5, 0, 0)
	player.receive_hit(99999.0, player.global_position + Vector3.FORWARD, 0.0, null)
	_check(player.is_dead(), "player can die")
	await _seconds(PlayerCrab.RESPAWN_DELAY + 0.3)
	_check(not player.is_dead(), "player respawns")
	_check(player.global_position.distance_to(player.home_position) < 1.0, "respawn at home")
	_check(is_equal_approx(player.health.hp, player.health.max_hp), "respawn with full HP")


func _test_save_roundtrip() -> void:
	GameState.choose_starter(&"louise")
	var eq := Equipment.new()
	for s in Equipment.SOCKET_COUNT:
		eq.equip(s, GameState.loadout_for(&"louise")[s])
	eq.equip(Equipment.Socket.HEAD, PartInstance.new(PartCatalog.by_id(&"angler_lure"), Rarity.Tier.RARE, 7))
	GameState.store_loadout(&"louise", eq)
	eq.free()
	GameState.load_game()
	_check(GameState.starter == &"louise", "starter survives a reload")
	var head := GameState.loadout_for(&"louise")[Equipment.Socket.HEAD]
	_check(head.data.id == &"angler_lure" and head.rarity == Rarity.Tier.RARE and head.level == 7, "mutations survive a reload")
	_check(GameState.is_cleared(&"shallows"), "clears survive a reload")
	_check(GameState.loadout_for(&"saul")[Equipment.Socket.SHELL].data.id == &"saul_shell", "other crabs keep their default parts")


func _test_rarity_roll() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts := [0, 0, 0, 0]
	for i in 4000:
		counts[Rarity.roll(rng)] += 1
	_check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > 0, "rarity odds ordered %s" % str(counts))
	var lucky := [0, 0, 0, 0]
	for i in 4000:
		lucky[Rarity.roll(rng, 1.0)] += 1
	_check(lucky[3] > counts[3], "luck raises epic odds (%d vs %d)" % [lucky[3], counts[3]])


## Waves and Hunt bring the boss when done.
func _test_objectives() -> void:
	var waves := GameState.level_at_depth(6).duplicate() as LevelData
	waves.objective = &"waves"
	waves.objective_count = 1
	waves.modifiers = []
	var lv := _open_level(waves, &"saul")
	lv.auto_spawn = true
	lv.player.global_position = Vector3(0, 0, 0)
	await _seconds(3.0)
	_check(lv.wave == 1 and get_tree().get_nodes_in_group("enemies").size() >= 3, "waves: wave 1 arrives (%d enemies)" % get_tree().get_nodes_in_group("enemies").size())
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Creature).receive_hit(99999.0, Vector3.ZERO, 0.0, lv.player)
	await _seconds(3.5)
	_check(is_instance_valid(lv.boss), "waves: the boss comes after the last wave")
	lv.queue_free()
	await _frames(3)
	var hunt := GameState.level_at_depth(7).duplicate() as LevelData
	hunt.objective = &"hunt"
	hunt.objective_count = 2
	hunt.modifiers = []
	lv = _open_level(hunt, &"gary", false)
	await _frames(3)
	var marked: Array[Creature] = []
	for c in get_tree().get_nodes_in_group("creatures"):
		if (c as Creature).is_marked:
			marked.append(c)
	_check(marked.size() == 2, "hunt: 2 marked champions spawn (%d)" % marked.size())
	_check(not marked.is_empty() and marked[0].is_champion, "hunt targets are champions")
	for m in marked:
		m.receive_hit(99999.0, Vector3.ZERO, 0.0, lv.player)
	await _frames(3)
	_check(is_instance_valid(lv.boss), "hunt: killing the marked brings the boss")
	lv.queue_free()
	await _frames(3)


## Chimera bosses wear stolen parts; the boss adapts to range vs close play.
func _test_boss_brain() -> void:
	var l := GameState.level_at_depth(20).duplicate() as LevelData
	l.boss_traits = [&"shell", &"enrage", &"splitter"]
	l.modifiers = []
	var lv := _open_level(l, &"marjorie")
	var b := lv.spawn_boss()
	await _frames(3)
	_check(b.display_name == l.boss_name, "boss uses its generated name")
	if b is EnemyCrab:
		var stolen := 0
		for s in Equipment.SOCKET_COUNT:
			if l.boss_parts[s] != null:
				stolen += 1
				_check(b.equipment.get_part(s).data == l.boss_parts[s], "chimera wears the stolen part in socket %d" % s)
		_check(stolen >= 2, "chimera stole at least 2 parts (%d)" % stolen)
	var brain := lv.boss_brain
	var p := lv.player
	b.lock_ai(999.0)
	# Snipe it from range -> it rushes.
	p.global_position = b.global_position + Vector3(0, 0, 10)
	for i in 6:
		b.receive_hit(1.0, p.global_position, 0.0, p)
	await _seconds(2.3)
	_check(brain.tactic == &"rush", "sniping makes the boss rush (%s)" % brain.tactic)
	# Brawl up close -> it bristles with thorns.
	p.global_position = b.global_position + Vector3(0, 0, b.radius() + 1.0)
	for i in 10:
		b.receive_hit(1.0, p.global_position, 0.0, p)
	await _seconds(1.2)
	_check(brain.tactic == &"bristle" and b.thorns > 0.0, "brawling makes the boss bristle (%s)" % brain.tactic)
	var hp := p.health.hp
	b.receive_hit(1.0, p.global_position, 0.0, p)
	_check(p.health.hp < hp, "thorns hurt you back")
	# Shell at 2/3, enrage at 1/2.
	b.receive_hit(b.health.max_hp * 0.4 * (25.0 + b.health.defense) / 25.0, Vector3.ZERO, 0.0, p)
	_check(b.damage_taken_mult < 0.5, "shell phase raises armour")
	b.damage_taken_mult = 1.0
	b.receive_hit(b.health.max_hp * 0.2 * (25.0 + b.health.defense) / 25.0, Vector3.ZERO, 0.0, p)
	_check(brain._enraged, "enrage below half health")
	var before := get_tree().get_nodes_in_group("enemies").size()
	b.damage_taken_mult = 1.0
	while not b.is_dead():
		b.receive_hit(99999.0, Vector3.ZERO, 0.0, p)
	await _frames(3)
	_check(get_tree().get_nodes_in_group("enemies").size() >= before + 1, "splitter splits on death")
	_check(is_instance_valid(lv.portal), "generated boss opens a portal")
	lv.queue_free()
	await _frames(3)


func _test_modifiers() -> void:
	var l := GameState.level_at_depth(9).duplicate() as LevelData
	l.modifiers = [&"champions", &"armored", &"swarm", &"riptide"]
	var lv := _open_level(l, &"debra")
	var champs := 0
	for i in 40:
		var e := lv.spawn_enemy(l.enemy_list()[0], Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)))
		if e.is_champion:
			champs += 1
		_check(e.damage_taken_mult < 1.0, "armoured creatures resist damage")
	_check(champs > 0 and champs < 40, "champions modifier makes some elites (%d / 40)" % champs)
	await _frames(5)
	_check(Creature.water_current.length() > 0.5, "riptide pushes the water")
	lv.queue_free()
	await _frames(3)
	_check(Creature.water_current == Vector3.ZERO, "riptide stops when you leave")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)


func _test_screens() -> void:
	var sel: CrabSelect = load("res://scenes/select.tscn").instantiate()
	add_child(sel)
	await _frames(5)
	_check(sel.crabs.size() == 5, "crab select shows 5 starters")
	_check(sel.crabs[GameState.STARTERS.find(&"louise")].get_socket(Equipment.Socket.HEAD).get_child(0).name == "angler_lure", "crab select shows saved mutations")
	sel.queue_free()
	await _frames(2)
	for d in range(1, 9):
		GameState.mark_cleared(GameState.level_at_depth(d).id)
	var map: WorldMap = load("res://scenes/map.tscn").instantiate()
	add_child(map)
	await _frames(5)
	_check(map._buttons.size() == GameState.frontier_depth() + WorldMap.LOOKAHEAD, "map shows every depth so far plus 2 ahead (%d)" % map._buttons.size())
	_check(map._selected.depth == 9, "map opens on the frontier (depth %d)" % map._selected.depth)
	map.queue_free()
	await _frames(2)


# --- Helpers -------------------------------------------------------------------------

func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	_clear_projectiles()


func _clear_projectiles() -> void:
	for p in get_tree().get_nodes_in_group("projectiles"):
		p.queue_free()


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.global_transform * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout
