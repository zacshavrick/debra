class_name Melee
extends RefCounted
## Shared hit queries for every attack (crab claws and critter attacks).


## Enemies of `attacker` inside a ground-plane arc. arc_deg >= 360 = all around.
static func targets(attacker: Creature, origin: Vector3, dir: Vector3, reach: float, arc_deg: float) -> Array[Creature]:
	var out: Array[Creature] = []
	for n in attacker.get_tree().get_nodes_in_group("creatures"):
		var other := n as Creature
		if other == null or other == attacker or other.team == attacker.team or other.is_dead():
			continue
		var to := other.global_position - origin
		to.y = 0.0
		if to.length() - other.radius() > reach:
			continue
		if arc_deg < 360.0 and to.length() > 0.6 and rad_to_deg(dir.angle_to(to)) > arc_deg * 0.5:
			continue
		out.append(other)
	return out


## Nearest living enemy of `team` within max_dist of pos, or null.
static func nearest_enemy(tree: SceneTree, team: int, pos: Vector3, max_dist: float) -> Creature:
	var best: Creature = null
	var best_d := max_dist
	for n in tree.get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.team == team or c.is_dead():
			continue
		var d := Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = c
	return best
