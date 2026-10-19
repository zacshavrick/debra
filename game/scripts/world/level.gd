class_name Level
extends Node3D
## A playable level (scenes/level.tscn). Reads GameState.current_level and
## GameState.starter, builds the arena, and runs the loop:
##   kill `kill_goal` creatures -> the boss arrives -> beat it -> level cleared
##   (next level unlocks). Creatures keep coming after the clear.
## Home is a Coke can at the north edge: you start and respawn there, and it heals.
##
## Dev keys (prototype): F1 random part, F2 spawn a creature, F3 heal, F4 summon the boss.

signal progress_changed
signal boss_spawned(boss: Creature)
signal cleared(unlocked_next: bool)

const RESPAWN_DELAY := 2.5

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
var is_cleared := false

var _boss_called := false
var _spawn_timer := 1.0
var _home_pos := Vector3.ZERO


func _ready() -> void:
	rng.randomize()
	if level == null:
		level = GameState.level(GameState.current_level)
	if level == null:
		level = GameState.levels()[0]
	if starter == null:
		starter = GameState.starter_data(GameState.starter if GameState.starter != &"" else &"debra")
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
	touch_layer.add_child(TouchControls.new())
	PlayerInput.debug_pressed.connect(_on_debug)
	PlayerInput.menu_pressed.connect(back_to_map)
	for i in 3:
		spawn_enemy(_pick_creature(), spawn_point())
	hud.toast(level.display_name, Color(1, 0.85, 0.6), 3.0)


func _exit_tree() -> void:
	if PlayerInput.debug_pressed.is_connected(_on_debug):
		PlayerInput.debug_pressed.disconnect(_on_debug)
	if PlayerInput.menu_pressed.is_connected(back_to_map):
		PlayerInput.menu_pressed.disconnect(back_to_map)


func back_to_map() -> void:
	GameState.go_to_map()


func _physics_process(delta: float) -> void:
	if not auto_spawn:
		return
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e as Creature).is_dead() and not (e as Creature).is_boss:
			alive += 1
	var cap := level.max_alive if not is_instance_valid(boss) or boss.is_dead() else maxi(level.max_alive / 2, 2)
	if alive < cap:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = RESPAWN_DELAY
			spawn_enemy(_pick_creature(), spawn_point())


## track = false: not counted towards the kill goal / boss (tests, debug).
func spawn_enemy(creature: CreatureData, pos: Vector3, track := true) -> Creature:
	var e: Creature
	if creature.is_crustacean():
		var c := EnemyCrab.new()
		c.creature = creature
		c.rng = rng
		c.difficulty = level.difficulty
		c.loot_luck = level.rarity_luck
		e = c
	else:
		var k := Critter.new()
		k.creature = creature
		k.rng = rng
		k.difficulty = level.difficulty
		k.loot_luck = level.rarity_luck
		e = k
	e.position = pos
	add_child(e)
	if track:
		e.died.connect(_on_enemy_died)
	return e


func spawn_boss() -> Creature:
	_boss_called = true
	var pos := Vector3(0, 0, level.radius * 0.5)
	boss = spawn_enemy(level.boss, pos)
	boss_spawned.emit(boss)
	hud.toast("%s appears!" % level.boss.display_name, Color(1, 0.5, 0.4), 3.0)
	return boss


func _on_enemy_died(c: Creature) -> void:
	if c.is_boss:
		_on_boss_died()
		return
	kills += 1
	progress_changed.emit()
	if kills >= level.kill_goal and not _boss_called and not is_cleared:
		spawn_boss()


func _on_boss_died() -> void:
	var first := not is_cleared
	is_cleared = true
	var unlocked := false
	if persist:
		unlocked = GameState.mark_cleared(level.id)
	progress_changed.emit()
	if first:
		cleared.emit(unlocked)


func _pick_creature() -> CreatureData:
	var list := level.enemy_list()
	var w := PackedFloat32Array()
	for c in list:
		w.append(c.spawn_weight)
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
			var part := PartInstance.new(parts[rng.randi() % parts.size()], Rarity.roll(rng, 1.0))
			PartPickup.spawn(self, player.global_position + player.facing * 1.2, part)
		KEY_F2:
			spawn_enemy(_pick_creature(), player.global_position + player.facing * 6.0)
		KEY_F3:
			player.health.fill()
		KEY_F4:
			if not is_instance_valid(boss):
				spawn_boss()
