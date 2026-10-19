extends Node
## Headless smoke test. Exit code 0 = pass.
##   godot --headless --path game res://tests/smoke_test.tscn
## Covers the prototype "done when" list plus milestone 2 (levels, map,
## starters, sea creatures). Uses a throwaway save file.

const TEST_SAVE := "user://smoke_test_save.json"
const BEHAVIOURS := [&"melee", &"ranged", &"charger", &"drifter", &"turret", &"ambusher"]

var _failures: Array[String] = []
var level: Level
var player: PlayerCrab


func _ready() -> void:
	GameState.use_save_file(TEST_SAVE)
	_test_data()
	await _test_sockets_and_alignment()

	level = load("res://scenes/level.tscn").instantiate()
	level.level = GameState.level(&"shallows")
	level.starter = GameState.starter_data(&"debra")
	add_child(level)
	level.auto_spawn = false
	level.rng.seed = 1234
	_clear_enemies()
	player = level.player
	await _frames(5)
	_check(player.display_name == "Debra the Lobster", "Debra is the lobster (%s)" % player.display_name)

	await _test_movement()
	await _test_every_creature()
	await _test_equip_changes_look_and_stats()
	await _test_claw_styles()
	await _test_enemies_fight_back()
	await _test_level_flow()
	await _test_death_and_respawn()
	_test_save_roundtrip()
	_test_rarity_roll()
	level.queue_free()
	await _frames(3)
	await _test_screens()

	DirAccess.remove_absolute(TEST_SAVE)
	for f in _failures:
		printerr("FAIL: ", f)
	print("SMOKE TEST %s (%d failures)" % ["PASSED" if _failures.is_empty() else "FAILED", _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_data() -> void:
	var parts := PartCatalog.all_parts()
	_check(parts.size() >= 60, "part catalog loads (%d parts)" % parts.size())
	var ids := {}
	for p in parts:
		_check(not ids.has(p.id), "part id unique: %s" % p.id)
		ids[p.id] = true
		if p.slot == PartData.Slot.CLAW:
			_check(CrabCombat.STYLES.has(p.ability), "claw %s has a known attack style (%s)" % [p.id, p.ability])
	var creatures := PartCatalog.all_creatures()
	_check(creatures.size() >= 25, "creatures load (%d)" % creatures.size())
	var critters := 0
	for c in creatures:
		if c.is_crustacean():
			var lo := c.loadout()
			for s in Equipment.SOCKET_COUNT:
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
	_check(critters >= 10, "at least 10 non-crustacean creatures (%d)" % critters)
	for id in GameState.STARTERS:
		var s := GameState.starter_data(id)
		_check(s != null and s.playable and s.is_crustacean(), "starter %s exists and is a playable crustacean" % id)
	var names := ""
	for id in GameState.STARTERS:
		names += GameState.starter_data(id).display_name + ","
	for want in ["Saul the Crab", "Debra the Lobster", "Louise the Shrimp"]:
		_check(names.contains(want), "starter roster has %s" % want)
	var levels := GameState.levels()
	_check(levels.size() == 5, "5 levels (%d)" % levels.size())
	for i in levels.size():
		var l := levels[i]
		_check(l.order == i, "level %s order %d" % [l.id, l.order])
		_check(not l.enemy_list().is_empty(), "level %s has creatures" % l.id)
		_check(l.boss != null and l.boss.boss, "level %s has a boss" % l.id)
		for e in l.enemy_list():
			_check(not e.playable and not e.boss, "level %s enemy %s is a regular creature" % [l.id, e.id])
	_check(GameState.is_unlocked(&"shallows") and not GameState.is_unlocked(&"kelp"), "fresh save: only level 1 unlocked")


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
			await _seconds(0.28)   # let the equip "pop" tween settle
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
			_check(pk.part.rarity >= 0 and pk.part.rarity <= Rarity.Tier.EPIC, "%s drop has a rolled rarity" % c.id)
		for i in range(before, pickups.size()):
			pickups[i].remove_from_group("pickups")
			pickups[i].queue_free()
		player.health.fill()
	await _seconds(1.8)
	level.boss = null
	level.kills = 0
	_clear_enemies()
	_check(player.kills > 20, "kills counted (%d)" % player.kills)


func _test_equip_changes_look_and_stats() -> void:
	player.global_position = Vector3(0, 0, 0)
	var conch := PartInstance.new(PartCatalog.by_id(&"hermit_shell"), Rarity.Tier.EPIC)
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
	var dropped := false
	for n in get_tree().get_nodes_in_group("pickups"):
		if (n as PartPickup).part.data.id == &"debra_shell":
			dropped = true
	_check(dropped, "old shell dropped on the floor")
	_check(GameState.loadout_for(&"debra")[Equipment.Socket.SHELL].data.id == &"hermit_shell", "mutation saved for Debra")


func _test_claw_styles() -> void:
	player.global_position = Vector3(0, 0, 0)
	player.face_now(Vector3.FORWARD)
	var claws := {&"pinch": &"saul_pincer", &"crush": &"hermit_crusher", &"snap": &"mantis_snapper", &"cut": &"lobster_cutter",
		&"bite": &"shark_jaw", &"lash": &"spider_arm", &"sting": &"ray_stinger"}
	for style in claws:
		player.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(claws[style])))
		await _seconds(0.3)
		var dist := 5.0 if style == &"snap" else 1.6
		var dummy := level.spawn_enemy(PartCatalog.creature(&"giant_isopod"), player.global_position + Vector3(0, 0, -dist), false)
		dummy.creature.aggro_range = 0.0
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
		dummy.creature.aggro_range = 6.0
		dummy.queue_free()
		await _seconds(0.9)
	player.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(&"spider_arm")))
	player.equip_part(Equipment.Socket.CLAW_R, PartInstance.new(PartCatalog.by_id(&"saul_pincer")))
	_check(player.combat.attack_range(0) > player.combat.attack_range(1) * 1.5, "lash reaches further than a pincer")
	player.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(&"hermit_crusher")))
	_check(player.combat.damage_for(0) > player.combat.damage_for(1), "crusher hits harder than a pincer")
	_clear_enemies()


func _test_enemies_fight_back() -> void:
	for id in [&"shore_crab", &"octopus", &"moray_eel", &"jellyfish"]:
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


func _test_level_flow() -> void:
	_check(not GameState.is_unlocked(&"kelp"), "kelp locked before the clear")
	level.kills = level.level.kill_goal - 1
	var e := level.spawn_enemy(PartCatalog.creature(&"shore_crab"), Vector3(6, 0, 6))
	await _frames(2)
	e.receive_hit(1000.0, Vector3.ZERO, 0.0, player)
	await _frames(3)
	_check(is_instance_valid(level.boss), "reaching the kill goal brings the boss")
	if is_instance_valid(level.boss):
		_check(level.boss.is_boss and level.boss.size > 1.5, "the boss is big")
		while not level.boss.is_dead():
			level.boss.receive_hit(1000.0, Vector3.ZERO, 0.0, player)
		await _frames(3)
	_check(level.is_cleared, "beating the boss clears the level")
	_check(GameState.is_cleared(&"shallows"), "clear is saved")
	_check(GameState.is_unlocked(&"kelp"), "clearing level 1 unlocks level 2")
	_check(not GameState.is_unlocked(&"reef"), "level 3 still locked")
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
	eq.equip(Equipment.Socket.HEAD, PartInstance.new(PartCatalog.by_id(&"angler_lure"), Rarity.Tier.RARE))
	GameState.store_loadout(&"louise", eq)
	eq.free()
	GameState.load_game()
	_check(GameState.starter == &"louise", "starter survives a reload")
	var head := GameState.loadout_for(&"louise")[Equipment.Socket.HEAD]
	_check(head.data.id == &"angler_lure" and head.rarity == Rarity.Tier.RARE, "mutations survive a reload")
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


func _test_screens() -> void:
	var sel: CrabSelect = load("res://scenes/select.tscn").instantiate()
	add_child(sel)
	await _frames(5)
	_check(sel.crabs.size() == 5, "crab select shows 5 starters")
	_check(sel.crabs[GameState.STARTERS.find(&"louise")].get_socket(Equipment.Socket.HEAD).get_child(0).name == "angler_lure", "crab select shows saved mutations")
	sel.queue_free()
	await _frames(2)
	var map: WorldMap = load("res://scenes/map.tscn").instantiate()
	add_child(map)
	await _frames(5)
	_check(map.get_child_count() > 5, "world map builds")
	map.queue_free()
	await _frames(2)


# --- Helpers -------------------------------------------------------------------------

func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
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
