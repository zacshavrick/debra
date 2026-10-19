extends Node
## Renders preview screenshots (needs a window/GPU, not headless):
##   godot --path game res://tests/screenshot.tscn -- <out_dir>
## gameplay.png  arena with enemies and drops of every rarity
## mutant.png    Debra wearing parts from three different creatures
## parts.png     every part in the catalogue, by slot

var out_dir := "res://../docs/screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if not a.begins_with("--"):
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	var arena: Arena = load("res://scenes/main.tscn").instantiate()
	add_child(arena)
	arena.auto_spawn = false
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var p := arena.player
	p.global_position = Vector3(0, 0, 4)
	arena.camera.snap()
	arena.spawn_enemy(PartCatalog.creature(&"shore_crab"), Vector3(-3.5, 0, -1))
	arena.spawn_enemy(PartCatalog.creature(&"hermit_crab"), Vector3(4, 0, -2))
	arena.spawn_enemy(PartCatalog.creature(&"mantis_shrimp"), Vector3(0.5, 0, -5))
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as EnemyCrab).creature.aggro_range = 0.0
	var drops := [&"shore_shell", &"hermit_crusher", &"mantis_eyes", &"hermit_pearl_shell"]
	for i in drops.size():
		PartPickup.spawn(arena, Vector3(-3 + i * 2.0, 0, 6.5), PartInstance.new(PartCatalog.by_id(drops[i]), i))
	p.global_position = Vector3(-1, 0, 6.3)
	await _seconds(1.5)
	await _shot("gameplay")
	PlayerInput._set_scheme(PlayerInput.Scheme.TOUCH)
	await _seconds(0.2)
	await _shot("touch")
	PlayerInput._set_scheme(PlayerInput.Scheme.KEYBOARD_MOUSE)

	# Mutant close-up
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for n in get_tree().get_nodes_in_group("pickups"):
		n.queue_free()
	p.global_position = Vector3(0, 0, 0)
	p.face_now(Vector3(0.6, 0, 1))
	p.equip_part(Equipment.Socket.SHELL, PartInstance.new(PartCatalog.by_id(&"hermit_shell"), Rarity.Tier.RARE))
	p.equip_part(Equipment.Socket.HEAD, PartInstance.new(PartCatalog.by_id(&"mantis_eyes"), Rarity.Tier.UNCOMMON))
	p.equip_part(Equipment.Socket.CLAW_L, PartInstance.new(PartCatalog.by_id(&"hermit_crusher"), Rarity.Tier.EPIC))
	p.equip_part(Equipment.Socket.CLAW_R, PartInstance.new(PartCatalog.by_id(&"mantis_snapper")))
	p.equip_part(Equipment.Socket.LEGS, PartInstance.new(PartCatalog.by_id(&"shore_legs")))
	for n in get_tree().get_nodes_in_group("pickups"):
		n.queue_free()
	arena.hud.visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 35
	cam.global_position = Vector3(1.6, 1.9, 3.2)
	cam.look_at(Vector3(0, 0.45, 0))
	cam.make_current()
	await _seconds(0.8)
	await _shot("mutant")

	# Parts lineup: one row per slot
	p.global_position = Vector3(0, 0, 40)
	var lineup := Node3D.new()
	lineup.position = Vector3(0, 0, -10)
	arena.add_child(lineup)
	var rows := {}
	for part in PartCatalog.all_parts():
		var row: int = part.slot
		var col: int = rows.get(row, 0)
		rows[row] = col + 1
		var v := PartVisual.build(PartInstance.new(part), 1)
		v.position = Vector3(col * 1.6 - (0.25 if row == PartData.Slot.CLAW else 0.0), 0.47 if row == PartData.Slot.LEGS else 0.4, row * 1.8)
		lineup.add_child(v)
		var l := Label3D.new()
		l.text = part.display_name
		l.font_size = 28
		l.outline_size = 8
		l.pixel_size = 0.005
		l.rotation_degrees.x = -50
		l.position = Vector3(col * 1.6, 0.05, row * 1.8 + 0.75)
		lineup.add_child(l)
	cam.global_position = Vector3(3.2, 7.5, 1.0)
	cam.fov = 50
	cam.look_at(Vector3(3.2, 0, -5.0))
	await _seconds(0.5)
	await _shot("parts")
	get_tree().quit()


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name_ + ".png")
	img.save_png(path)
	print("saved ", path)


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout
