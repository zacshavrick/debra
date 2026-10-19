class_name Crab
extends CharacterBody3D
## Shared base for every crustacean (player and enemies): the rig, equipment,
## health, combat, movement with knockback, and stats from parts.
## Built in code; subclasses (PlayerCrab, EnemyCrab) add the brain.

signal died(crab: Crab)

const BASE_SPEED := 3.0
const SPEED_PER_POINT := 0.4
const GRAVITY := 20.0
const BODY_RADIUS := 0.55

## 0 = player side, 1 = sea creatures.
var team := 0
## Visual + collision scale relative to Debra.
var size := 1.0
var base_hp := 50.0
var damage_mult := 1.0
var cooldown_mult := 1.0
## How much of the parts' HP bonus counts (enemies get less, or shells make them sponges).
var part_hp_factor := 1.0
var move_speed := BASE_SPEED
## World-space facing on the ground plane.
var facing := Vector3.FORWARD

var body: CrabBody
var equipment: Equipment
var health: Health
var combat: CrabCombat

var _knock := Vector3.ZERO
var _stagger := 0.0
var _dead := false
var _shape: CollisionShape3D


func _ready() -> void:
	add_to_group("crabs")
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
	body = CrabBody.new()
	body.name = "Body"
	body.scale = Vector3.ONE * size
	add_child(body)
	equipment = Equipment.new()
	equipment.name = "Equipment"
	add_child(equipment)
	health = Health.new()
	health.name = "Health"
	add_child(health)
	combat = CrabCombat.new()
	combat.name = "Combat"
	combat.crab = self
	add_child(combat)
	equipment.changed.connect(_on_equipment_changed)
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


func receive_hit(raw: float, from: Vector3, knock: float, source: Crab) -> void:
	if _dead:
		return
	var dealt := health.take_hit(raw, source)
	if dealt <= 0.0:
		return
	var away := global_position - from
	away.y = 0.0
	_knock = away.normalized() * knock if away.length() > 0.01 else Vector3.ZERO
	_stagger = 0.12
	body.flash()
	FX.number(get_parent(), global_position + Vector3(0, 1.1 * size, 0), dealt,
		Color(1, 0.35, 0.3) if team == 0 else Color(1, 0.95, 0.8))
	_on_hit(dealt, source)


## Moves with acceleration toward wish (length 0..1, world space) and turns to face it.
func physics_move(wish: Vector3, delta: float, turn_to_wish := true) -> void:
	var target := wish * move_speed
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
	body.walk_amount = h.length() / maxf(move_speed, 0.1)
	if turn_to_wish and wish.length() > 0.1 and not _dead:
		var want := atan2(-wish.x, -wish.z)
		rotation.y = rotate_toward(rotation.y, want, 12.0 * delta)
		facing = Vector3(-sin(rotation.y), 0, -cos(rotation.y))


func _on_equipment_changed(socket: int) -> void:
	body.show_part(socket, equipment.get_displayed(socket))
	apply_stats()


func apply_stats() -> void:
	health.set_max(base_hp + equipment.total(&"max_hp") * part_hp_factor)
	health.defense = equipment.total(&"defense")
	move_speed = maxf(1.5, BASE_SPEED + equipment.total(&"speed") * SPEED_PER_POINT)


func _on_died() -> void:
	_dead = true
	_knock = Vector3.ZERO
	body.walk_amount = 0.0
	body.play_death()
	collision_layer = 0
	died.emit(self)


## Revive in place with full health (player respawn).
func revive() -> void:
	_dead = false
	collision_layer = 2
	body.reset_pose()
	health.fill()


## Hook for subclasses (aggro, hit reactions).
func _on_hit(_amount: float, _source: Crab) -> void:
	pass
