class_name TouchControls
extends Control
## On-screen controls for phones. Feeds PlayerInput; visible only while the
## touch scheme is active.
##  - left half: floating move stick
##  - right side: two big claw buttons (hold to keep attacking; attacks auto-aim)
##  - context buttons above them while standing on a part (EQUIP / LEFT / RIGHT)

@export var stick_radius := 90.0
@export var button_radius := 78.0
@export var margin := Vector2(48, 40)

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _claw_finger: Array[int] = [-1, -1]
var _ctx_finger: Array[int] = [-1, -1]
var _ability_finger := -1
var _take_finger := -1
## 0..1 how charged the shell ability is (set by the HUD each frame).
var ability_ready := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	PlayerInput.scheme_changed.connect(_on_scheme_changed)
	_on_scheme_changed(PlayerInput.scheme)


func _on_scheme_changed(s: PlayerInput.Scheme) -> void:
	visible = s == PlayerInput.Scheme.TOUCH
	if not visible:
		_release_all()


# --- Layout ---------------------------------------------------------------------------

func _claw_center(side: int) -> Vector2:
	var right := size - margin - Vector2(button_radius, button_radius)
	if side == PlayerInput.Claw.RIGHT:
		return right
	return right - Vector2(button_radius * 2.3, -button_radius * 0.15)


## Context buttons sit above the claw buttons: main (EQUIP / LEFT) over the
## left claw, alt (RIGHT) over the right claw.
func _ctx_center(alt: bool) -> Vector2:
	return _claw_center(1 if alt else 0) - Vector2(0, button_radius * 2.15)


func _ability_center() -> Vector2:
	return _claw_center(0) - Vector2(button_radius * 2.1, -button_radius * 0.35)


func _take_center() -> Vector2:
	return _ability_center() - Vector2(0, button_radius * 1.95)


func _ctx_label(alt: bool) -> String:
	return PlayerInput.prompt_alt if alt else PlayerInput.prompt


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


# --- Events -----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag and event.index == _stick_finger:
		var offset: Vector2 = event.position - _stick_origin
		if offset.length() > stick_radius:  # drag the stick base along with the thumb
			_stick_origin = event.position - offset.normalized() * stick_radius
			offset = event.position - _stick_origin
		_stick_pos = event.position
		PlayerInput.touch_move = Vector2(offset.x, -offset.y) / stick_radius


func _on_press(finger: int, pos: Vector2) -> void:
	if PlayerInput.prompt != "" and pos.distance_to(_take_center()) < button_radius * 0.75:
		_take_finger = finger
		PlayerInput.touch_take()
		return
	if pos.distance_to(_ability_center()) < button_radius * 0.95:
		_ability_finger = finger
		PlayerInput.touch_ability()
		return
	for alt in [false, true]:
		if _ctx_label(alt) != "" and pos.distance_to(_ctx_center(alt)) < button_radius * 0.8:
			_ctx_finger[1 if alt else 0] = finger
			PlayerInput.touch_interact(alt)
			return
	for side in 2:
		if pos.distance_to(_claw_center(side)) < button_radius * 1.1:
			_claw_finger[side] = finger
			PlayerInput.touch_claw[side] = true
			return
	if pos.x < size.x * 0.55 and _stick_finger == -1:
		_stick_finger = finger
		_stick_origin = pos
		_stick_pos = pos


func _on_release(finger: int) -> void:
	if finger == _ability_finger:
		_ability_finger = -1
	if finger == _take_finger:
		_take_finger = -1
	if finger == _stick_finger:
		_stick_finger = -1
		PlayerInput.touch_move = Vector2.ZERO
	for i in 2:
		if _claw_finger[i] == finger:
			_claw_finger[i] = -1
			PlayerInput.touch_claw[i] = false
		if _ctx_finger[i] == finger:
			_ctx_finger[i] = -1


func _release_all() -> void:
	_stick_finger = -1
	for i in 2:
		_claw_finger[i] = -1
		_ctx_finger[i] = -1
		PlayerInput.touch_claw[i] = false
	PlayerInput.touch_move = Vector2.ZERO


# --- Drawing ------------------------------------------------------------------------------

func _draw() -> void:
	if _stick_finger != -1:
		draw_circle(_stick_origin, stick_radius, Color(1, 1, 1, 0.12))
		draw_arc(_stick_origin, stick_radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(_stick_pos, stick_radius * 0.4, Color(1, 1, 1, 0.45))
	_button(_claw_center(0), button_radius, Color(1.0, 0.55, 0.35), _claw_finger[0] != -1, "L CLAW", 22)
	_button(_claw_center(1), button_radius, Color(1.0, 0.8, 0.35), _claw_finger[1] != -1, "R CLAW", 22)
	_button(_ability_center(), button_radius * 0.85, Color(0.45, 0.8, 1.0), _ability_finger != -1, "ABILITY", 17)
	if ability_ready < 1.0:
		draw_arc(_ability_center(), button_radius * 0.85 + 5.0, -PI * 0.5, -PI * 0.5 + TAU * ability_ready, 32, Color(1, 1, 1, 0.8), 5.0)
	if PlayerInput.prompt != "":
		_button(_take_center(), button_radius * 0.65, Color(0.6, 1.0, 0.6), _take_finger != -1, "TAKE", 16)
	for alt in [false, true]:
		var label := _ctx_label(alt)
		if label != "":
			_button(_ctx_center(alt), button_radius * 0.7, Color(0.35, 0.85, 1.0), _ctx_finger[1 if alt else 0] != -1, label, 17)


func _button(centre: Vector2, r: float, col: Color, pressed: bool, label: String, fs: int) -> void:
	draw_circle(centre, r, Color(col, 0.55 if pressed else 0.28))
	draw_arc(centre, r, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	var font := get_theme_default_font()
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, centre + Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
