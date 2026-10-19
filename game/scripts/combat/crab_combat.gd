class_name CrabCombat
extends Node
## COMBAT ITERATION #1: "each claw is an attack".
## Left claw = attack 1, right claw = attack 2. The claw part's `ability`
## picks the style; the claw's rarity and the crab's total ATK scale damage.
## Swapping a claw therefore changes how you fight.
##
## Combat will be prototyped 3-4 times. Keep every combat rule in this folder
## and talk to the rest of the game only through Creature.receive_hit(),
## CrabBody.play_attack() and Equipment.

signal attacked(side: int, style: StringName)

## hits > 1 = several quick strikes. heal = fraction of damage dealt returned
## as HP. poison = damage per second for 3 s.
const STYLES := {
	&"pinch": {"damage": 6.0, "cooldown": 0.35, "windup": 0.06, "range": 1.7, "arc": 80.0, "knock": 2.0,
		"info": "Pinch: quick jabs"},
	&"crush": {"damage": 16.0, "cooldown": 1.0, "windup": 0.3, "range": 2.1, "arc": 130.0, "knock": 7.0,
		"info": "Crush: slow, heavy, knocks back"},
	&"snap": {"damage": 7.0, "cooldown": 0.6, "windup": 0.08, "range": 9.0, "knock": 2.5, "projectile_speed": 15.0,
		"info": "Snap: ranged bubble shot"},
	&"cut": {"damage": 4.5, "cooldown": 0.5, "windup": 0.05, "range": 1.8, "arc": 70.0, "knock": 1.0, "hits": 2,
		"info": "Cut: fast double slice"},
	&"bite": {"damage": 11.0, "cooldown": 0.8, "windup": 0.18, "range": 1.9, "arc": 90.0, "knock": 3.0, "heal": 0.3,
		"info": "Bite: heals you for 30% of damage"},
	&"lash": {"damage": 8.0, "cooldown": 0.75, "windup": 0.15, "range": 3.4, "arc": 40.0, "knock": 4.0,
		"info": "Lash: long, narrow reach"},
	&"sting": {"damage": 5.0, "cooldown": 0.7, "windup": 0.1, "range": 2.3, "arc": 45.0, "knock": 1.0, "poison": 4.0,
		"info": "Sting: poisons for 3 s"},
}

var crab: Crab
## Last style used per side (tests and HUD read this).
var last_style: Array[StringName] = [&"", &""]
var _cooldown: Array[float] = [0.0, 0.0]
var _busy := 0.0


static func style_id(claw: PartInstance) -> StringName:
	if claw and STYLES.has(claw.data.ability):
		return claw.data.ability
	return &"pinch"


static func style_info(claw: PartInstance) -> String:
	var st: Dictionary = STYLES[style_id(claw)]
	return st.info


func _claw(side: int) -> PartInstance:
	return crab.equipment.get_part(Equipment.Socket.CLAW_L if side == 0 else Equipment.Socket.CLAW_R)


func is_ready(side: int) -> bool:
	return _cooldown[side] <= 0.0 and _claw(side) != null


## True briefly after an attack (movement keeps facing the target meanwhile).
func is_busy() -> bool:
	return _busy > 0.0


func attack_range(side: int) -> float:
	var st: Dictionary = STYLES[style_id(_claw(side))]
	return st.range


func damage_for(side: int) -> float:
	var claw := _claw(side)
	var st: Dictionary = STYLES[style_id(claw)]
	var base: float = st.damage
	return (base * Rarity.multiplier(claw.rarity) + crab.equipment.total(&"attack") * 0.5) * crab.damage_mult


func try_attack(side: int, dir: Vector3) -> bool:
	if not is_ready(side) or crab.is_dead():
		return false
	var claw := _claw(side)
	var id := style_id(claw)
	var st: Dictionary = STYLES[id]
	var windup: float = st.windup
	var cooldown: float = st.cooldown
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else crab.facing
	_cooldown[side] = cooldown * crab.cooldown_mult
	_busy = windup + 0.25
	last_style[side] = id
	crab.face_now(dir)
	var socket := Equipment.Socket.CLAW_L if side == 0 else Equipment.Socket.CLAW_R
	crab.body.play_attack(socket, id, windup)
	attacked.emit(side, id)
	var dmg := damage_for(side)
	var hits: int = st.get("hits", 1)
	for i in hits:
		get_tree().create_timer(windup + i * 0.14, false, true).timeout.connect(_resolve.bind(id, dir, dmg))
	return true


func _resolve(id: StringName, dir: Vector3, dmg: float) -> void:
	if not is_instance_valid(crab) or crab.is_dead():
		return
	var st: Dictionary = STYLES[id]
	var knock: float = st.knock
	var origin := crab.global_position
	if st.has("projectile_speed"):
		var shot := BubbleShot.new()
		shot.team = crab.team
		shot.damage = dmg
		shot.knock = knock
		shot.velocity = dir * float(st.projectile_speed)
		shot.max_distance = st.range
		shot.source = crab
		crab.get_parent().add_child(shot)
		shot.global_position = origin + Vector3(0, 0.45 * crab.size, 0) + dir * 0.7 * crab.size
		return
	var reach: float = float(st.range) * maxf(crab.size, 1.0)
	var arc: float = st.arc
	FX.slash(crab.get_parent(), origin + Vector3(0, 0.35, 0), dir, reach, arc,
		Color(1, 0.85, 0.6) if crab.team == 0 else Color(1, 0.4, 0.3))
	var dealt_total := 0.0
	for other in Melee.targets(crab, origin, dir, reach, arc):
		dealt_total += other.receive_hit(dmg, origin, knock, crab)
		if st.has("poison"):
			other.poison(float(st.poison), 3.0)
	if st.has("heal") and dealt_total > 0.0:
		crab.health.heal(dealt_total * float(st.heal))


func _physics_process(delta: float) -> void:
	_busy = maxf(_busy - delta, 0.0)
	for i in 2:
		_cooldown[i] = maxf(_cooldown[i] - delta, 0.0)
