extends Node
## Renders preview screenshots (needs a window/GPU, not headless):
##   godot --path game res://tests/screenshot.tscn -- <out_dir>
## select.png, map.png, level_<id>.png (every level), creatures.png, mutant.png

const SAVE := "user://screenshot_save.json"

var out_dir := "res://../docs/screenshots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.use_save_file(SAVE)
	GameState.choose_starter(&"debra")
	GameState.mark_cleared(&"shallows")
	GameState.mark_cleared(&"kelp")

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
		var level: Level = load("res://scenes/level.tscn").instantiate()
		level.level = l
		level.starter = GameState.starter_data(starters[i % starters.size()])
		level.persist = false
		add_child(level)
		level.auto_spawn = false
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		var p := level.player
		p.global_position = Vector3(0, 0, 2)
		level.camera.snap()
		var list := l.enemy_list()
		for k in mini(list.size(), 4):
			var e := level.spawn_enemy(list[k], Vector3(-4.5 + k * 3.0, 0, -2.5 + (k % 2) * 1.5), false)
			if e is Critter:
				(e as Critter).creature.aggro_range = 0.0
			else:
				(e as EnemyCrab).creature.aggro_range = 0.0
		PartPickup.spawn(level, Vector3(1.6, 0, 3.2), PartInstance.new(list[0].drop_pool()[0], mini(i, 3)))
		await _seconds(1.4)
		await _shot("level_%s" % l.id)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Critter:
				(e as Critter).creature.aggro_range = 8.0
			else:
				(e as EnemyCrab).creature.aggro_range = 7.0
		level.queue_free()
		await _seconds(0.1)
		i += 1

	# Creature lineup: every non-playable creature in rows.
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
		var pos := Vector3(-8.0 + (n % 7) * 2.7, 0, -6.0 + (n / 7) * 3.2)
		var e := lvl.spawn_enemy(c, pos, false)
		e.set_physics_process(false)
		e.face_now(Vector3(0.4, 0, 1))
		var lab := Label3D.new()
		lab.text = c.display_name
		lab.font_size = 34
		lab.outline_size = 8
		lab.pixel_size = 0.006
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.position = pos + Vector3(0, 0.25, 1.1)
		labels.add_child(lab)
		n += 1
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 50
	cam.global_position = Vector3(0, 11, 9.5)
	cam.look_at(Vector3(0, 0, -1.5))
	cam.make_current()
	await _seconds(1.0)
	await _shot("creatures")

	# Mutant close-up: a lobster wearing half the sea.
	labels.queue_free()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var p2 := lvl.player
	p2.global_position = Vector3(0, 0, 0)
	p2.face_now(Vector3(0.6, 0, 1))
	p2.equip_part(Equipment.Socket.SHELL, PartInstance.new(PartCatalog.by_id(&"urchin_shell"), Rarity.Tier.RARE))
	p2.equip_part(Equipment.Socket.HEAD, PartInstance.new(PartCatalog.by_id(&"angler_lure"), Rarity.Tier.UNCOMMON))
	p2.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(&"shark_jaw"), Rarity.Tier.EPIC))
	p2.equip_part(Equipment.Socket.CLAW_R, PartInstance.new(PartCatalog.by_id(&"ray_stinger")))
	p2.equip_part(Equipment.Socket.LEGS, PartInstance.new(PartCatalog.by_id(&"octo_tentacles")))
	for k in get_tree().get_nodes_in_group("pickups"):
		k.queue_free()
	cam.fov = 35
	cam.global_position = Vector3(1.6, 1.9, 3.2)
	cam.look_at(Vector3(0, 0.45, 0))
	await _seconds(0.8)
	await _shot("mutant")
	DirAccess.remove_absolute(SAVE)
	get_tree().quit()


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name_ + ".png")
	img.save_png(path)
	print("saved ", path)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
