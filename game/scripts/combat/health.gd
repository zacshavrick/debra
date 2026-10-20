class_name Health
extends Node
## Hit points + defense for anything that can be hurt.

signal damaged(amount: float, source: Node3D)
signal died
signal changed

var max_hp := 50.0
var hp := 50.0
## Damage is scaled by 25 / (25 + defense): 25 DEF halves incoming damage.
var defense := 0.0
## Optional: called when a hit would kill. Return true to survive (Second wind).
var cheat_death: Callable


func is_dead() -> bool:
	return hp <= 0.0


func fill() -> void:
	hp = max_hp
	changed.emit()


## New max HP (from equipment). Keeps the current HP ratio.
func set_max(value: float) -> void:
	var ratio := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = maxf(value, 1.0)
	if not is_dead():
		hp = clampf(max_hp * ratio, 1.0, max_hp)
	changed.emit()


## Applies a hit after defense. Returns the damage actually taken.
func take_hit(raw: float, source: Node3D = null) -> float:
	if is_dead():
		return 0.0
	var dmg := maxf(1.0, raw * 25.0 / (25.0 + maxf(defense, 0.0)))
	if hp - dmg <= 0.0 and cheat_death.is_valid() and cheat_death.call():
		hp = max_hp * 0.3
		damaged.emit(dmg, source)
		changed.emit()
		return dmg
	hp = maxf(hp - dmg, 0.0)
	damaged.emit(dmg, source)
	changed.emit()
	if hp <= 0.0:
		died.emit()
	return dmg


func heal(amount: float) -> void:
	if is_dead() or hp >= max_hp:
		return
	hp = minf(hp + amount, max_hp)
	changed.emit()
