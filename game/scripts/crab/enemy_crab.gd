class_name EnemyCrab
extends Crab
## A crustacean enemy on the shared crab rig. It wears its CreatureData
## loadout, which is exactly what it can drop: every enemy is a parts catalogue.
## Brain: wander near spawn -> chase when the player is close -> attack with
## alternating claws (same CrabCombat as the player) -> drop a part on death.

const DESPAWN_DELAY := 1.6

var creature: CreatureData
var rng: RandomNumberGenerator
## Set by the level: multiplies HP and damage.
var difficulty := 1.0
var loot_luck := 0.0
## Stolen parts this one wears instead of its own, per socket (champions, chimera bosses).
## They become its drops too.
var extra_parts: Array[PartData] = []

var _home := Vector3.ZERO
var _wander_to := Vector3.ZERO
var _think := 0.0
var _aggro := false
var _alert_left := 0.0
var _next_side := 0
var _attack_delay := 0.0


func _ready() -> void:
	team = 1
	size = creature.size * size_mult * (1.25 if is_champion else 1.0)
	is_boss = (creature.boss or is_boss) and not not_boss
	if display_name == "":
		display_name = creature.display_name
	super._ready()
	add_to_group("enemies")
	base_hp = creature.base_hp * difficulty * hp_mult * (3.0 if is_champion else 1.0)
	damage_mult = creature.damage_mult * difficulty
	cooldown_mult = 1.6 if not is_boss else 1.25
	part_hp_factor = 0.25
	speed_mult = 0.75
	var lo := creature.loadout()
	for s in Equipment.SOCKET_COUNT:
		if s < extra_parts.size() and extra_parts[s] != null:
			lo[s] = extra_parts[s]
	equipment.load_loadout(lo, Rarity.Tier.COMMON)
	health.fill()
	if glow_overlay:
		_apply_glow()
	if rng == null:
		rng = RandomNumberGenerator.new()
	_home = global_position
	_wander_to = _home
	_aggro = is_boss
	face_now(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)))


func _physics_process(delta: float) -> void:
	if _dead or is_dashing() or ai_locked():
		physics_move(Vector3.ZERO, delta, false)
		return
	var player := get_tree().get_first_node_in_group("player") as PlayerCrab
	var wish := Vector3.ZERO
	_alert_left -= delta
	_attack_delay -= delta
	if player and not player.is_dead():
		var to := player.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < creature.aggro_range:
			_aggro = true
		elif d > creature.aggro_range * 2.5 and not is_boss and _alert_left <= 0.0:
			_aggro = false
		if _aggro:
			var dir := to / maxf(d, 0.01)
			var reach := combat.attack_range(_next_side) * maxf(size, 1.0) * 0.85 + player.radius()
			if creature.preferred_range > 0.0:
				reach = minf(reach, creature.preferred_range)
				if d < creature.preferred_range * 0.6:
					wish = -dir
			if d > reach:
				wish = dir
			if d <= reach + 0.2 and _attack_delay <= 0.0 and combat.is_ready(_next_side):
				combat.try_attack(_next_side, dir)
				_next_side = 1 - _next_side
				_attack_delay = rng.randf_range(0.25, 0.7) * (0.6 if is_boss else 1.0)
			physics_move(wish, delta, not combat.is_busy())
			if wish.length() < 0.1 and not combat.is_busy():
				face_now(facing.slerp(dir, minf(8.0 * delta, 1.0)))
			return
	elif _aggro:
		_aggro = false
	_think -= delta
	if _think <= 0.0:
		_think = rng.randf_range(1.5, 3.5)
		_wander_to = _home + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
	var w := _wander_to - global_position
	w.y = 0.0
	if w.length() > 0.4:
		wish = w.normalized() * 0.45
	physics_move(wish, delta)


func _on_hit(_amount: float, _source: Creature) -> void:
	_aggro = true


func _on_died() -> void:
	super._on_died()
	Loot.on_enemy_died(self, creature, rng, loot_luck, extra_parts)
	var tw := create_tween()
	tw.tween_interval(DESPAWN_DELAY * 0.6)
	tw.tween_property(self, "position:y", position.y - 0.8 * size, DESPAWN_DELAY * 0.4)
	tw.tween_callback(queue_free)


func alert() -> void:
	_aggro = true
	_alert_left = 8.0
