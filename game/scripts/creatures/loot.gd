class_name Loot
extends RefCounted
## What happens when an enemy dies: count the kill, drop its part(s).
## Every drop's part level = the creature's drop_level (the level's depth).
##  - Champions always drop, with extra luck; one of their stolen parts if they have any.
##  - Bosses drop two parts (one guaranteed Rare or better). Chimera bosses
##    always give up one of the parts they stole.


static func on_enemy_died(enemy: Creature, creature: CreatureData, rng: RandomNumberGenerator, luck: float, stolen: Array) -> void:
	var player := enemy.get_tree().get_first_node_in_group("player") as PlayerCrab
	if player:
		player.add_kill()
	var parent := enemy.get_parent()
	var pos := enemy.global_position
	var lvl := enemy.drop_level
	var stolen_parts: Array[PartData] = []
	for p in stolen:
		if p is PartData:
			stolen_parts.append(p)
	if enemy.is_boss:
		for i in 2:
			var part: PartInstance
			if i == 1 and not stolen_parts.is_empty():
				part = PartInstance.new(stolen_parts[rng.randi() % stolen_parts.size()], Rarity.roll(rng, luck + 1.0), lvl)
			else:
				part = creature.roll_drop(rng, luck + 1.0, lvl)
			if part == null:
				continue
			if i == 0:
				part.rarity = maxi(part.rarity, Rarity.Tier.RARE)
			var off := Vector3(cos(i * PI), 0, sin(i * PI)) * 1.2
			PartPickup.spawn(parent, pos + off, part)
		return
	if enemy.is_champion:
		var part: PartInstance
		if not stolen_parts.is_empty() and rng.randf() < 0.6:
			part = PartInstance.new(stolen_parts[rng.randi() % stolen_parts.size()], Rarity.roll(rng, luck + 1.0), lvl)
		else:
			var saved := creature.drop_chance
			creature.drop_chance = 1.0
			part = creature.roll_drop(rng, luck + 1.0, lvl)
			creature.drop_chance = saved
		if part:
			part.rarity = maxi(part.rarity, Rarity.Tier.UNCOMMON)
			PartPickup.spawn(parent, pos, part)
		return
	var drop := creature.roll_drop(rng, luck, lvl)
	if drop:
		PartPickup.spawn(parent, pos, drop)
