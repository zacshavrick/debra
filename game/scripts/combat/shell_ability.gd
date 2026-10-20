class_name ShellAbility
extends Node
## Spacebar: every shell gives one active ability (PartData.ability on the
## SHELL part). Better shells (rarity) recharge faster and hit harder;
## the Timeless mod cuts cooldowns by 40%.

signal used(kind: StringName)

const ABILITIES := {
	&"dash": {"info": "Dash: a quick dodge", "cooldown": 1.8},
	&"shield": {"info": "Deflector: a bubble that blocks 80% damage and bounces shots back", "cooldown": 7.0, "time": 1.8},
	&"cloak": {"info": "Cloak: vanish for 3 s; your next hit does double damage", "cooldown": 10.0, "time": 3.0},
	&"shark_dash": {"info": "Shark Dash: a long, straight ramming charge", "cooldown": 2.5, "damage": 16.0},
	&"spikes": {"info": "Spike Burst: spines in every direction", "cooldown": 5.0, "damage": 7.0, "count": 14},
	&"roll": {"info": "Roll: curl up and roll through everything, untouchable", "cooldown": 6.0, "damage": 8.0},
	&"heal": {"info": "Mend: heal 30% over 2 s", "cooldown": 12.0},
	&"quake": {"info": "Quake: slam the ground around you", "cooldown": 6.0, "damage": 14.0, "radius": 3.2},
}

var crab: Crab
var cooldown_left := 0.0
var _active := 0.0
var _active_kind: StringName = &""
var _heal_left := 0.0
var _bubble: MeshInstance3D


static func info(part: PartInstance) -> String:
	var id: StringName = part.data.ability if part and ABILITIES.has(part.data.ability) else &"dash"
	var d: Dictionary = ABILITIES[id]
	return d.info


func kind() -> StringName:
	var shell := crab.equipment.get_part(Equipment.Socket.SHELL)
	if shell and ABILITIES.has(shell.data.ability):
		return shell.data.ability
	return &"dash"


func cooldown_total() -> float:
	var shell := crab.equipment.get_part(Equipment.Socket.SHELL)
	var cfg: Dictionary = ABILITIES[kind()]
	var cd: float = cfg.cooldown
	if shell:
		cd /= 1.0 + 0.08 * shell.rarity
	if crab.has_mod(&"timeless"):
		cd *= 0.6
	return cd


func ready_fraction() -> float:
	return 1.0 - clampf(cooldown_left / maxf(cooldown_total(), 0.01), 0.0, 1.0)


func _power(base: float) -> float:
	var shell := crab.equipment.get_part(Equipment.Socket.SHELL)
	var p := shell.power() if shell else 1.0
	return (base * p + crab.equipment.total(&"attack") * 0.3) * crab.gear_damage_mult


func try_use(dir: Vector3) -> bool:
	if cooldown_left > 0.0 or crab.is_dead():
		return false
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else crab.facing
	var k := kind()
	var cfg: Dictionary = ABILITIES[k]
	var parent := crab.get_parent()
	var origin := crab.global_position
	cooldown_left = cooldown_total()
	match k:
		&"dash":
			crab.start_dash(dir, 14.0, 0.18)
			FX.burst(parent, origin + Vector3(0, 0.3, 0), Color(0.85, 0.95, 1.0), 10, 2.0, 0.06)
		&"shark_dash":
			crab.start_dash(dir, 22.0, 0.42, _power(cfg.damage), 6.0, true)
			FX.ribbon(parent, PackedVector3Array([origin + Vector3(0, 0.3, 0), origin + Vector3(0, 0.3, 0) + dir * 9.0]), 0.6, Color(0.6, 0.85, 1.0), 0.35)
			FX.burst(parent, origin + Vector3(0, 0.3, 0), Color(0.8, 0.95, 1.0), 16, 3.0, 0.08)
		&"shield":
			_start(k, cfg.time)
			crab.damage_taken_mult = 0.2
			crab.reflecting = true
			_show_bubble(Color(0.5, 0.85, 1.0))
		&"cloak":
			_start(k, cfg.time)
			crab.cloaked = true
			crab.body._set_overlay(crab.body, Creature.glow_material(Color(0.3, 0.4, 0.5)))
			FX.burst(parent, origin + Vector3(0, 0.4, 0), Color(0.6, 0.7, 0.8), 14, 2.0, 0.08)
		&"spikes":
			var n: int = cfg.count
			for i in n:
				var d := Vector3(cos(TAU * i / n), 0, sin(TAU * i / n))
				var s := BubbleShot.fire(crab, origin + Vector3(0, 0.4, 0) + d * crab.radius(), d, _power(cfg.damage), 10.0, 6.0, Color(0.85, 0.6, 1.0), 0.1)
				s.stretch = 2.5
		&"roll":
			_start(k, 0.6)
			crab.damage_taken_mult = 0.0
			crab.start_dash(dir, 10.0, 0.6, _power(cfg.damage), 5.0, true)
			_show_bubble(Color(0.75, 0.7, 0.9))
		&"heal":
			_heal_left = 2.0
			FX.ring(parent, origin + Vector3(0, 0.3, 0), 2.0, Color(0.4, 1.0, 0.6), 0.5)
		&"quake":
			var r: float = cfg.radius
			FX.shockwave(parent, origin, r, Color(0.9, 0.7, 0.4))
			for t in Melee.targets(crab, origin, dir, r, 360.0):
				t.receive_hit(_power(cfg.damage), origin, 7.0, crab)
	used.emit(k)
	return true


## Cloak ends early when you attack (the hit itself gets the bonus).
func break_cloak() -> void:
	if _active_kind == &"cloak":
		_end()


func _start(k: StringName, sec: float) -> void:
	_active_kind = k
	_active = sec


func _end() -> void:
	match _active_kind:
		&"shield", &"roll":
			crab.damage_taken_mult = 1.0
			crab.reflecting = false
		&"cloak":
			crab.cloaked = false
			crab.body._set_overlay(crab.body, crab.glow_overlay)
	if _bubble:
		_bubble.visible = false
	_active_kind = &""
	_active = 0.0


func _show_bubble(col: Color) -> void:
	if _bubble == null:
		_bubble = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		_bubble.mesh = s
		crab.add_child(_bubble)
	_bubble.material_override = CritterVisual._glass(col, 0.3, 0.9)
	_bubble.scale = Vector3.ONE * crab.radius() * 3.2
	_bubble.position.y = 0.45 * crab.size
	_bubble.visible = true


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if _heal_left > 0.0:
		_heal_left -= delta
		crab.health.heal(crab.health.max_hp * 0.15 * delta)
	if _active > 0.0:
		_active -= delta
		if _bubble and _bubble.visible:
			_bubble.rotation.y += delta * 2.0
		if _active <= 0.0 or crab.is_dead():
			_end()
