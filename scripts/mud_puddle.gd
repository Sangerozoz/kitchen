extends Node2D
class_name MudPuddle

var radius: float = 24.0
var lifetime: float = 9.0
var age: float = 0.0
var _seed: float = 0.0

func setup(pos: Vector2, rad: float = 24.0) -> void:
	position = pos
	radius = rad
	_seed = randf() * 100.0

func _ready() -> void:
	z_index = 5

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	var remain := clampf(1.0 - age / lifetime, 0.0, 1.0)
	if remain < 0.25:
		modulate.a = remain / 0.25
	else:
		modulate.a = minf(age * 4.0, 1.0)

func contains_point(p: Vector2, extra_rad: float = 10.0) -> bool:
	return position.distance_to(p) <= radius + extra_rad

func _draw() -> void:
	var dark_mud := Color(0.32, 0.20, 0.10, 0.86)
	var mid_mud := Color(0.44, 0.29, 0.16, 0.88)
	var sheen := Color(0.64, 0.50, 0.36, 0.45)

	# Organic splat lobes
	draw_circle(Vector2.ZERO, radius * 0.86, dark_mud)
	for i in range(5):
		var a := _seed + float(i) * (TAU / 5.0)
		var off := Vector2(cos(a), sin(a)) * (radius * 0.48)
		draw_circle(off, radius * (0.42 + 0.12 * sin(_seed + float(i) * 3.1)), dark_mud)
	draw_circle(Vector2(-2.0, -2.0), radius * 0.62, mid_mud)
	draw_circle(Vector2(-radius * 0.28, -radius * 0.26), radius * 0.24, sheen)
	# Outer tiny splash drops
	for i in range(3):
		var a := _seed * 1.7 + float(i) * 2.1
		draw_circle(Vector2(cos(a), sin(a)) * (radius * 1.15), 3.6, dark_mud)
