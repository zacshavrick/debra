class_name BossBrain
extends Node
## Extra brain for bosses, on top of their normal AI.
##
## Adaptive tactics (every boss): it watches where you hit it from.
##   - Fight it from range -> RUSH: it charges across the arena at you and
##     answers with a volley of shots.
##   - Fight it up close   -> BRISTLE: it grows thorns (hitting it hurts you),
##     slams the ground around itself, then backs off.
## Traits (generated bosses get 1-3): summoner, enrage, slam, shell, splitter.

signal announce(text: String)

const TRAITS := {
	&"summoner": "Summoner: calls in help",
	&"enrage": "Enrage: faster and angrier when hurt",
	&"slam": "Slam: a telegraphed shockwave",
	&"shell": "Shell: armours up at 2/3 and 1/3 health",
	&"splitter": "Splitter: splits in two when it dies",
}
const RANGED_DIST := 4.0

var boss: Creature
var level: Level
var traits: Array[StringName] = []
## "", &"rush" (you're fighting from range) or &"bristle" (you're up close).
var tactic: StringName = &""

var _range_score := 0.0
var _eval_t := 2.0
var _rush_t := 3.0
var _bristle_t := 3.0
var _summon_t := 9.0
var _slam_t := 6.0
var _enraged := false
var _shells_done := 0
var _shield_left := 0.0
var _shield: MeshInstance3D
var _special: StringName = &""
var _special_left := 0.0
var _special_dir := Vector3.FORWARD


func _ready() -> void:
	boss.health.damaged.connect(_on_damaged)
	boss.died.connect(_on_died)


func has_trait(t: StringName) -> bool:
	return traits.has(t)


func _player() -> PlayerCrab:
	return level.player if level and is_instance_valid(level.player) and not level.player.is_dead() and not level.player.cloaked else null


func _dmg(base: float) -> float:
	return base * boss.damage_mult


func _on_damaged(_amount: float, source: Node3D) -> void:
	if source is PlayerCrab:
		var d := (source as Node3D).global_position.distance_to(boss.global_position) - boss.radius()
		_range_score = lerpf(_range_score, 1.0 if d > RANGED_DIST else -1.0, 0.2)
	var frac := boss.health.hp / boss.health.max_hp
	if has_trait(&"enrage") and not _enraged and frac < 0.5:
		_enraged = true
		boss.move_speed *= 1.35
		boss.cooldown_mult *= 0.65
		boss.glow_overlay = Creature.glow_material(Color(1, 0.2, 0.15))
		boss._apply_glow()
		FX.shockwave(boss.get_parent(), boss.global_position, 3.0, Color(1, 0.3, 0.2))
		announce.emit("%s is enraged!" % boss.display_name)
	if has_trait(&"shell") and _shells_done < 2 and frac < (0.66 if _shells_done == 0 else 0.33):
		_shells_done += 1
		_raise_shield()


func _physics_process(delta: float) -> void:
	if boss == null or boss.is_dead():
		return
	_tick_shield(delta)
	var p := _player()
	if p == null:
		return
	var to := p.global_position - boss.global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	if _special != &"":
		_special_left -= delta
		if _special_left <= 0.0:
			_execute(_special, p)
			_special = &""
		return
	# Re-read how the player is fighting.
	_eval_t -= delta
	if _eval_t <= 0.0:
		_eval_t = 1.0
		var want := tactic
		if _range_score > 0.35:
			want = &"rush"
		elif _range_score < -0.35:
			want = &"bristle"
		if want != tactic:
			tactic = want
			boss.thorns = 0.35 if tactic == &"bristle" else 0.0
			if tactic == &"rush":
				announce.emit("%s adapts: it's coming for you!" % boss.display_name)
			else:
				announce.emit("%s bristles: thorns up!" % boss.display_name)
			FX.burst(boss.get_parent(), boss.global_position + Vector3(0, boss.size * 0.6, 0), Color(1, 0.6, 0.3), 16, 3.0, 0.08)
	_rush_t -= delta
	_bristle_t -= delta
	_summon_t -= delta
	_slam_t -= delta
	if tactic == &"rush" and _rush_t <= 0.0 and dist > 5.0:
		_rush_t = 4.5
		_begin(&"rush", 0.6, dir)
		FX.warn_lane(boss.get_parent(), boss.global_position, dir, 16.0 * 0.45, boss.radius() * 2.0, 0.6)
	elif tactic == &"bristle" and _bristle_t <= 0.0 and dist < 3.5 * maxf(boss.size, 1.0):
		_bristle_t = 5.0
		_begin(&"bristle", 0.6, dir)
		FX.warn_circle(boss.get_parent(), boss.global_position, 3.2 * maxf(boss.size * 0.6, 1.0), 0.6)
	elif has_trait(&"slam") and _slam_t <= 0.0 and dist < 6.0 * maxf(boss.size * 0.6, 1.0):
		_slam_t = 7.0
		_begin(&"slam", 0.9, dir)
		FX.warn_circle(boss.get_parent(), boss.global_position, 4.5 * maxf(boss.size * 0.6, 1.0), 0.9, Color(1, 0.5, 0.15))
	elif has_trait(&"summoner") and _summon_t <= 0.0:
		_summon_t = 11.0
		_begin(&"summon", 0.8, dir)
		for i in 2:
			FX.warn_circle(boss.get_parent(), boss.global_position + _summon_offset(i), 1.0, 0.8, Color(0.6, 0.9, 1.0))


func _begin(kind: StringName, windup: float, dir: Vector3) -> void:
	_special = kind
	_special_left = windup
	_special_dir = dir
	boss.lock_ai(windup + 0.3)
	boss.face_now(dir)


func _execute(kind: StringName, p: PlayerCrab) -> void:
	var parent := boss.get_parent()
	var origin := boss.global_position
	match kind:
		&"rush":
			boss.start_dash(_special_dir, 16.0, 0.45, _dmg(14.0), 7.0, true)
			# Answer the sniping with a volley once it lands.
			get_tree().create_timer(0.5, false, true).timeout.connect(_volley)
		&"bristle":
			var r := 3.2 * maxf(boss.size * 0.6, 1.0)
			FX.shockwave(parent, origin, r, Color(1, 0.4, 0.3))
			for t in Melee.targets(boss, origin, _special_dir, r, 360.0):
				t.receive_hit(_dmg(12.0), origin, 8.0, boss)
			get_tree().create_timer(0.35, false, true).timeout.connect(func() -> void:
				if is_instance_valid(boss) and not boss.is_dead() and is_instance_valid(p):
					boss.start_dash(boss.global_position - p.global_position, 10.0, 0.3))
		&"slam":
			var r := 4.5 * maxf(boss.size * 0.6, 1.0)
			FX.shockwave(parent, origin, r, Color(1, 0.6, 0.2))
			for t in Melee.targets(boss, origin, _special_dir, r, 360.0):
				t.receive_hit(_dmg(18.0), origin, 9.0, boss)
		&"summon":
			for i in 2:
				var list := level.level.enemy_list()
				var e := level.spawn_enemy(list[randi() % list.size()], boss.global_position + _summon_offset(i), false)
				e.alert()
				FX.burst(parent, e.global_position + Vector3(0, 0.4, 0), Color(0.6, 0.9, 1.0), 12, 2.5, 0.07)


func _volley() -> void:
	var p := _player()
	if p == null or boss.is_dead():
		return
	var dir := (p.global_position - boss.global_position)
	dir.y = 0.0
	for i in 5:
		var d := dir.normalized().rotated(Vector3.UP, lerpf(-0.5, 0.5, i / 4.0))
		BubbleShot.fire(boss, boss.global_position + Vector3(0, 0.6 * boss.size, 0) + d * boss.radius(), d, _dmg(7.0), 10.0, 12.0, Color(1, 0.55, 0.3), 0.2)


func _summon_offset(i: int) -> Vector3:
	return Vector3(cos(i * PI + 0.7), 0, sin(i * PI + 0.7)) * (boss.radius() + 2.0)


func _raise_shield() -> void:
	_shield_left = 5.0
	boss.damage_taken_mult = 0.1
	if _shield == null:
		_shield = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		_shield.mesh = s
		_shield.material_override = CritterVisual._glass(Color(0.5, 0.8, 1.0), 0.35, 0.8)
		boss.add_child(_shield)
	_shield.visible = true
	_shield.scale = Vector3.ONE * boss.radius() * 3.0
	_shield.position.y = boss.size * 0.5
	announce.emit("%s hides in its shell!" % boss.display_name)
	FX.ring(boss.get_parent(), boss.global_position + Vector3(0, 0.3, 0), boss.radius() * 2.0, Color(0.5, 0.8, 1.0))


func _tick_shield(delta: float) -> void:
	if _shield_left <= 0.0:
		return
	_shield_left -= delta
	if _shield:
		_shield.rotation.y += delta
	if _shield_left <= 0.0:
		boss.damage_taken_mult = 1.0
		if _shield:
			_shield.visible = false
		FX.burst(boss.get_parent(), boss.global_position + Vector3(0, boss.size * 0.5, 0), Color(0.6, 0.85, 1.0), 20, 4.0, 0.08)


func _on_died(_c: Creature) -> void:
	if has_trait(&"splitter") and level:
		var base := level.level.boss
		for i in 2:
			var piece := level.spawn_enemy(base, boss.global_position + _summon_offset(i) * 0.5, false, {"split": true})
			piece.alert()
		announce.emit("It splits in two!")
