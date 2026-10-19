class_name PlayerCrab
extends Crab
## The player's crab (whichever starter you picked). Reads intent from
## PlayerInput, attacks with each claw, picks up and equips parts, respawns at
## the level start. What you wear is saved per starter (GameState).

signal equipped(socket: int, part: PartInstance)
signal respawned
signal kills_changed(kills: int)

const PICKUP_RANGE := 1.3
const RESPAWN_DELAY := 2.0
const HOME_RADIUS := 3.0
const HOME_HEAL := 15.0   ## HP per second while at home

var creature: CreatureData
## Set to false in tests/screens that shouldn't touch the save file.
var persist := true
var camera: Camera3D
var home_position := Vector3.ZERO
var focused_pickup: PartPickup
var kills := 0

var _respawn_left := 0.0


func _ready() -> void:
	team = 0
	super._ready()
	add_to_group("player")
	name = "Player"
	display_name = creature.display_name
	base_hp = creature.base_hp
	damage_mult = 1.0
	var parts := GameState.loadout_for(creature.id) if persist else _default_loadout()
	for s in Equipment.SOCKET_COUNT:
		equipment.equip(s, parts[s])
	health.fill()
	PlayerInput.interact_pressed.connect(_on_interact)


func _default_loadout() -> Array[PartInstance]:
	var out: Array[PartInstance] = []
	for p in creature.loadout():
		out.append(PartInstance.new(p))
	return out


func _physics_process(delta: float) -> void:
	if _dead:
		physics_move(Vector3.ZERO, delta, false)
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_respawn()
		return
	var mv := PlayerInput.get_move()
	var wish := Vector3(mv.x, 0, -mv.y)
	var aim := PlayerInput.get_aim(global_position, camera)
	for side in 2:
		if PlayerInput.is_claw_held(side) and combat.is_ready(side):
			var dir := aim
			if dir == Vector3.ZERO:
				dir = _auto_aim(combat.attack_range(side))
			combat.try_attack(side, dir if dir != Vector3.ZERO else facing)
	physics_move(wish, delta, not combat.is_busy())
	_update_pickup_focus()
	if global_position.distance_to(home_position) < HOME_RADIUS:
		health.heal(HOME_HEAL * delta)


## Nearest enemy within reach, preferring ones in front. ZERO if none.
func _auto_aim(reach: float) -> Vector3:
	var best := Vector3.ZERO
	var best_score := INF
	var max_d := maxf(reach + 2.0, 4.0)
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.team == team or c.is_dead():
			continue
		var to := c.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > max_d or d < 0.01:
			continue
		var score := d * (1.0 + facing.angle_to(to) * 0.6)
		if score < best_score:
			best_score = score
			best = to / d
	return best


func _update_pickup_focus() -> void:
	var best: PartPickup = null
	var best_d := PICKUP_RANGE
	for n in get_tree().get_nodes_in_group("pickups"):
		var p := n as PartPickup
		if p == null or not p.can_pick():
			continue
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = p
	if best != focused_pickup:
		if is_instance_valid(focused_pickup):
			focused_pickup.set_focused(false)
		focused_pickup = best
		if best:
			best.set_focused(true)
	if focused_pickup:
		var is_claw := focused_pickup.part.data.slot == PartData.Slot.CLAW
		PlayerInput.prompt = "EQUIP L" if is_claw else "EQUIP"
		PlayerInput.prompt_alt = "EQUIP R" if is_claw else ""
	else:
		PlayerInput.prompt = ""
		PlayerInput.prompt_alt = ""


func _on_interact(alt: bool) -> void:
	if _dead or not is_instance_valid(focused_pickup):
		return
	var part := focused_pickup.part
	var socket: int = Equipment.sockets_for(part.data.slot)[0]
	if part.data.slot == PartData.Slot.CLAW:
		socket = Equipment.Socket.CLAW_R if alt else Equipment.Socket.CLAW_L
	elif alt:
		return
	equip_part(socket, part, focused_pickup)


## Equips a part from a pickup (or from nowhere when pickup is null).
## The replaced part drops at your feet, so nothing is ever lost.
func equip_part(socket: int, part: PartInstance, pickup: PartPickup = null) -> void:
	var drop_at := global_position
	if pickup:
		drop_at = pickup.global_position
		pickup.consume()
	focused_pickup = null
	var old := equipment.equip(socket, part)
	if old:
		var behind := drop_at - facing * 0.9
		PartPickup.spawn(get_parent(), behind, old, false)
	if persist:
		GameState.store_loadout(creature.id, equipment)
	equipped.emit(socket, part)


func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)


func _on_died() -> void:
	super._on_died()
	_respawn_left = RESPAWN_DELAY


func _respawn() -> void:
	global_position = home_position
	velocity = Vector3.ZERO
	revive()
	respawned.emit()
