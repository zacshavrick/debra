class_name Creature
extends CharacterBody3D
## Base for everything that fights: crustaceans (Crab, on the shared rig) and
## other sea creatures (Critter, with their own bodies). Owns health,
## movement with knockback, dashes, poison, thorns, hit reactions and death.
## Group: "creatures".

signal died(creature: Creature)

const GRAVITY := 20.0
const BODY_RADIUS := 0.55

## Riptide modifier: a current that pushes every creature (set by the level).
static var water_current := Vector3.ZERO

## 0 = player side, 1 = sea creatures.
var team := 0
## Visual + collision scale relative to Debra-sized crabs.
var size := 1.0
var base_hp := 50.0
var damage_mult := 1.0
var cooldown_mult := 1.0
var move_speed := 3.0
## World-space facing on the ground plane.
var facing := Vector3.FORWARD
## Bosses get a HUD bar and resist knockback.
var is_boss := false
## Champions: elite versions of normal creatures (glow, tougher, always drop).
var is_champion := false
## Marked targets for the Hunt objective.
var is_marked := false
var display_name := ""
## Multiplies incoming damage (boss shell phase, armoured modifier).
var damage_taken_mult := 1.0
## Fraction of melee damage reflected back at attackers standing close.
var thorns := 0.0
## Hits from this creature poison (Venom tide): damage per second for 3 s.
var venom := 0.0
## Part level of anything this creature drops.
var drop_level := 1
## Set by the level before spawning: size / HP multipliers, and "never a boss" (split pieces).
var size_mult := 1.0
var hp_mult := 1.0
var not_boss := false
## Permanent overlay (dark water / champion glow); hit flashes return to it.
var glow_overlay: Material
## 0..1: how much knockback is ignored (Colossus).
var knock_resist := 0.0
## Fraction of max HP healed per second (Regen).
var regen := 0.0
## Chance to slip out of a hit entirely (Dodge tail).
var dodge_chance := 0.0
## Hits fully blocked before taking damage (Guard tail).
var guard_charges := 0
## Deflector shield up: projectiles bounce back.
var reflecting := false
## Cloaked: enemies can't see you.
var cloaked := false

var health: Health

var _knock := Vector3.ZERO
var _stagger := 0.0
var _dead := false
var _shape: CollisionShape3D
var _poison_left := 0.0
var _poison_dps := 0.0
var _poison_tick := 0.0
## While > 0 the creature's own AI stands down (boss specials, scripted moves).
var _ai_lock := 0.0
var _dash_left := 0.0
var _dash_vel := Vector3.ZERO
var _dash_dmg := 0.0
var _dash_knock := 0.0
var _dash_hit: Array[Creature] = []
var _dash_pierce := false
var _slow_left := 0.0
var _slow_mult := 1.0
var _last_hitter: Creature


func _ready() -> void:
	add_to_group("creatures")
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = 0.3
	_shape = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BODY_RADIUS * size
	cyl.height = 0.8 * size
	_shape.shape = cyl
	_shape.position.y = 0.45 * size
	add_child(_shape)
	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.died.connect(_on_died)


func is_dead() -> bool:
	return _dead


func radius() -> float:
	return BODY_RADIUS * size


func is_dashing() -> bool:
	return _dash_left > 0.0


## Lock out the creature's own AI for `sec` (bosses use it for special moves).
func lock_ai(sec: float) -> void:
	_ai_lock = maxf(_ai_lock, sec)


func ai_locked() -> bool:
	return _ai_lock > 0.0


## Turn instantly (attacks).
func face_now(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	facing = dir.normalized()
	rotation.y = atan2(-facing.x, -facing.z)


func receive_hit(raw: float, from: Vector3, knock: float, source: Creature) -> float:
	if _dead:
		return 0.0
	if dodge_chance > 0.0 and randf() < dodge_chance:
		FX.burst(get_parent(), global_position + Vector3(0, 0.5, 0), Color(0.8, 0.95, 1.0), 6, 2.0, 0.05)
		return 0.0
	if guard_charges > 0:
		guard_charges -= 1
		FX.ring(get_parent(), global_position + Vector3(0, 0.4, 0), radius() * 2.2, Color(1.0, 0.9, 0.5))
		return 0.0
	var dealt := health.take_hit(raw * damage_taken_mult, source)
	if dealt <= 0.0:
		return 0.0
	var away := global_position - from
	away.y = 0.0
	var k := knock * (0.25 if is_boss else 1.0) * (1.0 - knock_resist)
	_knock = away.normalized() * k if away.length() > 0.01 else Vector3.ZERO
	_stagger = 0.05 if is_boss else 0.12
	_flash()
	FX.number(get_parent(), global_position + Vector3(0, 1.1 * size, 0), dealt,
		Color(1, 0.35, 0.3) if team == 0 else Color(1, 0.95, 0.8))
	FX.burst(get_parent(), global_position + Vector3(0, 0.5 * size, 0), Color(1, 0.9, 0.7), 5, 2.5, 0.05)
	if is_instance_valid(source):
		_last_hitter = source
		source._on_dealt_hit(self, dealt)
	if is_instance_valid(source) and not source.is_dead():
		if source.venom > 0.0:
			poison(source.venom, 3.0)
		if thorns > 0.0 and source.global_position.distance_to(global_position) < 3.5 * maxf(size, 1.0):
			source.receive_hit(dealt * thorns, global_position, 2.0, null)
	_on_hit(dealt, source)
	return dealt


## Damage over time (stingers, jellies). Re-applying refreshes and keeps the stronger dps.
func poison(dps: float, sec: float) -> void:
	if _dead:
		return
	_poison_dps = maxf(_poison_dps if _poison_left > 0.0 else 0.0, dps)
	_poison_left = maxf(_poison_left, sec)


## Charge in a straight line. dmg > 0 hits enemies along the way, once each.
## pierce = keep going through everything (otherwise stop on the first hit).
func start_dash(dir: Vector3, spd: float, sec: float, dmg := 0.0, knock := 0.0, pierce := true) -> void:
	_dash_vel = Vector3(dir.x, 0, dir.z).normalized() * spd
	_dash_left = sec
	_dash_dmg = dmg
	_dash_knock = knock
	_dash_pierce = pierce
	_dash_hit.clear()
	face_now(dir)


func _dash_step(delta: float) -> void:
	_dash_left -= delta
	velocity = Vector3(_dash_vel.x, 0, _dash_vel.z)
	move_and_slide()
	_set_walk(1.0)
	if _dash_dmg > 0.0:
		for t in Melee.targets(self, global_position, _dash_vel, radius() + 0.4, 360.0):
			if _dash_hit.has(t):
				continue
			_dash_hit.append(t)
			t.receive_hit(_dash_dmg, global_position, _dash_knock, self)
			if not _dash_pierce:
				_dash_left = 0.0
	if _dash_left <= 0.0:
		velocity = Vector3.ZERO


## Moves with acceleration toward wish (length 0..1, world space) and turns to face it.
func physics_move(wish: Vector3, delta: float, turn_to_wish := true, speed_scale := 1.0) -> void:
	_ai_lock = maxf(_ai_lock - delta, 0.0)
	if is_dashing():
		_dash_step(delta)
		_tick_poison(delta)
		return
	if _slow_left > 0.0:
		_slow_left -= delta
		speed_scale *= _slow_mult
	if regen > 0.0 and not _dead:
		health.heal(health.max_hp * regen * delta)
	var target := wish * move_speed * speed_scale
	if _stagger > 0.0 or _dead:
		_stagger -= delta
		target = Vector3.ZERO
	var accel := 30.0 if wish.length() > 0.01 else 22.0
	var h := Vector3(velocity.x, 0, velocity.z) - water_current
	h = h.move_toward(target, accel * delta)
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * delta)
	var drift := water_current if not _dead else Vector3.ZERO
	velocity.x = h.x + _knock.x + drift.x
	velocity.z = h.z + _knock.z + drift.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_set_walk(h.length() / maxf(move_speed, 0.1))
	if turn_to_wish and wish.length() > 0.1 and not _dead:
		var want := atan2(-wish.x, -wish.z)
		rotation.y = rotate_toward(rotation.y, want, 12.0 * delta)
		facing = Vector3(-sin(rotation.y), 0, -cos(rotation.y))
	_tick_poison(delta)


func _tick_poison(delta: float) -> void:
	if _poison_left <= 0.0 or _dead:
		return
	_poison_left -= delta
	_poison_tick -= delta
	if _poison_tick <= 0.0:
		_poison_tick = 0.5
		var dealt := health.take_hit(_poison_dps * 0.5 * (25.0 + health.defense) / 25.0, null)   # poison ignores DEF
		FX.number(get_parent(), global_position + Vector3(0, 1.0 * size, 0), dealt, Color(0.6, 1.0, 0.3))


func _on_died() -> void:
	_dead = true
	_knock = Vector3.ZERO
	_poison_left = 0.0
	_dash_left = 0.0
	_set_walk(0.0)
	_play_death()
	collision_layer = 0
	died.emit(self)
	if is_instance_valid(_last_hitter) and not _last_hitter.is_dead():
		_last_hitter._on_killed(self)


## Revive in place with full health (player respawn).
func revive() -> void:
	_dead = false
	collision_layer = 2
	_poison_left = 0.0
	_reset_pose()
	health.fill()


## Makes this creature an elite: bigger, tougher, glowing, guaranteed loot.
func make_champion(col := Color(1.0, 0.8, 0.2)) -> void:
	is_champion = true
	glow_overlay = glow_material(col)
	_apply_glow()


static func glow_material(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col, 0.22)
	return m


# --- Hooks for subclasses ---------------------------------------------------------

## Slow down (Frost): move at `mult` speed for `sec`.
func slow(mult: float, sec: float) -> void:
	_slow_mult = minf(_slow_mult if _slow_left > 0.0 else 1.0, mult)
	_slow_left = maxf(_slow_left, sec)


## Called on the attacker after it damages something (mods hook in here).
func _on_dealt_hit(_target: Creature, _dealt: float) -> void:
	pass


## Called on whoever landed the killing blow.
func _on_killed(_victim: Creature) -> void:
	pass


## Something (a lure tail, a boss summon) wants this creature to come and fight.
func alert() -> void:
	pass


func _on_hit(_amount: float, _source: Creature) -> void:
	pass


func _flash() -> void:
	pass


func _apply_glow() -> void:
	pass


func _set_walk(_amount: float) -> void:
	pass


func _play_death() -> void:
	pass


func _reset_pose() -> void:
	pass
