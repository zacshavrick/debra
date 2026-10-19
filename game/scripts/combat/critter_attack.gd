class_name CritterAttack
extends RefCounted
## Attacks for non-crustacean sea creatures (combat iteration #1).
## Every attack has a visible windup (the body puffs/glows) before it lands.

const ATTACKS := {
	&"bite":   {"damage": 9.0, "cooldown": 1.1, "windup": 0.3, "range": 1.5, "arc": 100.0, "knock": 3.0},
	&"dash":   {"damage": 13.0, "cooldown": 2.6, "windup": 0.55, "range": 7.0, "dash_speed": 13.0, "dash_time": 0.4, "knock": 6.0},
	&"spit":   {"damage": 7.0, "cooldown": 1.7, "windup": 0.35, "range": 10.0, "speed": 9.0, "color": Color(0.6, 1.0, 0.75)},
	&"spines": {"damage": 6.0, "cooldown": 2.6, "windup": 0.6, "range": 6.0, "speed": 7.0, "count": 10, "color": Color(0.35, 0.2, 0.45)},
	&"pulse":  {"damage": 10.0, "cooldown": 2.2, "windup": 0.6, "range": 2.4, "knock": 5.0, "poison": 2.0},
	&"ink":    {"damage": 5.0, "cooldown": 2.0, "windup": 0.3, "range": 9.0, "speed": 8.0, "count": 3, "color": Color(0.1, 0.08, 0.15)},
}


static func info(id: StringName) -> Dictionary:
	return ATTACKS.get(id, ATTACKS[&"bite"])


## Telegraph shown at the start of the windup.
static func telegraph(c: Critter, id: StringName) -> void:
	var a := info(id)
	if id == &"pulse" or id == &"spines":
		FX.ring(c.get_parent(), c.global_position + Vector3(0, 0.1, 0), float(a.range) * (1.0 if id == &"pulse" else 0.5), Color(1, 0.4, 0.4))


## The hit itself, after the windup. dir = towards the target.
static func perform(c: Critter, id: StringName, dir: Vector3) -> void:
	var a := info(id)
	var dmg: float = float(a.damage) * c.damage_mult
	var origin := c.global_position
	var muzzle := origin + Vector3(0, c.hover_height() + 0.2 * c.size, 0) + dir * c.radius()
	match id:
		&"bite":
			FX.slash(c.get_parent(), origin + Vector3(0, 0.3, 0), dir, float(a.range) * c.size, a.arc, Color(1, 0.4, 0.3))
			for t in Melee.targets(c, origin, dir, float(a.range) * maxf(c.size, 1.0), a.arc):
				t.receive_hit(dmg, origin, a.knock, c)
		&"pulse":
			var r: float = float(a.range) * maxf(c.size, 1.0)
			FX.ring(c.get_parent(), origin + Vector3(0, 0.2, 0), r, Color(0.8, 0.6, 1.0))
			for t in Melee.targets(c, origin, dir, r, 360.0):
				t.receive_hit(dmg, origin, a.knock, c)
				t.poison(float(a.poison) * c.damage_mult * 2.0, 3.0)
		&"spit":
			BubbleShot.fire(c, muzzle, dir, dmg, a.speed, a.range, a.color, 0.2)
		&"ink":
			for i in int(a.count):
				var d := dir.rotated(Vector3.UP, (i - 1) * 0.25)
				BubbleShot.fire(c, muzzle, d, dmg, a.speed, a.range, a.color, 0.22)
		&"spines":
			var n: int = a.count
			for i in n:
				var d := Vector3(cos(TAU * i / n), 0, sin(TAU * i / n))
				BubbleShot.fire(c, origin + Vector3(0, 0.4, 0) + d * c.radius(), d, dmg, a.speed, a.range, a.color, 0.12)
		&"dash":
			c.start_dash(dir, a.dash_speed, a.dash_time, dmg, a.knock)
