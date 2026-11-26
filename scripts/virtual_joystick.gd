extends Control
class_name ThumbJoystick

signal input_changed(vec: Vector2)

var enabled: bool = false:
	set(v):
		enabled = v
		if not enabled:
			_reset_touch()
		queue_redraw()

var max_radius: float = 64.0
var deadzone: float = 0.10
var output: Vector2 = Vector2.ZERO
var has_moved_once: bool = false
var show_idle_ring: bool = true

# Rect (in global screen coords) excluded from joystick touch capture (e.g. Sound button)
var excluded_rect: Rect2 = Rect2()
var top_exclude_y: float = 110.0
var bottom_safe_margin: float = 24.0

var _active_touch_idx: int = -1
var _base_pos: Vector2 = Vector2.ZERO
var _knob_pos: Vector2 = Vector2.ZERO
var _is_pressed: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if not enabled:
		return

	if event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		if ev.pressed:
			if _active_touch_idx == -1 and _can_capture(ev.position):
				_active_touch_idx = ev.index
				_is_pressed = true
				_base_pos = ev.position
				_knob_pos = ev.position
				_update_output(ev.position)
				queue_redraw()
		else:
			if ev.index == _active_touch_idx:
				_reset_touch()
				queue_redraw()
	elif event is InputEventScreenDrag:
		var ev := event as InputEventScreenDrag
		if ev.index == _active_touch_idx and _is_pressed:
			_update_output(ev.position)
			queue_redraw()

func _can_capture(pos: Vector2) -> bool:
	# Ignore top HUD strip (including safe-area notch) so taps on top don't accidentally steer
	if pos.y < top_exclude_y:
		return false
	if excluded_rect.has_point(pos):
		return false
	return true

func _update_output(touch_pos: Vector2) -> void:
	var diff := touch_pos - _base_pos
	var dist := diff.length()
	if dist > max_radius:
		diff = diff.normalized() * max_radius
		dist = max_radius
	_knob_pos = _base_pos + diff

	var ratio := dist / max_radius
	if ratio < deadzone:
		output = Vector2.ZERO
	else:
		var remapped := (ratio - deadzone) / (1.0 - deadzone)
		output = diff.normalized() * remapped
		if remapped > 0.15:
			has_moved_once = true
	input_changed.emit(output)

func _reset_touch() -> void:
	_active_touch_idx = -1
	_is_pressed = false
	output = Vector2.ZERO
	input_changed.emit(Vector2.ZERO)

func _draw() -> void:
	if not enabled:
		return

	if _is_pressed:
		# Outer soft ring
		draw_circle(_base_pos, max_radius, Color(0.08, 0.16, 0.10, 0.28))
		draw_arc(_base_pos, max_radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.58), 3.0, true)
		# Direction line
		if output.length() > 0.05:
			draw_line(_base_pos, _knob_pos, Color(0.68, 0.96, 0.42, 0.65), 5.0, true)
		# Thumb knob
		draw_circle(_knob_pos, 26.0, Color(1.0, 1.0, 1.0, 0.85))
		draw_circle(_knob_pos, 18.0, Color(0.32, 0.78, 0.28, 0.92))
	elif show_idle_ring and not has_moved_once:
		# Gentle resting hint indicator in lower center above bottom safe area before first touch
		var hint_center := Vector2(size.x * 0.5, size.y - bottom_safe_margin - 128.0)
		var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.005)
		draw_circle(hint_center, 52.0 * pulse, Color(0.08, 0.16, 0.10, 0.22))
		draw_arc(hint_center, 52.0 * pulse, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.45), 2.4, true)
		draw_circle(hint_center, 20.0, Color(1.0, 1.0, 1.0, 0.50))

func _process(_delta: float) -> void:
	if enabled and show_idle_ring and not _is_pressed and not has_moved_once:
		queue_redraw()
