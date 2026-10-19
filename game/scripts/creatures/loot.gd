class_name Loot
extends RefCounted
## What happens when an enemy dies: count the kill, drop its part(s).
## Bosses always drop two parts (one guaranteed Rare or better).


static func on_enemy_died(enemy: Creature, creature: CreatureData, rng: RandomNumberGenerator, luck: float) -> void:
	var player := enemy.get_tree().get_first_node_in_group("player") as PlayerCrab
	if player:
		player.add_kill()
	var parent := enemy.get_parent()
	var pos := enemy.global_position
	if creature.boss:
		for i in 2:
			var part := creature.roll_drop(rng, luck + 1.0)
			if part:
				if i == 0:
					part.rarity = maxi(part.rarity, Rarity.Tier.RARE)
				var off := Vector3(cos(i * PI), 0, sin(i * PI)) * 1.2
				PartPickup.spawn(parent, pos + off, part)
		return
	var drop := creature.roll_drop(rng, luck)
	if drop:
		PartPickup.spawn(parent, pos, drop)
