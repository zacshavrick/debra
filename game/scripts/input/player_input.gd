extends Node
## Autoload `PlayerInput`: the ONLY code that reads input devices.
## Gameplay asks it for intent (move, aim, claw attacks, equip) and never
## touches Input, so keyboard+mouse, gamepad and touch stay interchangeable.
## The active scheme follows whichever device was used last.

signal scheme_changed(scheme: Scheme)
## Equip / interact. alt = the second choice (e.g. "put this claw on the RIGHT").
signal interact_pressed(alt: bool)
## Debug-only helpers (F-keys), handled by the arena.
signal debug_pressed(key: int)
## Back to the map (Esc / Start / the MAP button).
signal menu_pressed

enum Scheme { KEYBOARD_MOUSE, GAMEPAD, TOUCH }
enum Claw { LEFT, RIGHT }

@export var stick_deadzone := 0.2

var scheme: Scheme = Scheme.KEYBOARD_MOUSE

## Written by TouchControls.
var touch_move := Vector2.ZERO
var touch_claw: Array[bool] = [false, false]

## Context labels set by gameplay each frame ("EQUIP", "EQUIP L"...). "" = none.
var prompt := ""
var prompt_alt := ""

var _override_active := false
var _override_move := Vector2.ZERO
var _override_aim := Vector3.ZERO
var _claw_until: Array[int] = [0, 0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_default_bindings()
	if Platform.is_mobile:
		scheme = Scheme.TOUCH


# --- Public API -------------------------------------------------------------

## Movement intent. x = right, y = up the screen. Length <= 1.
func get_move() -> Vector2:
	if _override_active:
		return _override_move
	if scheme == Scheme.TOUCH:
		return touch_move.limit_length(1.0)
	return Input.get_vector("move_left", "move_right", "move_back", "move_forward", stick_deadzone).limit_length(1.0)


## Aim direction on the ground plane (world space), or ZERO when the player
## isn't aiming. Gameplay then auto-aims or keeps facing.
## Mouse: towards the cursor. Gamepad: right stick. Touch: always ZERO.
func get_aim(origin: Vector3, cam: Camera3D) -> Vector3:
	if _override_active:
		return _override_aim
	match scheme:
		Scheme.KEYBOARD_MOUSE:
			if cam == null or not cam.is_inside_tree():
				return Vector3.ZERO
			var mp := cam.get_viewport().get_mouse_position()
			var from := cam.project_ray_origin(mp)
			var dir := cam.project_ray_normal(mp)
			if absf(dir.y) < 0.001:
				return Vector3.ZERO
			var hit := from + dir * ((origin.y - from.y) / dir.y)
			var d := Vector3(hit.x - origin.x, 0, hit.z - origin.z)
			return d.normalized() if d.length() > 0.3 else Vector3.ZERO
		Scheme.GAMEPAD:
			var s := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", stick_deadzone)
			return Vector3(s.x, 0, s.y).normalized() if s != Vector2.ZERO else Vector3.ZERO
	return Vector3.ZERO


## Claw attack held (hold to keep attacking). side: Claw.LEFT / Claw.RIGHT.
func is_claw_held(side: int) -> bool:
	if Time.get_ticks_msec() < _claw_until[side]:
		return true
	if _override_active:
		return false
	if scheme == Scheme.TOUCH:
		return touch_claw[side]
	if Input.is_action_pressed("claw_left" if side == Claw.LEFT else "claw_right"):
		return true
	if scheme == Scheme.KEYBOARD_MOUSE:
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT if side == Claw.LEFT else MOUSE_BUTTON_RIGHT)
	return false


## Short key hint for the HUD ("E", "A"...). Touch shows buttons instead.
func hint(alt: bool) -> String:
	match scheme:
		Scheme.KEYBOARD_MOUSE:
			return "R" if alt else "E"
		Scheme.GAMEPAD:
			return "Y" if alt else "A"
	return ""


func claw_hint(side: int) -> String:
	match scheme:
		Scheme.KEYBOARD_MOUSE:
			return "LMB / J" if side == Claw.LEFT else "RMB / K"
		Scheme.GAMEPAD:
			return "X" if side == Claw.LEFT else "B"
	return ""


## Touch buttons (called by TouchControls).
func touch_interact(alt: bool) -> void:
	_set_scheme(Scheme.TOUCH)
	interact_pressed.emit(alt)


## For tests and cutscenes: replace player intent. Pass `null` to clear.
func set_override(move: Variant, aim := Vector3.ZERO) -> void:
	_override_active = move != null
	_override_move = (move as Vector2).limit_length(1.0) if move != null else Vector2.ZERO
	_override_aim = aim


## For tests: hold a claw button for sec seconds.
func press_claw(side: int, sec := 0.2) -> void:
	_claw_until[side] = Time.get_ticks_msec() + int(sec * 1000.0)


# --- Device handling --------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Mouse events synthesized from touch must not flip us to keyboard/mouse.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event.is_action_pressed("menu"):
		menu_pressed.emit()
	if event.is_action_pressed("interact"):
		interact_pressed.emit(false)
	elif event.is_action_pressed("interact_alt"):
		interact_pressed.emit(true)
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_scheme(Scheme.TOUCH)
	elif event is InputEventKey:
		_set_scheme(Scheme.KEYBOARD_MOUSE)
		if event.pressed and not event.echo and event.keycode >= KEY_F1 and event.keycode <= KEY_F10:
			debug_pressed.emit(event.keycode)
	elif event is InputEventMouseButton and event.pressed:
		# Clicks only: stray mouse motion (hover, browsers on touch devices)
		# must not hide the touch controls.
		_set_scheme(Scheme.KEYBOARD_MOUSE)
	elif event is InputEventJoypadButton:
		_set_scheme(Scheme.GAMEPAD)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		_set_scheme(Scheme.GAMEPAD)


func _set_scheme(s: Scheme) -> void:
	if s == scheme:
		return
	scheme = s
	print("Input scheme: ", Scheme.keys()[s])
	scheme_changed.emit(s)


func _register_default_bindings() -> void:
	_bind("move_forward", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_back", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("aim_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_bind("aim_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_bind("aim_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_bind("aim_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_bind("claw_left", [KEY_J], [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_bind("claw_right", [KEY_K], [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_bind("interact", [KEY_E, KEY_F], [JOY_BUTTON_A], [])
	_bind("interact_alt", [KEY_R], [JOY_BUTTON_Y], [])
	_bind("menu", [KEY_ESCAPE], [JOY_BUTTON_START], [])


func _bind(action: StringName, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		return  # project.godot or a rebinding menu already defined it
	InputMap.add_action(action, 0.2)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)
