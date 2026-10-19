class_name Equipment
extends Node
## What a crab is wearing, per socket. Sums stats. Knows nothing about
## combat or visuals: CrabBody draws the *displayed* parts, Crab applies stats.
##
## Transmog-ready: each socket stores the equipped part (stats) and an
## optional display override (look). Transmog unlocks late game; until then
## nothing sets a display override.

signal changed(socket: int)

enum Socket { HEAD, SHELL, CLAW_L, CLAW_R, LEGS }
const SOCKET_COUNT := 5
const SOCKET_NAMES := ["Head", "Shell", "Left claw", "Right claw", "Legs"]

var _equipped: Array[PartInstance] = [null, null, null, null, null]
var _display: Array[PartInstance] = [null, null, null, null, null]


static func accepts(socket: int, slot: PartData.Slot) -> bool:
	match socket:
		Socket.HEAD:
			return slot == PartData.Slot.HEAD
		Socket.SHELL:
			return slot == PartData.Slot.SHELL
		Socket.CLAW_L, Socket.CLAW_R:
			return slot == PartData.Slot.CLAW
		Socket.LEGS:
			return slot == PartData.Slot.LEGS
	return false


static func sockets_for(slot: PartData.Slot) -> Array[int]:
	var out: Array[int] = []
	for s in SOCKET_COUNT:
		if accepts(s, slot):
			out.append(s)
	return out


func get_part(socket: int) -> PartInstance:
	return _equipped[socket]


## The part whose look is shown in this socket (transmog override or equipped).
func get_displayed(socket: int) -> PartInstance:
	return _display[socket] if _display[socket] != null else _equipped[socket]


## Equips `part` and returns what was there before (or null).
func equip(socket: int, part: PartInstance) -> PartInstance:
	assert(part == null or accepts(socket, part.data.slot), "part does not fit socket")
	var old := _equipped[socket]
	_equipped[socket] = part
	changed.emit(socket)
	return old


## Transmog: show `look` in a socket without changing stats. null clears it.
func set_display(socket: int, look: PartInstance) -> void:
	_display[socket] = look
	changed.emit(socket)


func load_loadout(parts: Array[PartData], rarity: int = Rarity.Tier.COMMON) -> void:
	for s in SOCKET_COUNT:
		equip(s, PartInstance.new(parts[s], rarity) if parts[s] else null)


func total(stat_name: StringName) -> float:
	var t := 0.0
	for p in _equipped:
		if p:
			t += p.stat(stat_name)
	return t


func to_array() -> Array:
	var out := []
	for p in _equipped:
		out.append(p.to_dict() if p else null)
	return out
