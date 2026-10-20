class_name Loot
extends RefCounted
## What happens when an enemy dies: count the kill, drop its part(s).
## Every drop's part level = the creature's drop_level (the level's depth).
##  - Champions always drop, with extra luck; often one of their stolen parts.
##  - Bosses drop two parts (one at least Rare). Chimera bosses always give up
##    one of the parts they stole.
##  - The Midas mod adds an extra drop to every kill.


static func on_enemy_died(enemy: Creature, creature: CreatureData, rng: RandomNumberGenerator, luck: float, stolen: Array) -> void:
	var player := enemy.get_tree().get_first_node_in_group("player") as PlayerCrab
	if player:
		player.add_kill()
		luck += 0.5 * player.mod_count(&"lucky")
	var parent := enemy.get_parent()
	var pos := enemy.global_position
	var lvl := enemy.drop_level
	var stolen_parts: Array[PartData] = []
	for p in stolen:
		if p is PartData:
			stolen_parts.append(p)
	var drops: Array[PartInstance] = []
	if enemy.is_boss:
		for i in 2:
			var part: PartInstance
			if i == 1 and not stolen_parts.is_empty():
				part = PartInstance.roll(stolen_parts[rng.randi() % stolen_parts.size()], rng, luck + 1.0, lvl)
			else:
				part = _force_drop(creature, rng, luck + 1.0, lvl)
			if part and i == 0 and part.rarity < Rarity.Tier.RARE:
				part.set_tier(Rarity.Tier.RARE, rng)
			if part:
				drops.append(part)
	elif enemy.is_champion:
		var part: PartInstance
		if not stolen_parts.is_empty() and rng.randf() < 0.6:
			part = PartInstance.roll(stolen_parts[rng.randi() % stolen_parts.size()], rng, luck + 1.0, lvl)
		else:
			part = _force_drop(creature, rng, luck + 1.0, lvl)
		if part:
			if part.rarity < Rarity.Tier.UNCOMMON:
				part.set_tier(Rarity.Tier.UNCOMMON, rng)
			drops.append(part)
	else:
		var drop := creature.roll_drop(rng, luck, lvl)
		if drop:
			drops.append(drop)
	if player and player.has_mod(&"midas"):
		var extra := _force_drop(creature, rng, luck, lvl)
		if extra:
			drops.append(extra)
	for i in drops.size():
		var off := Vector3.ZERO if drops.size() == 1 else Vector3(cos(i * TAU / drops.size()), 0, sin(i * TAU / drops.size())) * 1.2
		PartPickup.spawn(parent, pos + off, drops[i])


## A drop that ignores drop_chance.
static func _force_drop(creature: CreatureData, rng: RandomNumberGenerator, luck: float, lvl: int) -> PartInstance:
	var saved := creature.drop_chance
	creature.drop_chance = 1.0
	var part := creature.roll_drop(rng, luck, lvl)
	creature.drop_chance = saved
	return part
