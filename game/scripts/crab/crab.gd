class_name Crab
extends Creature
## Every crustacean (player and enemies): the shared rig, equipment, stats
## from parts and claw combat. Subclasses (PlayerCrab, EnemyCrab) add the brain.

const BASE_SPEED := 3.0
const SPEED_PER_POINT := 0.4

## How much of the parts' HP bonus counts (enemies get less, or shells make them sponges).
var part_hp_factor := 1.0
var speed_mult := 1.0

var body: CrabBody
var equipment: Equipment
var combat: CrabCombat


func _ready() -> void:
	super._ready()
	add_to_group("crabs")
	body = CrabBody.new()
	body.name = "Body"
	body.scale = Vector3.ONE * size
	add_child(body)
	equipment = Equipment.new()
	equipment.name = "Equipment"
	add_child(equipment)
	combat = CrabCombat.new()
	combat.name = "Combat"
	combat.crab = self
	add_child(combat)
	equipment.changed.connect(_on_equipment_changed)


func _on_equipment_changed(socket: int) -> void:
	body.show_part(socket, equipment.get_displayed(socket))
	apply_stats()


func apply_stats() -> void:
	health.set_max(base_hp + equipment.total(&"max_hp") * part_hp_factor)
	health.defense = equipment.total(&"defense")
	move_speed = maxf(1.5, BASE_SPEED + equipment.total(&"speed") * SPEED_PER_POINT) * speed_mult


func _flash() -> void:
	body.flash()


func _set_walk(amount: float) -> void:
	if body:
		body.walk_amount = amount


func _play_death() -> void:
	body.play_death()


func _reset_pose() -> void:
	body.reset_pose()
