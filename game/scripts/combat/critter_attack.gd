class_name CritterAttack
extends RefCounted
## Attacks for non-crustacean sea creatures (combat iteration #1).
## Every attack has a visible windup (the body puffs/glows) and, for area and
## charge attacks, a red ground telegraph showing where it will land.

const ATTACKS := {
	&"bite":   {"damage": 9.0, "cooldown": 1.1, "windup": 0.3, "range": 1.5, "arc": 100.0, "knock": 3.0},
	&"dash":   {"damage": 13.0, "cooldown": 2.6, "windup": 0.55, "range": 7.0, "dash_speed": 13.0, "dash_time": 0.4, "knock": 6.0},
	&"pierce": {"damage": 15.0, "cooldown": 3.0, "windup": 0.7, "range": 9.0, "dash_speed": 19.0, "dash_time": 0.45, "knock": 7.0},
	&"spit":   {"damage": 7.0, "cooldown": 1.7, "windup": 0.35, "range": 10.0, "speed": 9.0, "color": Color(0.6, 1.0, 0.75)},
	&"volley": {"damage": 5.0, "cooldown": 2.4, "windup": 0.5, "range": 9.0, "speed": 8.5, "count": 5, "spread": 0.7, "color": Color(1.0, 0.6, 0.35)},
	&"spines": {"damage": 6.0, "cooldown": 2.6, "windup": 0.6, "range": 6.0, "speed": 7.0, "count": 10, "color": Color(0.35, 0.2, 0.45)},
	&"pulse":  {"damage": 10.0, "cooldown": 2.2, "windup": 0.6, "range": 2.4, "knock": 5.0, "poison": 2.0},
	&"ink":    {"damage": 5.0, "cooldown": 2.0, "windup": 0.3, "range": 9.0, "speed": 8.0, "count": 3, "color": Color(0.1, 0.08, 0.15)},
	&"zap":    {"damage": 9.0, "cooldown": 2.2, "windup": 0.55, "range": 6.5, "color": Color(0.5, 0.85, 1.0)},
	&"pull":   {"damage": 7.0, "cooldown": 2.6, "windup": 0.45, "range": 5.5, "knock": 9.0, "color": Color(0.9, 0.5, 0.75)},
}


## Bosses charge more than twice as far (the shark boss especially needed it).
static func dash_reach(c: Creature) -> float:
	return 2.2 if c.is_boss else 1.0


static func info(id: StringName) -> Dictionary:
	return ATTACKS.get(id, ATTACKS[&"bite"])


## Telegraph shown at the start of the windup.
static func telegraph(c: Creature, id: StringName, dir: Vector3, windup: float) -> void:
	var a := info(id)
	var parent := c.get_parent()
	var big := maxf(c.size, 1.0)
	match id:
		&"pulse":
			FX.warn_circle(parent, c.global_position, float(a.range) * big, windup)
		&"spines":
			FX.warn_circle(parent, c.global_position, float(a.range) * 0.5, windup, Color(0.75, 0.4, 1.0))
		&"dash", &"pierce":
			var length: float = float(a.dash_speed) * float(a.dash_time) * dash_reach(c)
			FX.warn_lane(parent, c.global_position, dir, length, c.radius() * 2.0, windup)
		&"zap":
			FX.burst(parent, c.global_position + Vector3(0, 0.6 * c.size, 0), a.color, 10, 1.5, 0.05)


## The hit itself, after the windup. dir = towards the target.
static func perform(c: Creature, id: StringName, dir: Vector3, target: Creature) -> void:
	var a := info(id)
	var dmg: float = float(a.damage) * c.damage_mult
	var origin := c.global_position
	var hover := (c as Critter).hover_height() if c is Critter else 0.3
	var muzzle := origin + Vector3(0, hover + 0.2 * c.size, 0) + dir * c.radius()
	var parent := c.get_parent()
	match id:
		&"bite":
			FX.claw(parent, origin + Vector3(0, 0.3, 0), dir, float(a.range) * c.size, a.arc, &"bite", c.team)
			for t in Melee.targets(c, origin, dir, float(a.range) * maxf(c.size, 1.0), a.arc):
				t.receive_hit(dmg, origin, a.knock, c)
		&"pulse":
			var r: float = float(a.range) * maxf(c.size, 1.0)
			FX.ring(parent, origin + Vector3(0, 0.2, 0), r, Color(0.8, 0.6, 1.0))
			FX.burst(parent, origin + Vector3(0, 0.4, 0), Color(0.85, 0.6, 1.0), 14, 3.0, 0.07)
			for t in Melee.targets(c, origin, dir, r, 360.0):
				t.receive_hit(dmg, origin, a.knock, c)
				t.poison(float(a.poison) * c.damage_mult * 2.0, 3.0)
		&"spit":
			BubbleShot.fire(c, muzzle, dir, dmg, a.speed, a.range, a.color, 0.2)
		&"volley":
			var n: int = a.count
			for i in n:
				var d := dir.rotated(Vector3.UP, lerpf(-float(a.spread), float(a.spread), float(i) / (n - 1)))
				BubbleShot.fire(c, muzzle, d, dmg, a.speed, a.range, a.color, 0.15)
		&"ink":
			for i in int(a.count):
				var d := dir.rotated(Vector3.UP, (i - 1) * 0.25)
				BubbleShot.fire(c, muzzle, d, dmg, a.speed, a.range, a.color, 0.22)
		&"spines":
			var n: int = a.count
			for i in n:
				var d := Vector3(cos(TAU * i / n), 0, sin(TAU * i / n))
				var s := BubbleShot.fire(c, origin + Vector3(0, 0.4, 0) + d * c.radius(), d, dmg, a.speed, a.range, a.color, 0.1)
				s.stretch = 2.5
		&"dash":
			c.start_dash(dir, float(a.dash_speed) * (1.2 if c.is_boss else 1.0), float(a.dash_time) * dash_reach(c) / (1.2 if c.is_boss else 1.0), dmg, a.knock, false)
			FX.burst(parent, origin + Vector3(0, 0.3, 0), Color(0.8, 0.95, 1.0), 10, 2.0, 0.07)
		&"pierce":
			c.start_dash(dir, float(a.dash_speed) * (1.2 if c.is_boss else 1.0), float(a.dash_time) * dash_reach(c) / (1.2 if c.is_boss else 1.0), dmg, a.knock, true)
			FX.burst(parent, origin + Vector3(0, 0.3, 0), Color(0.8, 0.95, 1.0), 14, 3.0, 0.07)
		&"zap":
			if is_instance_valid(target) and target.global_position.distance_to(origin) <= float(a.range) * maxf(c.size, 1.0) + 0.5:
				FX.lightning(parent, muzzle, target.global_position + Vector3(0, 0.5, 0), a.color)
				target.receive_hit(dmg, origin, 2.0, c)
			else:
				FX.lightning(parent, muzzle, muzzle + dir * float(a.range), a.color)
		&"pull":
			if is_instance_valid(target) and target.global_position.distance_to(origin) <= float(a.range) * maxf(c.size, 1.0) + 0.5:
				var tp := target.global_position
				FX.ribbon(parent, PackedVector3Array([muzzle, muzzle.lerp(tp, 0.5) + dir.cross(Vector3.UP) * 0.4, tp + Vector3(0, 0.4, 0)]), 0.16, a.color, 0.35)
				# Knock "away" from a point behind the target = towards the creature.
				target.receive_hit(dmg, tp + (tp - origin).normalized(), a.knock, c)
			else:
				FX.ribbon(parent, PackedVector3Array([muzzle, muzzle + dir * float(a.range)]), 0.14, a.color, 0.3)
