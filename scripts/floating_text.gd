extends Node2D
class_name FloatingText

static var _cached_cute_font: Font = null

var text: String = ""
var text_color: Color = Color.WHITE
var outline_color: Color = Color(0.24, 0.12, 0.03, 0.96)
var font_size: int = 24
var lifetime: float = 1.05
var rise_speed: float = 58.0

var _elapsed: float = 0.0
var _tilt: float = 0.0
var _label: Label

func setup(msg: String, pos: Vector2, col: Color = Color.WHITE, size: int = 24, dur: float = 1.05) -> void:
	text = msg
	position = pos
	text_color = col
	font_size = size
	lifetime = dur
	_tilt = randf_range(-0.07, 0.07)

func _ready() -> void:
	z_index = 65
	if _cached_cute_font == null:
		var cute: FontFile = load("res://assets/fonts/cute_font.ttf")
		var fallback: FontFile = load("res://assets/fonts/ui_font.ttf")
		if cute != null:
			if fallback != null:
				cute.fallbacks = [fallback]
			_cached_cute_font = cute
		else:
			_cached_cute_font = fallback

	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _cached_cute_font != null:
		_label.add_theme_font_override("font", _cached_cute_font)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", text_color)
	_label.add_theme_color_override("font_outline_color", outline_color)
	_label.add_theme_constant_override("outline_size", 7)
	_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.02, 0.45))
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.add_theme_constant_override("shadow_offset_y", 3)
	_label.position = Vector2(-150, -24)
	_label.size = Vector2(300, 48)
	add_child(_label)
	scale = Vector2(0.42, 0.42)
	rotation = _tilt

func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / lifetime
	if t >= 1.0:
		queue_free()
		return
	position.y -= rise_speed * delta * (1.0 - t * 0.5)
	if t < 0.16:
		var s := lerpf(0.42, 1.24, ease(t / 0.16, 0.4))
		scale = Vector2(s, s)
	elif t < 0.30:
		var s := lerpf(1.24, 1.0, (t - 0.16) / 0.14)
		scale = Vector2(s, s)
	else:
		scale = Vector2.ONE
	if t > 0.64:
		modulate.a = clampf(1.0 - (t - 0.64) / 0.36, 0.0, 1.0)
