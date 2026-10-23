class_name MoveAbility
extends Node
## Each starter crab's own movement move (Shift / gamepad B / MOVE). It belongs
## to the crab, not to a part (CreatureData.move_ability), so swapping gear never
## changes it. Charges refill one at a time, one per `cooldown` seconds.
##
##   leap     Gary      1 charge, 3 s: a long jump over everything (untouchable in the air)
##   scuttle  Saul      3 charges, 3 s: sideways dash, pattern Right, Right, Left, Left
##   lunge    Debra     2 charges, 3 s: a long forward dash
##   arc      Marjorie  2 charges, 3 s: a medium dash that curves (right, then left)
##   shimmy   Louise    4 charges, 4 s: short dashes, pattern Fwd, Fwd, Back, Fwd

signal used(kind: StringName, step: int)

const MOVES := {
	&"leap": {"name": "Long Jump", "charges": 1, "cooldown": 3.0, "speed": 12.0, "time": 0.5, "height": 1.6},
	&"scuttle": {"name": "Scuttle", "charges": 3, "cooldown": 3.0, "speed": 15.0, "time": 0.22, "pattern": ["R", "R", "L", "L"]},
	&"lunge": {"name": "Lunge", "charges": 2, "cooldown": 3.0, "speed": 20.0, "time": 0.35},
	&"arc": {"name": "Arc Dash", "charges": 2, "cooldown": 3.0, "speed": 11.0, "time": 0.45, "turn": PI * 0.5},
	&"shimmy": {"name": "Shimmy", "charges": 4, "cooldown": 4.0, "speed": 15.0, "time": 0.15, "pattern": ["F", "F", "B", "F"]},
}

var crab: Crab
var kind: StringName = &"lunge"
var charges := 0
## Where in the move's pattern the next use is (scuttle, shimmy, arc direction).
var step := 0
var _recharge := 0.0
var _hop_left := 0.0
var _hop_total := 0.0
var _saved_mask := 0


static func info(id: StringName) -> String:
	var m: Dictionary = MOVES.get(id, {})
	if m.is_empty():
		return ""
	var t := "%s: %d charge%s, %.0f s each" % [m.name, m.charges, "" if int(m.charges) == 1 else "s", m.cooldown]
	if m.has("pattern"):
		t += " (" + " ".join(PackedStringArray(m.pattern)) + ")"
	return t


func _ready() -> void:
	if not MOVES.has(kind):
		kind = &"lunge"
	charges = max_charges()


func cfg() -> Dictionary:
	return MOVES[kind]


func max_charges() -> int:
	return int(cfg().charges)


## 0..1 progress of the charge currently refilling (1 when full).
func recharge_fraction() -> float:
	if charges >= max_charges():
		return 1.0
	return 1.0 - _recharge / float(cfg().cooldown)


## `forward`: where the player wants to go (stick / keys), or ZERO to use facing.
func try_use(forward: Vector3) -> bool:
	if charges <= 0 or crab.is_dead() or crab.is_dashing():
		return false
	var c := cfg()
	forward.y = 0.0
	var fwd := forward.normalized() if forward.length() > 0.1 else crab.facing
	var right := crab.facing.cross(Vector3.UP).normalized()
	var dir := fwd
	match kind:
		&"scuttle":
			var p: Array = c.pattern
			dir = right if p[step % p.size()] == "R" else -right
		&"shimmy":
			var p: Array = c.pattern
			dir = fwd if p[step % p.size()] == "F" else -fwd
	var spd: float = c.speed
	var sec: float = c.time
	var keep_facing := kind == &"scuttle" or (kind == &"shimmy" and dir == -fwd)
	var face := crab.facing
	crab.start_dash(dir, spd, sec)
	if keep_facing:   # sideways scuttles and back-steps keep looking ahead
		crab.face_now(face)
	if kind == &"arc":
		var turn: float = c.turn
		crab.curve_dash((turn if step % 2 == 0 else -turn) / sec * -1.0)
	if kind == &"leap":
		_hop_total = sec
		_hop_left = sec
		crab.airborne = true
		_saved_mask = crab.collision_mask
		crab.collision_mask = 1   # sail over creatures, still stopped by walls
	used.emit(kind, step)
	step += 1
	charges -= 1
	if _recharge <= 0.0:
		_recharge = float(c.cooldown)
	FX.burst(crab.get_parent(), crab.global_position + Vector3(0, 0.3, 0), Color(0.85, 0.95, 1.0), 10, 2.5, 0.06)
	FX.ribbon(crab.get_parent(), PackedVector3Array([crab.global_position + Vector3(0, 0.15, 0), crab.global_position + Vector3(0, 0.15, 0) + dir * spd * sec]),
		0.5, Color(0.6, 0.85, 1.0), 0.3)
	return true


func _physics_process(delta: float) -> void:
	if charges < max_charges():
		_recharge -= delta
		if _recharge <= 0.0:
			charges += 1
			_recharge = float(cfg().cooldown) if charges < max_charges() else 0.0
	if _hop_left > 0.0:
		_hop_left -= delta
		var t := 1.0 - _hop_left / _hop_total
		crab.body.position.y = sin(clampf(t, 0.0, 1.0) * PI) * float(cfg().height)
		if _hop_left <= 0.0:
			crab.body.position.y = 0.0
			crab.airborne = false
			crab.collision_mask = _saved_mask
			FX.ring(crab.get_parent(), crab.global_position + Vector3(0, 0.1, 0), 1.6, Color(0.9, 0.85, 0.7))
