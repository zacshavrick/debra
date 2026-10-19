class_name TailBrain
extends Node
## Tails act on their own: the player doesn't control them. Each tail part's
## `ability` picks a behaviour. Works for any Crab (enemy lobsters flick too).
## Strength scales with the tail's rarity/level and the crab's ATK.

const TAILS := {
	&"": {"info": "Tucked: does nothing. It's a crab."},
	&"flick": {"info": "Flick: sometimes yanks you backwards when you're hit", "chance": 0.35, "cooldown": 1.5},
	&"stab": {"info": "Stab: jabs nearby enemies on its own", "period": 2.2, "range": 2.6, "damage": 7.0},
	&"zap": {"info": "Zap: shocks up to 3 enemies now and then", "period": 4.0, "range": 6.0, "damage": 7.0, "chains": 3},
	&"lure": {"info": "Lure: every so often, calls every creature to you", "period": 9.0, "radius": 18.0},
	&"spines": {"info": "Spines: sprays spines when you're hit", "chance": 0.6, "cooldown": 1.0, "damage": 4.0, "count": 8},
	&"surge": {"info": "Surge: randomly rams you forward", "period": 5.0, "damage": 6.0},
}

signal triggered(kind: StringName)

var crab: Crab
var _timer := 2.0
var _cool := 0.0
var _t := 0.0
var _kick := 0.0


static func info(part: PartInstance) -> String:
	var id: StringName = part.data.ability if part else &""
	var d: Dictionary = TAILS.get(id, TAILS[&""])
	return d.info


func _ready() -> void:
	crab.health.damaged.connect(_on_damaged)


func _kind() -> StringName:
	var tail := crab.equipment.get_part(Equipment.Socket.TAIL)
	if tail == null or not TAILS.has(tail.data.ability):
		return &""
	return tail.data.ability


func _power(base: float) -> float:
	var tail := crab.equipment.get_part(Equipment.Socket.TAIL)
	return (base * tail.power() + crab.equipment.total(&"attack") * 0.3) * crab.damage_mult


func _physics_process(delta: float) -> void:
	_t += delta
	_cool = maxf(_cool - delta, 0.0)
	_animate(delta)
	if crab.is_dead():
		return
	var kind := _kind()
	var cfg: Dictionary = TAILS[kind]
	if not cfg.has("period"):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = float(cfg.period) * randf_range(0.8, 1.3)
	match kind:
		&"stab":
			var t := Melee.nearest_enemy(get_tree(), crab.team, crab.global_position, float(cfg.range) * maxf(crab.size, 1.0))
			if t:
				FX.ribbon(crab.get_parent(), PackedVector3Array([crab.global_position + Vector3(0, 0.4, 0) - crab.facing * 0.5, t.global_position + Vector3(0, 0.4, 0)]), 0.1, Color(1, 0.9, 0.6), 0.2)
				t.receive_hit(_power(cfg.damage), crab.global_position, 2.0, crab)
				_fire(kind)
			else:
				_timer = 0.4
		&"zap":
			var from := crab.global_position + Vector3(0, 0.5, 0) - crab.facing * 0.6
			var hit: Array[Creature] = []
			var cur := from
			for i in int(cfg.chains):
				var best: Creature = null
				var best_d := float(cfg.range)
				for n in get_tree().get_nodes_in_group("creatures"):
					var c := n as Creature
					if c == null or c.team == crab.team or c.is_dead() or hit.has(c):
						continue
					var d := c.global_position.distance_to(cur)
					if d < best_d:
						best_d = d
						best = c
				if best == null:
					break
				var to := best.global_position + Vector3(0, 0.5, 0)
				FX.lightning(crab.get_parent(), cur, to, Color(0.5, 0.85, 1.0))
				best.receive_hit(_power(cfg.damage), cur, 1.5, crab)
				hit.append(best)
				cur = to
			if hit.is_empty():
				_timer = 0.5
			else:
				_fire(kind)
		&"lure":
			FX.ring(crab.get_parent(), crab.global_position + Vector3(0, 0.3, 0), float(cfg.radius) * 0.5, Color(0.6, 1.0, 0.8), 0.6)
			for n in get_tree().get_nodes_in_group("creatures"):
				var c := n as Creature
				if c and c.team != crab.team and not c.is_dead() and c.global_position.distance_to(crab.global_position) < float(cfg.radius):
					c.alert()
			_fire(kind)
		&"surge":
			crab.start_dash(crab.facing, 12.0, 0.25, _power(cfg.damage), 4.0, true)
			FX.burst(crab.get_parent(), crab.global_position + Vector3(0, 0.3, 0), Color(0.8, 0.95, 1.0), 10, 2.0, 0.07)
			_fire(kind)


func _on_damaged(_amount: float, source: Node3D) -> void:
	if crab.is_dead() or _cool > 0.0:
		return
	var kind := _kind()
	var cfg: Dictionary = TAILS[kind]
	if not cfg.has("chance") or randf() > float(cfg.chance):
		return
	_cool = cfg.cooldown
	match kind:
		&"flick":
			var away := -crab.facing
			if is_instance_valid(source):
				away = crab.global_position - source.global_position
			crab.start_dash(away, 11.0, 0.22)
			FX.burst(crab.get_parent(), crab.global_position + Vector3(0, 0.3, 0), Color(0.85, 0.95, 1.0), 12, 2.5, 0.07)
			_fire(kind)
		&"spines":
			var n: int = cfg.count
			for i in n:
				var d := Vector3(cos(TAU * i / n), 0, sin(TAU * i / n))
				var s := BubbleShot.fire(crab, crab.global_position + Vector3(0, 0.4, 0) + d * crab.radius(), d, _power(cfg.damage), 8.0, 5.0, Color(0.95, 0.85, 0.7), 0.09)
				s.stretch = 2.5
			_fire(kind)


func _fire(kind: StringName) -> void:
	_kick = 1.0
	triggered.emit(kind)


## Idle sway, plus a sharp swing whenever the tail does something.
func _animate(delta: float) -> void:
	var sock := crab.body.get_socket(Equipment.Socket.TAIL) if crab.body else null
	if sock == null or sock.get_child_count() == 0:
		return
	var swing := sock.get_child(0).get_node_or_null("Swing") as Node3D
	if swing == null:
		return
	_kick = maxf(_kick - delta * 4.0, 0.0)
	swing.rotation.y = sin(_t * 2.2) * 0.12 + sin(_t * 30.0) * 0.25 * _kick
	swing.rotation.x = -0.6 * _kick
