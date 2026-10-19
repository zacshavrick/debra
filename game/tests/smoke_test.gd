extends Node
## Headless smoke test. Exit code 0 = pass.
##   godot --headless --path game res://tests/smoke_test.tscn
## Mirrors the prototype's "done when" list (docs/DESIGN.md):
##  - every slot accepts any crustacean part with no misalignment
##  - killing an enemy drops a part with a rolled rarity
##  - equipping a part changes both appearance and a visible stat
##  - swapping arms changes how an attack works

var _failures: Array[String] = []
var arena: Arena
var player: PlayerCrab


func _ready() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	arena.rng.seed = 1234
	add_child(arena)
	arena.auto_spawn = false
	arena.rng.seed = 1234
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	player = arena.player
	await _frames(5)

	_test_data()
	await _test_sockets_and_alignment()
	await _test_movement()
	await _test_kill_drops_part()
	await _test_equip_changes_look_and_stats()
	await _test_claw_swap_changes_attack()
	await _test_enemy_fights_back()
	await _test_death_and_respawn()
	_test_rarity_roll()

	for f in _failures:
		printerr("FAIL: ", f)
	print("SMOKE TEST %s (%d failures)" % ["PASSED" if _failures.is_empty() else "FAILED", _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_data() -> void:
	var parts := PartCatalog.all_parts()
	_check(parts.size() >= 12, "part catalog loads (%d parts)" % parts.size())
	var ids := {}
	for p in parts:
		_check(not ids.has(p.id), "part id unique: %s" % p.id)
		ids[p.id] = true
		if p.slot == PartData.Slot.CLAW:
			_check(CrabCombat.STYLES.has(p.ability), "claw %s has a known attack style (%s)" % [p.id, p.ability])
	var creatures := PartCatalog.all_creatures()
	_check(creatures.size() >= 4, "creatures load (%d)" % creatures.size())
	for c in creatures:
		var lo := c.loadout()
		for s in Equipment.SOCKET_COUNT:
			_check(lo[s] != null and Equipment.accepts(s, lo[s].slot), "%s loadout fits socket %s" % [c.id, Equipment.SOCKET_NAMES[s]])
		for sp in c.special_drops:
			_check(sp is PartData and (sp as PartData).special, "%s special drop is flagged special" % c.id)


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
			await _seconds(0.3)   # let the equip "pop" tween settle
			var sock := body.get_socket(socket)
			_check(sock.get_child_count() == 1, "%s: one visual in %s" % [p.id, sock.name])
			var v := sock.get_child(0) as Node3D
			_check(v.transform.is_equal_approx(Transform3D.IDENTITY) or v.position.is_zero_approx(), "%s snaps to socket origin" % p.id)
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


func _test_kill_drops_part() -> void:
	var shore := PartCatalog.creature(&"shore_crab")
	var e := arena.spawn_enemy(shore, player.global_position + Vector3(0, 0, -6))
	await _frames(3)
	var before := get_tree().get_nodes_in_group("pickups").size()
	var guard := 0
	while not e.is_dead() and guard < 50:
		e.receive_hit(100.0, player.global_position, 0.0, player)
		guard += 1
	await _frames(3)
	var pickups := get_tree().get_nodes_in_group("pickups")
	_check(pickups.size() == before + 1, "a kill drops one part (%d -> %d)" % [before, pickups.size()])
	if pickups.size() > before:
		var pk := pickups[pickups.size() - 1] as PartPickup
		_check(pk.part.rarity >= Rarity.Tier.COMMON and pk.part.rarity <= Rarity.Tier.EPIC, "dropped part has a rolled rarity")
		_check(shore.drop_pool().has(pk.part.data), "drop comes from the creature's own parts (%s)" % pk.part.data.id)
		pk.queue_free()
	_check(player.kills == 1, "kill counted")
	await _seconds(DESPAWN_WAIT)


const DESPAWN_WAIT := 1.8


func _test_equip_changes_look_and_stats() -> void:
	var conch := PartInstance.new(PartCatalog.by_id(&"hermit_shell"), Rarity.Tier.EPIC)
	var pk := PartPickup.spawn(arena, player.global_position + player.facing * 0.5, conch, false)
	await _seconds(0.7)
	_check(player.focused_pickup == pk, "standing on a part focuses it")
	var hp_before := player.health.max_hp
	var def_before := player.health.defense
	PlayerInput.interact_pressed.emit(false)
	await _frames(2)
	_check(player.equipment.get_part(Equipment.Socket.SHELL) == conch, "interact equips the part")
	var shell_socket := player.body.get_socket(Equipment.Socket.SHELL)
	_check(shell_socket.get_child_count() >= 1 and shell_socket.get_child(shell_socket.get_child_count() - 1).name == "hermit_shell", "shell socket shows the new look")
	_check(player.health.max_hp > hp_before, "max HP went up (%.0f -> %.0f)" % [hp_before, player.health.max_hp])
	_check(player.health.defense > def_before, "DEF went up (%.1f -> %.1f)" % [def_before, player.health.defense])
	var dropped := false
	for n in get_tree().get_nodes_in_group("pickups"):
		if (n as PartPickup).part.data.id == &"debra_shell":
			dropped = true
	_check(dropped, "old shell dropped on the floor")


func _test_claw_swap_changes_attack() -> void:
	player.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(&"mantis_snapper")))
	await _seconds(0.7)
	var shots_before := get_tree().get_nodes_in_group("projectiles").size()
	PlayerInput.press_claw(PlayerInput.Claw.LEFT, 0.05)
	await _seconds(0.15)
	_check(player.combat.last_style[0] == &"snap", "snapper claw snaps (got %s)" % player.combat.last_style[0])
	_check(get_tree().get_nodes_in_group("projectiles").size() > shots_before, "snapper fires a bubble")
	player.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(&"hermit_crusher")))
	await _seconds(0.7)
	PlayerInput.press_claw(PlayerInput.Claw.LEFT, 0.05)
	await _seconds(0.1)
	_check(player.combat.last_style[0] == &"crush", "crusher claw crushes (got %s)" % player.combat.last_style[0])
	var crush_dmg := player.combat.damage_for(0)
	var pinch_dmg := player.combat.damage_for(1)
	_check(crush_dmg > pinch_dmg, "crusher hits harder than a pincer (%.1f vs %.1f)" % [crush_dmg, pinch_dmg])
	_check(player.combat.attack_range(0) > player.combat.attack_range(1) * 0.9, "crusher reach")
	await _seconds(1.2)


func _test_enemy_fights_back() -> void:
	player.global_position = Vector3(0, 0, 3)   # open ground, away from the healing home
	player.health.fill()
	var e := arena.spawn_enemy(PartCatalog.creature(&"shore_crab"), player.global_position + Vector3(1.5, 0, 0))
	var hp := player.health.hp
	await _seconds(2.5)
	_check(player.health.hp < hp, "enemies fight back (%.0f -> %.0f)" % [hp, player.health.hp])
	e.queue_free()
	await _frames(2)


func _test_death_and_respawn() -> void:
	player.global_position = Vector3(5, 0, 0)
	player.receive_hit(99999.0, player.global_position + Vector3.FORWARD, 0.0, null)
	_check(player.is_dead(), "player can die")
	await _seconds(PlayerCrab.RESPAWN_DELAY + 0.3)
	_check(not player.is_dead(), "player respawns")
	_check(player.global_position.distance_to(player.home_position) < 1.0, "respawn at home")
	_check(is_equal_approx(player.health.hp, player.health.max_hp), "respawn with full HP")


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


# --- Helpers -------------------------------------------------------------------------

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
