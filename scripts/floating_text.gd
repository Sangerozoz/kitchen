extends Node2D
class_name FloatingText

var text: String = ""
var text_color: Color = Color.WHITE
var font_size: int = 20
var lifetime: float = 0.95
var rise_speed: float = 54.0

var _elapsed: float = 0.0
var _label: Label

func setup(msg: String, pos: Vector2, col: Color = Color.WHITE, size: int = 20, dur: float = 0.95) -> void:
	text = msg
	position = pos
	text_color = col
	font_size = size
	lifetime = dur

func _ready() -> void:
	z_index = 60
	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", text_color)
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.08, 0.92))
	_label.add_theme_constant_override("outline_size", 5)
	_label.position = Vector2(-120, -18)
	_label.size = Vector2(240, 36)
	add_child(_label)
	scale = Vector2(0.55, 0.55)

func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / lifetime
	if t >= 1.0:
		queue_free()
		return
	position.y -= rise_speed * delta * (1.0 - t * 0.45)
	if t < 0.16:
		var s := lerpf(0.55, 1.15, t / 0.16)
		scale = Vector2(s, s)
	elif t < 0.28:
		var s := lerpf(1.15, 1.0, (t - 0.16) / 0.12)
		scale = Vector2(s, s)
	if t > 0.62:
		modulate.a = clampf(1.0 - (t - 0.62) / 0.38, 0.0, 1.0)
