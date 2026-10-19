extends Node
## Renders preview screenshots (needs a window/GPU, not headless):
##   godot --path game res://tests/screenshot.tscn -- <out_dir>
## select, map, level_<id> (hand-made), gen_<biome> (generated depths with
## their chimera boss), creatures (every creature), fx (attack effects), mutant.

const SAVE := "user://screenshot_save.json"

var out_dir := "res://../docs/screenshots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.use_save_file(SAVE)
	GameState.choose_starter(&"debra")
	for d in range(1, 8):
		GameState.mark_cleared(GameState.level_at_depth(d).id)

	var sel: Node = load("res://scenes/select.tscn").instantiate()
	add_child(sel)
	await _seconds(1.2)
	await _shot("select")
	sel.queue_free()

	var map: Control = load("res://scenes/map.tscn").instantiate()
	add_child(map)
	await _seconds(0.8)
	await _shot("map")
	map.queue_free()
	await _seconds(0.1)

	var starters := [&"debra", &"saul", &"louise", &"marjorie", &"gary"]
	var i := 0
	for l in GameState.levels():
		await _level_shot(l, starters[i % starters.size()], "level_%s" % l.id, false)
		i += 1
	# One generated depth per new-ish biome, with its chimera boss in view.
	var seen := {}
	for depth in range(6, 80):
		var l := GameState.level_at_depth(depth)
		if seen.has(l.decor) or [&"shallows", &"kelp", &"reef"].has(l.decor):
			continue
		seen[l.decor] = true
		await _level_shot(l, starters[i % starters.size()], "gen_%s" % l.decor, true)
		i += 1
		if seen.size() >= 6:
			break

	# Creature lineup: every non-playable, non-boss creature in rows.
	var lvl: Level = load("res://scenes/level.tscn").instantiate()
	lvl.level = GameState.level(&"reef")
	lvl.persist = false
	add_child(lvl)
	lvl.auto_spawn = false
	lvl.hud.visible = false
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	lvl.player.global_position = Vector3(0, 0, 40)
	var labels := Node3D.new()
	lvl.add_child(labels)
	var n := 0
	for c in PartCatalog.all_creatures():
		if c.playable or c.boss:
			continue
		var pos := Vector3(-11.0 + (n % 9) * 2.75, 0, -8.0 + (n / 9) * 3.6)
		var e := lvl.spawn_enemy(c, pos, false)
		e.set_physics_process(false)
		e.face_now(Vector3(0.4, 0, 1))
		var lab := Label3D.new()
		lab.text = c.display_name
		lab.font_size = 30
		lab.outline_size = 8
		lab.pixel_size = 0.006
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.position = pos + Vector3(0, 0.25, 1.2)
		labels.add_child(lab)
		n += 1
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 55
	cam.global_position = Vector3(0, 14, 9.5)
	cam.look_at(Vector3(0, 0, -2.5))
	cam.make_current()
	await _seconds(1.0)
	await _shot("creatures")
	labels.queue_free()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()

	# Attack effects, caught mid-flash.
	var p2 := lvl.player
	p2.global_position = Vector3(0, 0, 0)
	cam.fov = 45
	cam.global_position = Vector3(0, 8, 6.5)
	cam.look_at(Vector3(0, 0, -0.5))
	await _seconds(0.3)
	FX.claw(lvl, Vector3(-3.5, 0.35, -1), Vector3(0, 0, -1), 2.0, 130, &"crush", 0)
	FX.claw(lvl, Vector3(-1.2, 0.35, -1), Vector3(0, 0, -1), 1.8, 70, &"cut", 0)
	FX.claw(lvl, Vector3(1.2, 0.35, -1), Vector3(0, 0, -1), 1.9, 90, &"bite", 0)
	FX.claw(lvl, Vector3(3.5, 0.35, -1), Vector3(0, 0, -1), 3.0, 40, &"lash", 0)
	FX.lightning(lvl, Vector3(-4, 0.6, 2), Vector3(-1, 0.6, 3), Color(0.5, 0.85, 1.0))
	FX.warn_circle(lvl, Vector3(2.5, 0, 2.5), 2.0, 1.0)
	FX.warn_lane(lvl, Vector3(-4, 0, -3.5), Vector3(1, 0, 0), 8.0, 0.8, 1.0)
	FX.shockwave(lvl, Vector3(0, 0, 2.2), 1.6, Color(1, 0.6, 0.2))
	await _frames(2)
	await _shot("fx")

	# Mutant close-up: a lobster wearing half the sea, tail and all.
	p2.face_now(Vector3(1, 0, 0.35))
	p2.equip_part(Equipment.Socket.SHELL, PartInstance.new(PartCatalog.by_id(&"urchin_shell"), Rarity.Tier.RARE, 9))
	p2.equip_part(Equipment.Socket.HEAD, PartInstance.new(PartCatalog.by_id(&"hammer_head"), Rarity.Tier.UNCOMMON, 9))
	p2.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(&"anemone_pom"), Rarity.Tier.EPIC, 9))
	p2.equip_part(Equipment.Socket.CLAW_R, PartInstance.new(PartCatalog.by_id(&"swordfish_bill")))
	p2.equip_part(Equipment.Socket.LEGS, PartInstance.new(PartCatalog.by_id(&"octo_tentacles")))
	p2.equip_part(Equipment.Socket.TAIL, PartInstance.new(PartCatalog.by_id(&"angler_tail")))
	for k in get_tree().get_nodes_in_group("pickups"):
		k.queue_free()
	cam.fov = 35
	cam.global_position = Vector3(0.5, 2.0, 3.6)
	cam.look_at(Vector3(0, 0.45, 0))
	await _seconds(0.8)
	await _shot("mutant")
	DirAccess.remove_absolute(SAVE)
	get_tree().quit()


func _level_shot(l: LevelData, starter: StringName, name_: String, with_boss: bool) -> void:
	var level: Level = load("res://scenes/level.tscn").instantiate()
	level.level = l
	level.starter = GameState.starter_data(starter)
	level.persist = false
	add_child(level)
	level.auto_spawn = false
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var p := level.player
	p.global_position = Vector3(0, 0, 3)
	level.camera.snap()
	var list := l.enemy_list()
	for k in mini(list.size(), 3 if with_boss else 4):
		var e := level.spawn_enemy(list[k], Vector3(-5.0 + k * 3.3, 0, 0.5 + (k % 2) * 1.5), false)
		e.lock_ai(99.0)
	if with_boss:
		var b := level.spawn_enemy(l.boss, Vector3(0, 0, -2.5), false, {"boss": true})
		b.lock_ai(99.0)
		level.boss = b
		level.hud._on_boss_spawned(b)
	PartPickup.spawn(level, Vector3(1.6, 0, 4.2), PartInstance.new(list[0].drop_pool()[0], mini(l.depth - 1, 3), l.depth))
	await _seconds(1.4)
	await _shot(name_)
	level.queue_free()
	await _seconds(0.1)


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name_ + ".png")
	img.save_png(path)
	print("saved ", path)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
