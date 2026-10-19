class_name Creature
extends CharacterBody3D
## Base for everything that fights: crustaceans (Crab, on the shared rig) and
## other sea creatures (Critter, with their own bodies). Owns health,
## movement with knockback, hit reactions and death. Group: "creatures".

signal died(creature: Creature)

const GRAVITY := 20.0
const BODY_RADIUS := 0.55

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
var display_name := ""

var health: Health

var _knock := Vector3.ZERO
var _stagger := 0.0
var _dead := false
var _shape: CollisionShape3D
var _poison_left := 0.0
var _poison_dps := 0.0
var _poison_tick := 0.0


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
	var dealt := health.take_hit(raw, source)
	if dealt <= 0.0:
		return 0.0
	var away := global_position - from
	away.y = 0.0
	var k := knock * (0.25 if is_boss else 1.0)
	_knock = away.normalized() * k if away.length() > 0.01 else Vector3.ZERO
	_stagger = 0.05 if is_boss else 0.12
	_flash()
	FX.number(get_parent(), global_position + Vector3(0, 1.1 * size, 0), dealt,
		Color(1, 0.35, 0.3) if team == 0 else Color(1, 0.95, 0.8))
	_on_hit(dealt, source)
	return dealt


## Damage over time (stingers). Re-applying refreshes and keeps the stronger dps.
func poison(dps: float, sec: float) -> void:
	if _dead:
		return
	_poison_dps = maxf(_poison_dps if _poison_left > 0.0 else 0.0, dps)
	_poison_left = maxf(_poison_left, sec)


## Moves with acceleration toward wish (length 0..1, world space) and turns to face it.
func physics_move(wish: Vector3, delta: float, turn_to_wish := true, speed_scale := 1.0) -> void:
	var target := wish * move_speed * speed_scale
	if _stagger > 0.0 or _dead:
		_stagger -= delta
		target = Vector3.ZERO
	var accel := 30.0 if wish.length() > 0.01 else 22.0
	var h := Vector3(velocity.x, 0, velocity.z).move_toward(target, accel * delta)
	_knock = _knock.move_toward(Vector3.ZERO, 25.0 * delta)
	velocity.x = h.x + _knock.x
	velocity.z = h.z + _knock.z
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
	_set_walk(0.0)
	_play_death()
	collision_layer = 0
	died.emit(self)


## Revive in place with full health (player respawn).
func revive() -> void:
	_dead = false
	collision_layer = 2
	_poison_left = 0.0
	_reset_pose()
	health.fill()


# --- Hooks for subclasses ---------------------------------------------------------

func _on_hit(_amount: float, _source: Creature) -> void:
	pass


func _flash() -> void:
	pass


func _set_walk(_amount: float) -> void:
	pass


func _play_death() -> void:
	pass


func _reset_pose() -> void:
	pass
