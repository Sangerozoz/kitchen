extends Node2D
class_name SpecialFlower

enum FlowerKind { SUNFLOWER, MAGENTA_STAR, BLUE_BELL }

signal collected(flower: SpecialFlower)
signal expired(flower: SpecialFlower)

var kind: FlowerKind = FlowerKind.SUNFLOWER
var collect_radius: float = 34.0
var lifetime: float = 18.0
var age: float = 0.0
var is_collected: bool = false

var _phase: float = 0.0
var _bloom_scale: float = 0.0

func setup(pos: Vector2, flower_kind: FlowerKind = FlowerKind.SUNFLOWER, dur: float = 18.0) -> void:
	position = pos
	kind = flower_kind
	lifetime = dur
	_phase = randf() * TAU

func _ready() -> void:
	z_index = 8

func _process(delta: float) -> void:
	if is_collected:
		return
	age += delta
	_bloom_scale = minf(_bloom_scale + delta * 4.5, 1.0)
	if age >= lifetime:
		expired.emit(self)
		queue_free()
		return
	queue_redraw()

func try_collect(mower_pos: Vector2, mower_radius: float) -> bool:
	if is_collected:
		return false
	if position.distance_to(mower_pos) <= collect_radius + mower_radius:
		is_collected = true
		collected.emit(self)
		queue_free()
		return true
	return false

func get_primary_color() -> Color:
	match kind:
		FlowerKind.SUNFLOWER:
			return Color(1.0, 0.82, 0.14)
		FlowerKind.MAGENTA_STAR:
			return Color(1.0, 0.32, 0.68)
		FlowerKind.BLUE_BELL:
			return Color(0.32, 0.85, 1.0)
	return Color(1.0, 0.85, 0.2)

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001 + _phase
	var remain := clampf(1.0 - age / lifetime, 0.0, 1.0)
	var pulse := 1.0 + 0.08 * sin(t * 5.0)
	var pop := ease(_bloom_scale, 0.35)
	if remain < 0.2:
		# Blink gently when about to wilt
		var blink := 0.55 + 0.45 * sin(t * 18.0)
		pop *= blink

	var primary := get_primary_color()

	# Pulsing glowing ground halo
	var halo_r := (26.0 + 5.0 * sin(t * 4.0)) * pop
	draw_circle(Vector2.ZERO, halo_r, Color(primary.r, primary.g, primary.b, 0.20))
	draw_arc(Vector2.ZERO, halo_r, 0.0, TAU, 32, Color(primary.r, primary.g, primary.b, 0.55), 2.5, true)

	# Remaining lifetime ring
	draw_arc(
		Vector2.ZERO,
		22.0 * pop,
		-PI * 0.5,
		-PI * 0.5 + TAU * remain,
		28,
		Color(1.0, 0.98, 0.82, 0.85),
		2.8,
		true
	)

	# Soft leaf cluster under flower
	var sway := Vector2(sin(t * 2.8) * 2.4, cos(t * 2.2) * 1.0)
	for i in range(4):
		var a := float(i) * PI * 0.5 + 0.35
		var leaf_dir := Vector2(cos(a), sin(a))
		draw_circle(leaf_dir * 10.0 * pop, 6.2 * pop, Color(0.16, 0.55, 0.22, 0.95))

	# Main blossom + two mini side buds
	_draw_blossom(sway, 12.5 * pop * pulse, primary, t)
	_draw_blossom(Vector2(-11.0, 7.0) * pop + sway * 0.6, 6.5 * pop, primary.lightened(0.15), t + 1.2)
	_draw_blossom(Vector2(11.0, 6.0) * pop + sway * 0.6, 6.0 * pop, primary.lightened(0.1), t + 2.4)

	# Orbiting sparkles
	for i in range(3):
		var ang := t * 2.2 + float(i) * (TAU / 3.0)
		var sp := Vector2(cos(ang), sin(ang)) * (20.0 + 3.0 * sin(t * 5.0 + float(i))) * pop
		var sr := (2.2 + 1.1 * sin(t * 7.0 + float(i) * 2.0)) * pop
		draw_circle(sp, sr, Color(1.0, 1.0, 0.86, 0.92))

func _draw_blossom(center: Vector2, radius: float, petal_col: Color, t: float) -> void:
	var petals := 7 if kind == FlowerKind.SUNFLOWER else 6
	var rot := sin(t * 1.8) * 0.15
	for i in range(petals):
		var a := rot + float(i) * (TAU / float(petals))
		var p := center + Vector2(cos(a), sin(a)) * (radius * 0.68)
		draw_circle(p, radius * 0.44, petal_col)
		draw_circle(p + Vector2(-1.0, -1.0), radius * 0.22, petal_col.lightened(0.28))

	# Flower center
	var center_col := Color(0.36, 0.20, 0.08) if kind == FlowerKind.SUNFLOWER else Color(1.0, 0.92, 0.28)
	draw_circle(center, radius * 0.42, center_col)
	draw_circle(center + Vector2(-radius * 0.1, -radius * 0.1), radius * 0.16, center_col.lightened(0.3))
