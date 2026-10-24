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
	GameState.choose_starter(&"debra")
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
	await _test_early_boss_pacing()
	await _test_move_abilities()
	await _test_props_and_title()
	_test_rarity_roll()
	level.queue_free()
	await _frames(3)
	await _test_objectives()
	await _test_boss_brain()
	await _test_modifiers()
	await _test_loot_tiers_mods_sets()
	await _test_shell_abilities()
	await _test_bag_inventory_and_expiry()

	await _test_screens()
	await _test_branching_and_dev_skip()

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
		_check(String(l.id) == "depth_%d_0" % depth, "depth %d id" % depth)
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
	_check(GameState.bag.any(func(p: PartInstance) -> bool: return p.data.id == &"debra_shell"), "the swapped-out shell went into the bag")


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
	var boss_at := Vector3.ZERO
	_check(is_instance_valid(level.boss), "reaching the kill goal brings the boss")
	if is_instance_valid(level.boss):
		_check(level.boss.is_boss and level.boss.size > 1.5, "the boss is big")
		_check(level.boss.get_node_or_null("BossBrain") != null, "the boss has a boss brain")
		boss_at = level.boss.global_position
		while not level.boss.is_dead():
			level.boss.receive_hit(1000.0, Vector3.ZERO, 0.0, player)
		await _frames(3)
	_check(level.is_cleared, "beating the boss clears the level")
	_check(GameState.is_cleared(&"shallows"), "clear is saved")
	_check(GameState.is_unlocked(&"kelp"), "clearing depth 1 unlocks depth 2")
	_check(not GameState.is_unlocked(&"reef"), "depth 3 still locked")
	_check(is_instance_valid(level.portal), "a portal opens after the boss dies")
	if is_instance_valid(level.portal):
		var gap := Vector2(level.portal.global_position.x - boss_at.x, level.portal.global_position.z - boss_at.z).length()
		_check(absf(gap - Level.PORTAL_DISTANCE) < 1.0, "...about 20 m from the boss (%.1f m)" % gap)
		_check(Vector2(level.portal.global_position.x, level.portal.global_position.z).length() <= level.level.radius - 1.9, "...inside the arena")
		_check(not level._blocked(level.portal.global_position), "...and not on a rock")
		level.portal.entered.disconnect(level.back_to_map)
		var used := [false]
		level.portal.entered.connect(func() -> void: used[0] = true)
		await _seconds(1.2)
		_check(not used[0], "the portal waits for you")
		player.global_position = level.portal.global_position
		await _seconds(0.5)
		_check(not used[0], "walking into the portal does NOT take it")
		PlayerInput.point_pressed.emit(Vector2(5, 5))
		await _frames(2)
		_check(not used[0], "clicking somewhere else doesn't take it")
		var cam := get_viewport().get_camera_3d()
		PlayerInput.point_pressed.emit(cam.unproject_position(level.portal.global_position + Vector3(0, 1.1, 0)))
		await _frames(2)
		_check(used[0], "clicking the portal takes it")
		used[0] = false
		level.portal._used = false
		player.global_position = level.portal.global_position + Vector3(Portal.USE_RANGE + 2.0, 0, 0)
		player._on_interact(false)
		_check(not used[0], "interact from far away doesn't take it")
		player.global_position = level.portal.global_position + Vector3(1.5, 0, 0)
		player._on_interact(false)
		_check(used[0], "interact (gamepad X / E) next to the portal takes it")
		for i in 6:   # wherever the boss dies, the portal lands ~20 m off, in the arena
			var at := Vector3(cos(i * 1.1), 0, sin(i * 1.1)) * (level.level.radius - 2.0) * (i / 5.0)
			var s := level.portal_spot(at)
			_check(absf(s.distance_to(at) - Level.PORTAL_DISTANCE) < 1.0 and s.length() <= level.level.radius - 1.9, "portal spot from %s is 20 m away (%.1f)" % [str(at), s.distance_to(at)])
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


## Every crab is its own saved game; NEW GAME starts one over; old saves migrate.
func _test_save_roundtrip() -> void:
	_check(GameState.starter == &"debra" and GameState.is_cleared(&"shallows"), "Debra's save has her progress")
	var debra_bag := GameState.bag.size()
	GameState.choose_starter(&"louise")
	_check(not GameState.is_cleared(&"shallows") and GameState.bag.is_empty(), "Louise starts with her own empty save")
	_check(GameState.has_save(&"debra") and int(GameState.slot_summary(&"debra").cleared) >= 1, "Debra's save is kept while you play Louise")
	var eq := Equipment.new()
	for s in Equipment.SOCKET_COUNT:
		eq.equip(s, GameState.loadout_for(&"louise")[s])
	eq.equip(Equipment.Socket.HEAD, PartInstance.new(PartCatalog.by_id(&"angler_lure"), Rarity.Tier.RARE, 7))
	GameState.store_loadout(&"louise", eq)
	eq.free()
	GameState.mark_cleared(&"shallows")
	GameState.add_to_bag(PartInstance.new(PartCatalog.by_id(&"shore_eyes")))
	GameState.load_game()
	_check(GameState.starter == &"louise", "the crab you were playing survives a reload")
	var head := GameState.loadout_for(&"louise")[Equipment.Socket.HEAD]
	_check(head.data.id == &"angler_lure" and head.rarity == Rarity.Tier.RARE and head.level == 7, "mutations survive a reload")
	_check(GameState.bag.size() == 1, "Louise's bag survives a reload")
	GameState.choose_starter(&"debra")
	_check(GameState.is_cleared(&"shallows") and GameState.bag.size() == debra_bag, "CONTINUE picks Debra's save back up")
	_check(GameState.loadout_for(&"debra")[Equipment.Socket.SHELL].data.id == &"hermit_shell", "Debra still wears what she wore")
	# New game wipes just that crab.
	GameState.choose_starter(&"saul")
	GameState.mark_cleared(&"shallows")
	GameState.add_to_bag(PartInstance.new(PartCatalog.by_id(&"shore_eyes")))
	GameState.new_game(&"saul")
	_check(GameState.starter == &"saul" and not GameState.is_cleared(&"shallows") and GameState.bag.is_empty(), "NEW GAME starts Saul over from the beginning")
	_check(GameState.loadout_for(&"saul")[Equipment.Socket.SHELL].data.id == &"saul_shell", "...in his starting gear")
	_check(int(GameState.slot_summary(&"debra").cleared) >= 1 and GameState.loadout_for(&"louise")[Equipment.Socket.HEAD].data.id == &"angler_lure", "...and nobody else's save changes")
	# A version-1 save (shared progress) migrates into the crab you were playing.
	var old_path := GameState.save_path
	GameState.save_path = "user://smoke_v1_save.json"
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "starter": "gary", "cleared": ["shallows", "kelp"],
		"loadouts": {"gary": [], "saul": []}, "bag": [{"id": "shore_eyes", "rarity": 2}], "stash": []}))
	f.close()
	GameState.load_game()
	_check(GameState.starter == &"gary" and GameState.is_cleared(&"kelp") and GameState.bag.size() == 1, "old saves move into the crab you were playing")
	_check(GameState.has_save(&"saul") and int(GameState.slot_summary(&"saul").cleared) == 0, "other crabs from an old save start without progress")
	DirAccess.remove_absolute(GameState.save_path)
	GameState.save_path = old_path
	GameState.load_game()
	GameState.choose_starter(&"louise")


## The first three depths' bosses leave more time between attacks.
func _test_early_boss_pacing() -> void:
	var paces: Array[float] = []
	for d in [1, 2, 3, 4]:
		paces.append(Level.early_boss_pace(d))
	_check(paces[0] > paces[1] and paces[1] > paces[2] and paces[2] > paces[3] and is_equal_approx(paces[3], 1.0), "boss pacing eases off over depths 1-3 %s" % str(paces))
	var lv := _open_level(GameState.level(&"shallows"), &"debra")
	var b := lv.spawn_boss()
	await _frames(2)
	_check(is_equal_approx(b.boss_pace, 2.0) and b.windup_mult > 1.3, "depth 1 boss is paced slower")
	_check(b.cooldown_mult >= 2.4, "depth 1 boss claws recharge twice as slowly (%.2f)" % b.cooldown_mult)
	var brain := lv.boss_brain
	var shallow_cd := b.cooldown_mult
	_check(brain._rush_t >= 5.9 and brain._slam_t >= 11.9, "its special moves start later too")
	lv.queue_free()
	await _frames(3)
	lv = _open_level(GameState.level(&"abyss"), &"debra")
	var deep := lv.spawn_boss()
	await _frames(2)
	_check(is_equal_approx(deep.boss_pace, 1.0) and deep.cooldown_mult < shallow_cd, "deep bosses keep full speed")
	lv.queue_free()
	await _frames(3)


func _test_rarity_roll() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 40000:
		counts[Rarity.roll(rng)] += 1
	_check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > 0, "rarity odds ordered %s" % str(counts))
	var lucky := [0, 0, 0, 0, 0, 0]
	for i in 40000:
		lucky[Rarity.roll(rng, 1.0)] += 1
	_check(lucky[3] > counts[3], "luck raises epic odds (%d vs %d)" % [lucky[3], counts[3]])
	_check(counts[5] < counts[4] and counts[5] < 60, "gold is much rarer than everything else (%d in 40000)" % counts[5])


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
	var expect := 0
	for d in range(1, GameState.frontier_depth() + WorldMap.LOOKAHEAD + 1):
		expect += GameState.branch_count(d)
	_check(map._buttons.size() == expect, "map shows every route so far plus 2 depths ahead (%d vs %d)" % [map._buttons.size(), expect])
	_check(map._selected.depth == 9, "map opens on the frontier (depth %d)" % map._selected.depth)
	map.queue_free()
	await _frames(2)


## Legendary/Gold tiers roll mods; mods do things; full sets turn on bonuses.
func _test_loot_tiers_mods_sets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var claw := PartCatalog.by_id(&"shore_pincer")
	var legendary_mods := true
	var gold_mods := true
	var debra := 0
	for i in 3000:
		var p := PartInstance.roll(claw, rng, 40.0, 5)   # absurd luck: lots of high tiers
		if p.rarity == Rarity.Tier.LEGENDARY and not Mods.REGULAR.has(p.mod):
			legendary_mods = false
		if p.rarity == Rarity.Tier.GOLD:
			if not Mods.GOLD.has(p.mod):
				gold_mods = false
			if p.data.set_id == &"debra":
				debra += 1
		if p.rarity < Rarity.Tier.LEGENDARY and p.mod != &"":
			legendary_mods = false
	_check(legendary_mods, "legendary parts always have a regular mod, lower tiers none")
	_check(gold_mods, "gold parts always have a unique gold mod")
	_check(debra > 0, "gold rolls sometimes become Golden Debra pieces (%d)" % debra)
	var back := PartInstance.from_dict(PartInstance.new(claw, Rarity.Tier.GOLD, 4, &"echo").to_dict())
	_check(back.mod == &"echo" and back.rarity == Rarity.Tier.GOLD, "mods survive the save format")

	var lv := _open_level(GameState.level_at(3, 0), &"saul")
	var p := lv.player
	p.global_position = Vector3.ZERO
	p.face_now(Vector3.FORWARD)
	# Echo: one claw press, two hits.
	p.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(claw, Rarity.Tier.GOLD, 1, &"echo"))
	var dummy := lv.spawn_enemy(PartCatalog.creature(&"giant_isopod"), Vector3(0, 0, -1.6), false)
	dummy.lock_ai(60.0)
	var hits := [0]
	dummy.health.damaged.connect(func(_a: float, _s: Node3D) -> void: hits[0] += 1)
	PlayerInput.set_override(Vector2.ZERO, Vector3.FORWARD)
	PlayerInput.press_claw(PlayerInput.Claw.LEFT, 0.05)
	await _seconds(0.6)
	PlayerInput.set_override(null)
	_check(hits[0] >= 2, "echo makes one strike hit twice (%d hits)" % hits[0])
	# Vampiric heals.
	p.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(claw, Rarity.Tier.LEGENDARY, 1, &"vampiric"))
	p.health.hp = p.health.max_hp * 0.5
	var hp0 := p.health.hp
	p.combat._cooldown[0] = 0.0
	p.combat.try_attack(0, Vector3.FORWARD)
	await _seconds(0.3)
	_check(p.health.hp > hp0, "vampiric heals on hit")
	# Detonate: a kill hurts things nearby.
	p.equip_part(Equipment.Socket.HEAD, PartInstance.new(PartCatalog.by_id(&"saul_eyes"), Rarity.Tier.GOLD, 1, &"detonate"))
	var near := lv.spawn_enemy(PartCatalog.creature(&"giant_isopod"), Vector3(1.2, 0, -1.6), false)
	near.lock_ai(60.0)
	var near_hp := near.health.hp
	while not dummy.is_dead():
		dummy.receive_hit(99999.0, p.global_position, 0.0, p)
	await _frames(2)
	_check(near.health.hp < near_hp, "detonate: a kill explodes into neighbours")
	near.queue_free()
	# Second wind: survive one killing blow.
	p.equip_part(Equipment.Socket.HEAD, PartInstance.new(PartCatalog.by_id(&"saul_eyes"), Rarity.Tier.GOLD, 1, &"second_wind"))
	p.receive_hit(1.0e7, p.global_position + Vector3.FORWARD, 0.0, null)
	_check(not p.is_dead() and p.health.hp > 0.0, "second wind saves you once")
	p.receive_hit(1.0e7, p.global_position + Vector3.FORWARD, 0.0, null)
	_check(p.is_dead(), "...only once")
	await _seconds(PlayerCrab.RESPAWN_DELAY + 0.3)

	# Sets: every Shore piece at Epic -> Shore set on, with its perk.
	var shore := Sets.pieces(&"shore")
	_check(shore.size() >= 4, "shore set has its pieces (%d)" % shore.size())
	for part in shore:
		var s: int = Equipment.sockets_for(part.slot)[0]
		p.equip_part(s, PartInstance.new(part, Rarity.Tier.RARE))
	_check(not p.active_sets.has(&"shore"), "a set below Epic doesn't count")
	var hp_before := p.health.max_hp
	for part in shore:
		var s: int = Equipment.sockets_for(part.slot)[0]
		p.equip_part(s, PartInstance.new(part, Rarity.Tier.EPIC))
	_check(p.active_sets.has(&"shore") and p.has_mod(&"swift"), "full Epic shore set turns on (with Swift)")
	# Debra at Gold = Headliner.
	var debra_set := Sets.pieces(&"debra")
	_check(debra_set.size() == 6, "the Debra set has 6 pieces (%d)" % debra_set.size())
	for part in debra_set:
		var s: int = Equipment.sockets_for(part.slot)[0]
		if part.id == &"debra_cutter":
			s = Equipment.Socket.CLAW_R
		p.equip_part(s, PartInstance.new(part, Rarity.Tier.EPIC))
	_check(not p.active_sets.has(&"debra"), "the Debra set needs Gold, Epic isn't enough")
	for part in debra_set:
		var s: int = Equipment.sockets_for(part.slot)[0]
		if part.id == &"debra_cutter":
			s = Equipment.Socket.CLAW_R
		p.equip_part(s, PartInstance.new(part, Rarity.Tier.GOLD))
	_check(p.active_sets.has(&"debra") and p.has_mod(&"echo") and p.has_mod(&"second_wind"), "full Gold Debra set: Headliner is on")
	_check(p.health.max_hp > hp_before * 1.5, "Headliner is a big boost (%.0f -> %.0f HP)" % [hp_before, p.health.max_hp])
	lv.queue_free()
	await _frames(3)
	GameState.bag.clear()


## Every shell has a spacebar ability, and the main ones work.
func _test_shell_abilities() -> void:
	for part in PartCatalog.all_parts():
		if part.slot == PartData.Slot.SHELL:
			_check(ShellAbility.ABILITIES.has(part.ability), "shell %s has a spacebar ability (%s)" % [part.id, part.ability])
	_check(PartCatalog.by_id(&"shark_fin").special and PartCatalog.by_id(&"shark_fin").ability == &"shark_dash", "shark fin = rare Shark Dash")
	_check(PartCatalog.by_id(&"shark_tail") == null, "shark tail is gone from the loot")
	var lv := _open_level(GameState.level_at(3, 0), &"saul")
	var p := lv.player
	var shell_for := {&"harden": &"saul_shell", &"shark_dash": &"shark_fin", &"shield": &"hermit_shell", &"cloak": &"mantis_carapace",
		&"spikes": &"urchin_shell", &"quake": &"coconut_shell", &"heal": &"starfish_shell", &"roll": &"isopod_shell"}
	for k in shell_for:
		p.global_position = Vector3.ZERO
		p.equip_part(Equipment.Socket.SHELL, PartInstance.new(PartCatalog.by_id(shell_for[k])))
		_check(p.shell_ability.kind() == k, "%s gives %s" % [shell_for[k], k])
		var dummy := lv.spawn_enemy(PartCatalog.creature(&"giant_isopod"), Vector3(0, 0, -2.0), false)
		dummy.lock_ai(60.0)
		await _frames(2)
		var start := p.global_position
		var hp_e := dummy.health.hp
		p.health.hp = p.health.max_hp * 0.5
		var hp_p := p.health.hp
		var shots := get_tree().get_nodes_in_group("projectiles").size()
		var use_dir := Vector3.RIGHT if k == &"roll" else Vector3.FORWARD
		_check(p.shell_ability.try_use(use_dir), "%s fires" % k)
		_check(not p.shell_ability.try_use(Vector3.FORWARD), "%s has a cooldown" % k)
		await _frames(3)
		match k:
			&"roll":
				await _seconds(0.3)
				_check(p.global_position.distance_to(start) > 1.0, "%s moves you" % k)
			&"harden":
				var before_h := p.health.hp
				p.receive_hit(20.0, Vector3(0, 0, -3), 0.0, null)
				_check(before_h - p.health.hp <= 20.0 * 0.45, "harden takes most of the sting out of a hit")
			&"shark_dash":
				await _seconds(0.5)
				_check(p.global_position.distance_to(start) > 4.0 and dummy.health.hp < hp_e, "shark dash goes far and rams")
			&"shield":
				var before := p.health.hp
				p.receive_hit(20.0, Vector3(0, 0, -3), 0.0, dummy)
				_check(before - p.health.hp < 20.0 * 0.4, "deflector blocks most damage")
				var shot := BubbleShot.fire(dummy, p.global_position + Vector3(0, 0.4, -1.4), Vector3.BACK, 5.0, 8.0, 5.0, Color.WHITE)
				for i in 8:   # the shot needs ~0.2 s to arrive; give slow frames some slack
					await _seconds(0.1)
					if not is_instance_valid(shot) or shot.team == p.team:
						break
				_check(not is_instance_valid(shot) or shot.team == p.team, "deflector bounces shots back")
			&"cloak":
				_check(p.cloaked, "cloak hides you")
				dummy.lock_ai(0.0)
				await _seconds(0.5)
				_check(not (dummy as EnemyCrab)._aggro, "enemies can't see a cloaked crab")
			&"spikes":
				_check(get_tree().get_nodes_in_group("projectiles").size() > shots + 8, "spike burst fires spines")
			&"quake":
				_check(dummy.health.hp < hp_e, "quake hits what's around you")
			&"heal":
				await _seconds(1.0)
				_check(p.health.hp > hp_p, "mend heals")
		await _seconds(0.7)
		dummy.queue_free()
		_clear_projectiles()
		p.shell_ability.cooldown_left = 0.0
		await _frames(2)
	# Passive tails: dodge, guard, mend.
	p.equip_part(Equipment.Socket.TAIL, PartInstance.new(PartCatalog.by_id(&"louise_tail")))
	_check(p.dodge_chance >= 0.2, "dodge tail gives a dodge chance")
	p.equip_part(Equipment.Socket.TAIL, PartInstance.new(PartCatalog.by_id(&"squat_tail")))
	_check(p.regen > 0.0, "mend tail regenerates")
	p.equip_part(Equipment.Socket.TAIL, PartInstance.new(PartCatalog.by_id(&"isopod_tail")))
	p.tail._timer = 0.0
	await _frames(3)
	var hp1 := p.health.hp
	p.receive_hit(10.0, p.global_position + Vector3.FORWARD, 0.0, null)
	_check(p.health.hp == hp1, "guard tail blocks the next hit")
	# Shark boss: its charge goes much further than a normal shark's.
	var reef_shark := PartCatalog.creature(&"reef_shark")
	var boss_shark := PartCatalog.creature(&"boss_reef_shark")
	var normal := lv.spawn_enemy(reef_shark, Vector3(-8, 0, 8), false)
	var big := lv.spawn_enemy(boss_shark, Vector3(8, 0, -8), false)
	await _frames(2)
	normal.lock_ai(5.0)
	big.lock_ai(5.0)
	CritterAttack.perform(normal as Critter, &"dash", Vector3.BACK, null)
	CritterAttack.perform(big as Critter, &"dash", Vector3.BACK, null)
	var dn := normal._dash_vel.length() * normal._dash_left   # planned charge length
	var db := big._dash_vel.length() * big._dash_left
	_check(db > dn * 1.8, "shark boss dashes much farther (%.1f vs %.1f)" % [db, dn])
	await _seconds(1.0)
	lv.queue_free()
	await _frames(3)


## Take to bag, inventory equip/store, loot expiry.
func _test_bag_inventory_and_expiry() -> void:
	GameState.bag.clear()
	GameState.stash.clear()
	var lv := _open_level(GameState.level_at(2, 0), &"debra")
	var p := lv.player
	p.global_position = Vector3.ZERO
	var part := PartInstance.new(PartCatalog.by_id(&"mantis_eyes"), Rarity.Tier.RARE, 2)
	var pk := PartPickup.spawn(lv, Vector3(0, 0, -0.4), part, false)
	await _seconds(0.7)
	_check(p.focused_pickup == pk, "standing on loot focuses it")
	PlayerInput.take_pressed.emit()
	await _frames(2)
	_check(GameState.bag.has(part), "take puts it in the bag")
	# Inventory: open, equip from bag, store at home.
	lv.open_inventory()
	await _frames(2)
	_check(is_instance_valid(lv.inventory) and get_tree().paused, "inventory opens and pauses")
	lv.inventory._select(part, -1)
	lv.inventory._equip(Equipment.Socket.HEAD)
	_check(p.equipment.get_part(Equipment.Socket.HEAD) == part and not GameState.bag.has(part), "equip from the bag")
	_check(GameState.bag.any(func(x: PartInstance) -> bool: return x.data.id == &"debra_eyes"), "the old head went to the bag")
	lv.inventory.close()
	await _frames(2)
	_check(not get_tree().paused, "closing unpauses")
	p.global_position = p.home_position
	lv.open_inventory()
	await _frames(2)
	_check(lv.inventory.at_home, "at the Coke can you see the stash")
	var old: PartInstance = GameState.bag[0]
	lv.inventory._select(old, -1)
	lv.inventory._move(true)
	_check(GameState.stash.has(old) and not GameState.bag.has(old), "move a part to the stash")
	lv.inventory.close()
	await _frames(2)
	GameState.load_game()
	_check(GameState.stash.size() == 1 and GameState.stash[0].data.id == &"debra_eyes", "the stash is saved")
	# Loot expires.
	var temp := PartPickup.spawn(lv, Vector3(5, 0, 5), PartInstance.new(PartCatalog.by_id(&"shore_eyes")), false)
	_check(temp.life == PartPickup.LIFETIME and is_equal_approx(PartPickup.LIFETIME, 20.0), "loot lasts 20 seconds")
	temp.life = 0.3
	await _seconds(0.7)
	_check(not is_instance_valid(temp), "loot disappears when its time runs out")
	lv.queue_free()
	await _frames(3)


## The chart branches; clearing one route unlocks the levels it leads to. Dev skip works.
func _test_branching_and_dev_skip() -> void:
	var orphans := 0
	var childless := 0
	for d in range(2, 40):
		var n := GameState.branch_count(d)
		_check(n >= 2 and n <= 3, "depth %d has 2-3 routes (%d)" % [d, n])
		for b in n:
			if GameState.parents(d, b).is_empty():
				orphans += 1
		for pb in GameState.branch_count(d - 1):
			var has_child := false
			for b in n:
				if GameState.parents(d, b).has(pb):
					has_child = true
			if not has_child:
				childless += 1
	_check(orphans == 0, "every level has a way in (%d orphans)" % orphans)
	_check(childless == 0, "every level leads somewhere (%d dead ends)" % childless)
	_check(GameState.level_at(9, 0).boss_name != GameState.level_at(9, 1).boss_name, "routes at the same depth differ")
	GameState.use_save_file(TEST_SAVE)
	GameState.mark_cleared(GameState.level_at(1, 0).id)
	_check(GameState.is_unlocked(GameState.level_at(2, 0).id) and GameState.is_unlocked(GameState.level_at(2, 1).id), "depth 1 opens both routes at depth 2")
	var side := GameState.level_at(2, 1)
	GameState.mark_cleared(side.id)
	var kids := 0
	for b in GameState.branch_count(3):
		if GameState.is_unlocked(GameState.level_at(3, b).id):
			kids += 1
			_check(GameState.parents(3, b).has(1), "only routes linked to the cleared one unlock")
	_check(kids >= 1, "clearing a side route unlocks the next depth")
	_check(GameState.level(&"depth_7") == GameState.level_at(7, 0), "old depth_N ids still resolve")
	# Dev skip inside a level
	var lv := _open_level(GameState.level_at(2, 0), &"gary")
	lv.dev_skip()
	await _frames(3)
	_check(lv.is_cleared and is_instance_valid(lv.portal), "dev skip clears the level and opens the portal")
	lv.queue_free()
	await _frames(3)


## Every starter's own movement move: charges, cooldowns, patterns.
func _test_move_abilities() -> void:
	var expect := {&"gary": [&"leap", 1, 0.9], &"saul": [&"scuttle", 3, 0.9], &"debra": [&"lunge", 2, 0.9],
		&"marjorie": [&"arc", 2, 0.9], &"louise": [&"shimmy", 4, 0.6]}
	for id in expect:
		var e: Array = expect[id]
		var c := GameState.starter_data(id)
		_check(c.move_ability == e[0], "%s's move is %s (%s)" % [id, e[0], c.move_ability])
		var m: Dictionary = MoveAbility.MOVES[e[0]]
		_check(int(m.charges) == int(e[1]) and is_equal_approx(float(m.cooldown), float(e[2])), "%s: %d charges, %.0f s" % [id, e[1], e[2]])
	# Saul zigzags forward: Right, Right, Left, Left.
	var lv := _open_level(GameState.level(&"shallows"), &"saul")
	var p := lv.player
	var mv := p.move_ability
	var sides: Array[float] = []
	var ahead := 0
	for i in 4:
		p.global_position = Vector3(0, 0, 0)
		p.face_now(Vector3.FORWARD)
		mv.charges = mv.max_charges()
		var x0 := p.global_position.x
		_check(mv.try_use(Vector3.ZERO), "scuttle %d fires" % i)
		await _seconds(0.35)
		sides.append(signf(p.global_position.x - x0))
		if p.global_position.z < -1.0:   # forward is -Z
			ahead += 1
	_check(sides == [1.0, 1.0, -1.0, -1.0], "Saul scuttles R, R, L, L (%s)" % str(sides))
	_check(ahead == 4, "...and every scuttle carries him forward (%d of 4)" % ahead)
	# Charges run out and refill one per cooldown.
	mv.charges = 3
	mv._recharge = 0.0
	for i in 3:
		mv.try_use(Vector3.ZERO)
		await _seconds(0.26)   # just past the 0.24 s scuttle
	_check(mv.charges == 0 and not mv.try_use(Vector3.ZERO), "out of charges after 3 scuttles")
	await _seconds(0.5)
	_check(mv.charges == 1, "one charge back after 0.9 seconds (%d)" % mv.charges)
	lv.queue_free()
	await _frames(3)
	# Louise: Forward, Forward, Back, Forward.
	lv = _open_level(GameState.level(&"shallows"), &"louise")
	p = lv.player
	mv = p.move_ability
	var steps: Array[float] = []
	for i in 4:
		p.global_position = Vector3(0, 0, 0)
		p.face_now(Vector3.FORWARD)
		var z0 := p.global_position.z
		mv.try_use(Vector3.ZERO)
		await _seconds(0.3)
		steps.append(-signf(p.global_position.z - z0))   # forward is -Z
	_check(steps == [1.0, 1.0, -1.0, 1.0], "Louise shimmies F, F, B, F (%s)" % str(steps))
	lv.queue_free()
	await _frames(3)
	# Debra: a long forward lunge.
	lv = _open_level(GameState.level(&"shallows"), &"debra")
	p = lv.player
	p.global_position = Vector3(0, 0, 0)
	p.face_now(Vector3.RIGHT)
	p.move_ability.try_use(Vector3.ZERO)
	await _seconds(0.5)
	_check(p.global_position.x > 5.0, "Debra lunges far forward (%.1f)" % p.global_position.x)
	lv.queue_free()
	await _frames(3)
	# Marjorie: an arc that bends her path.
	lv = _open_level(GameState.level(&"shallows"), &"marjorie")
	p = lv.player
	p.global_position = Vector3(0, 0, 0)
	p.face_now(Vector3.RIGHT)
	p.move_ability.try_use(Vector3.ZERO)
	await _seconds(0.6)
	_check(absf(p.global_position.z) > 1.0 and p.global_position.x > 1.5, "Marjorie's dash curves (%s)" % str(p.global_position))
	_check(p.facing.angle_to(Vector3.RIGHT) > 1.0, "...and turns her around the arc")
	lv.queue_free()
	await _frames(3)
	# Gary: a long jump over a creature, untouchable in the air.
	lv = _open_level(GameState.level(&"shallows"), &"gary")
	p = lv.player
	p.global_position = Vector3(0, 0, 0)
	p.face_now(Vector3.RIGHT)
	var wall := lv.spawn_enemy(PartCatalog.creature(&"giant_isopod"), Vector3(2.5, 0, 0), false)
	wall.lock_ai(30.0)
	LevelBuilder._solid(lv, Vector3(6, 0, 0), 1.2)   # a rock in the way too
	await _frames(2)
	p.move_ability.try_use(Vector3.ZERO)
	await _frames(5)
	_check(p.airborne, "Gary is in the air")
	var hp := p.health.hp
	p.receive_hit(50.0, p.global_position + Vector3.LEFT, 0.0, null)
	_check(p.health.hp == hp, "nothing hits Gary mid-jump")
	await _seconds(1.8)
	_check(not p.airborne and p.global_position.x > 15.0 and p.global_position.x < 32.0, "Gary jumped way past the isopod and the rock (x %.1f)" % p.global_position.x)
	_check(Vector2(p.global_position.x, p.global_position.z).length() <= lv.level.radius, "...and landed inside the arena")
	lv.queue_free()
	await _frames(3)


## Props build, and the title screen has creatures scuttling past.
func _test_props_and_title() -> void:
	var d := RandomNumberGenerator.new()
	d.seed = 11
	for k in Props.KINDS:
		var prop := Props.build(k, d)
		_check(prop != null and prop.find_children("*", "MeshInstance3D", true, false).size() > 0, "prop %s builds" % k)
		if prop:
			prop.free()
	var sel: CrabSelect = load("res://scenes/select.tscn").instantiate()
	add_child(sel)
	await _frames(5)
	_check(sel._parade.size() >= 3, "creatures parade past the title screen (%d)" % sel._parade.size())
	var first: Node3D = sel._parade[0].node
	var x0 := first.position.x
	await _seconds(0.5)
	_check(is_instance_valid(first) and absf(first.position.x - x0) > 0.2, "...and they move")
	sel.queue_free()
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
