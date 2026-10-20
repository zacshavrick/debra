class_name Critter
extends Creature
## A non-crustacean sea creature: its own procedural body (CritterVisual),
## one attack (CritterAttack) and a behaviour:
##   melee     chase and attack up close
##   ranged    keep `preferred_range` and shoot
##   charger   close in, wind up, charge through you
##   drifter   slowly float at you, sting with a pulse when close
##   turret    never moves; fires when you're in range
##   ambusher  sits still until you come close, then behaves like a charger
## Drops only its CreatureData.drops (1-2 parts for limited slots).

const DESPAWN_DELAY := 1.6

var creature: CreatureData
var rng: RandomNumberGenerator
var difficulty := 1.0
var loot_luck := 0.0
var visual: Node3D
## Parts it carries as extra loot (champions, chimera bosses).
var stolen: Array[PartData] = []
## The attack in use (bosses may switch it).
var attack: StringName

var _t := 0.0
var _home := Vector3.ZERO
var _wander_to := Vector3.ZERO
var _think := 0.0
var _aggro := false
var _alert_left := 0.0
var _cooldown := 1.0
var _windup := 0.0
var _windup_total := 0.0
var _flash_left := 0.0
static var _flash_mat: StandardMaterial3D


func _ready() -> void:
	team = 1
	size = creature.size * size_mult * (1.25 if is_champion else 1.0)
	is_boss = (creature.boss or is_boss) and not not_boss
	if display_name == "":
		display_name = creature.display_name
	attack = creature.attack
	super._ready()
	add_to_group("enemies")
	base_hp = creature.base_hp * difficulty * hp_mult * (3.0 if is_champion else 1.0)
	damage_mult = creature.damage_mult * difficulty
	move_speed = creature.speed
	health.set_max(base_hp)
	health.fill()
	if rng == null:
		rng = RandomNumberGenerator.new()
	visual = CritterVisual.build(creature.body_kind, creature.color, creature.accent)
	visual.scale = Vector3.ONE * size
	visual.position.y = hover_height()
	add_child(visual)
	if glow_overlay:
		_apply_glow()
	_home = global_position
	_wander_to = _home
	_aggro = is_boss
	_cooldown = rng.randf_range(0.5, 1.5)
	face_now(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))


func hover_height() -> float:
	return creature.hover * size


func _process(delta: float) -> void:
	_t += delta
	var charge := 1.0 - _windup / _windup_total if _windup > 0.0 and _windup_total > 0.0 else 0.0
	if not _dead:
		CritterVisual.animate(visual, _t, clampf(Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.1), 0.0, 1.0), charge)
		visual.position.y = hover_height() + (sin(_t * 1.5) * 0.08 if creature.hover > 0.0 else 0.0)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_overlay(visual, glow_overlay)


func _physics_process(delta: float) -> void:
	if _dead or is_dashing() or ai_locked():
		physics_move(Vector3.ZERO, delta, false)
		return
	_cooldown -= delta
	var player := get_tree().get_first_node_in_group("player") as PlayerCrab
	var wish := Vector3.ZERO
	_alert_left -= delta
	var b := creature.behaviour
	if player and not player.is_dead() and not player.cloaked:
		var to := player.global_position - global_position
		to.y = 0.0
		var d := to.length()
		var dir := to / maxf(d, 0.01)
		if d < creature.aggro_range:
			_aggro = true
		elif d > creature.aggro_range * 2.5 and not is_boss and _alert_left <= 0.0:
			_aggro = false
		if _aggro:
			# Winding up: stand still, track the target, then strike.
			if _windup > 0.0:
				_windup -= delta
				face_now(dir)
				if _windup <= 0.0:
					CritterAttack.perform(self, attack, dir, player)
				physics_move(Vector3.ZERO, delta, false)
				return
			var a := CritterAttack.info(attack)
			var reach: float = float(a.range) * maxf(size, 1.0) * 0.85 * (CritterAttack.dash_reach(self) if [&"dash", &"pierce"].has(attack) else 1.0) + player.radius()
			match b:
				&"turret":
					pass
				&"ranged":
					var keep := creature.preferred_range if creature.preferred_range > 0.0 else 6.0
					if d > keep + 1.0:
						wish = dir
					elif d < keep - 1.5:
						wish = -dir
					else:
						wish = dir.rotated(Vector3.UP, PI * 0.5) * 0.4   # strafe
				&"drifter":
					wish = dir * 0.7 if d > reach * 0.6 else Vector3.ZERO
				_:
					wish = dir if d > reach * 0.8 else Vector3.ZERO
			if d <= reach and _cooldown <= 0.0:
				begin_attack(attack, dir)
			physics_move(wish, delta, true)
			if wish.length() < 0.1:
				face_now(facing.slerp(dir, minf(6.0 * delta, 1.0)))
			return
	if b == &"turret" or b == &"ambusher":
		physics_move(Vector3.ZERO, delta, false)
		return
	_think -= delta
	if _think <= 0.0:
		_think = rng.randf_range(1.5, 3.5)
		_wander_to = _home + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
	var w := _wander_to - global_position
	w.y = 0.0
	if w.length() > 0.4:
		wish = w.normalized() * 0.45
	physics_move(wish, delta)


## Starts an attack's windup (bosses call this with other attacks too).
func begin_attack(id: StringName, dir: Vector3) -> void:
	var a := CritterAttack.info(id)
	_windup_total = float(a.windup) * (0.75 if is_boss else 1.0) * cooldown_mult
	_windup = _windup_total
	_cooldown = float(a.cooldown) * (0.7 if is_boss else 1.0) * cooldown_mult
	attack = id
	CritterAttack.telegraph(self, id, dir, _windup_total)


func _on_hit(_amount: float, _source: Creature) -> void:
	_aggro = true


func _flash() -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.albedo_color = Color(1, 1, 1, 0.65)
	_set_overlay(visual, _flash_mat)
	_flash_left = 0.08


func _apply_glow() -> void:
	if visual:
		_set_overlay(visual, glow_overlay)


func _set_overlay(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = m
	for ch in n.get_children():
		_set_overlay(ch, m)


func _play_death() -> void:
	_windup = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(visual, "rotation:z", PI, 0.4)
	tw.tween_property(visual, "position:y", hover_height() + 0.4, 0.4)


func _on_died() -> void:
	super._on_died()
	Loot.on_enemy_died(self, creature, rng, loot_luck, stolen)
	var tw := create_tween()
	tw.tween_interval(DESPAWN_DELAY * 0.6)
	tw.tween_property(visual, "scale", Vector3.ONE * 0.01, DESPAWN_DELAY * 0.4)
	tw.tween_callback(queue_free)


func alert() -> void:
	_aggro = true
	_alert_left = 8.0
