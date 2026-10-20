class_name Crab
extends Creature
## Every crustacean (player and enemies): the shared rig, equipment, stats
## from parts (+ set bonuses + mods), claw combat, the tail's own brain and the
## shell's spacebar ability. Subclasses (PlayerCrab, EnemyCrab) add the brain.

const BASE_SPEED := 3.0
const SPEED_PER_POINT := 0.4

## How much of the parts' HP bonus counts (enemies get less, or shells make them sponges).
var part_hp_factor := 1.0
var speed_mult := 1.0

var body: CrabBody
var equipment: Equipment
var combat: CrabCombat
var tail: TailBrain
var shell_ability: ShellAbility
## {mod: count} from worn parts + completed sets (see Mods, Sets).
var active_mods: Dictionary = {}
## Completed set ids.
var active_sets: Array[StringName] = []
## Damage multiplier from mods and sets (CrabCombat reads it).
var gear_damage_mult := 1.0
var _second_wind_used := false


func _ready() -> void:
	super._ready()
	add_to_group("crabs")
	body = CrabBody.new()
	body.name = "Body"
	body.scale = Vector3.ONE * size
	add_child(body)
	equipment = Equipment.new()
	equipment.name = "Equipment"
	add_child(equipment)
	combat = CrabCombat.new()
	combat.name = "Combat"
	combat.crab = self
	add_child(combat)
	equipment.changed.connect(_on_equipment_changed)
	tail = TailBrain.new()
	tail.name = "Tail"
	tail.crab = self
	add_child(tail)
	shell_ability = ShellAbility.new()
	shell_ability.name = "ShellAbility"
	shell_ability.crab = self
	add_child(shell_ability)
	health.cheat_death = _try_second_wind


func has_mod(id: StringName) -> bool:
	return active_mods.has(id)


func mod_count(id: StringName) -> int:
	return int(active_mods.get(id, 0))


func _on_equipment_changed(socket: int) -> void:
	body.show_part(socket, equipment.get_displayed(socket))
	apply_stats()


func apply_stats() -> void:
	active_mods = Sets.perks(equipment)
	for s in Equipment.SOCKET_COUNT:
		var p := equipment.get_part(s)
		if p and p.mod != &"":
			active_mods[p.mod] = int(active_mods.get(p.mod, 0)) + 1
	active_sets = Sets.active(equipment)
	var set_mult := Sets.stat_mult(equipment)
	var m := Mods.stat_mults(active_mods)
	health.set_max((base_hp + equipment.total(&"max_hp") * part_hp_factor * set_mult) * float(m.max_hp))
	health.defense = equipment.total(&"defense") * set_mult
	move_speed = maxf(1.5, BASE_SPEED + equipment.total(&"speed") * SPEED_PER_POINT) * speed_mult * float(m.speed)
	gear_damage_mult = float(m.damage) * set_mult
	thorns = 0.15 * mod_count(&"thorns")
	regen = 0.01 * mod_count(&"regen")
	knock_resist = 1.0 if has_mod(&"colossus") else 0.0
	# Passive tails
	var tail_part := equipment.get_part(Equipment.Socket.TAIL)
	var tail_kind: StringName = tail_part.data.ability if tail_part else &""
	dodge_chance = minf(0.2 + 0.02 * tail_part.rarity, 0.35) if tail_kind == &"dodge" else 0.0
	if tail_kind == &"regen":
		regen += 0.008 + 0.002 * tail_part.rarity
	if tail_kind != &"guard":
		guard_charges = 0
	if body:
		body.scale = Vector3.ONE * size * (1.2 if has_mod(&"colossus") else 1.0)


func _on_dealt_hit(target: Creature, dealt: float) -> void:
	if not active_mods.is_empty():
		Mods.on_hit(self, target, dealt, active_mods)


func _on_killed(victim: Creature) -> void:
	if not active_mods.is_empty():
		Mods.on_kill(self, victim, active_mods)


func _try_second_wind() -> bool:
	if not has_mod(&"second_wind") or _second_wind_used:
		return false
	_second_wind_used = true
	FX.shockwave(get_parent(), global_position, 3.0, Color(1, 0.9, 0.5))
	return true


func _flash() -> void:
	body.flash()


func _set_walk(amount: float) -> void:
	if body:
		body.walk_amount = amount


func _play_death() -> void:
	body.play_death()


func _reset_pose() -> void:
	body.reset_pose()


func _apply_glow() -> void:
	if body:
		body.base_overlay = glow_overlay
		body._set_overlay(body, glow_overlay)
