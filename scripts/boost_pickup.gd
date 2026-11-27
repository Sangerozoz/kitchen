extends Node2D
class_name BoostPickup

signal collected(pickup: BoostPickup)
signal expired(pickup: BoostPickup)

const RAINBOW_COLS := [
	Color(1.0, 0.28, 0.32),
	Color(1.0, 0.62, 0.14),
	Color(1.0, 0.90, 0.20),
	Color(0.32, 0.88, 0.40),
	Color(0.24, 0.84, 1.0),
	Color(0.70, 0.42, 1.0),
]

var collect_radius: float = 34.0
var lifetime: float = 18.0
var age: float = 0.0
var is_collected: bool = false
var lifetime_paused: bool = false

var _phase: float = 0.0
var _pop_scale: float = 0.0
var _redraw_accum: float = 0.0

func setup(pos: Vector2, dur: float = 18.0) -> void:
	position = pos
	lifetime = dur
	_phase = randf() * TAU

func _ready() -> void:
	z_index = 9

func _process(delta: float) -> void:
	if is_collected:
		return
	_pop_scale = minf(_pop_scale + delta * 4.5, 1.0)
	if not lifetime_paused:
		age += delta
		if age >= lifetime:
			expired.emit(self)
			queue_free()
			return
	_redraw_accum += delta
	if _redraw_accum >= 0.05:
		_redraw_accum = 0.0
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

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001 + _phase
	var remain := clampf(1.0 - age / lifetime, 0.0, 1.0)
	var pop := ease(_pop_scale, 0.35)
	if remain < 0.2:
		pop *= (0.55 + 0.45 * sin(t * 18.0))

	var bob := Vector2(0.0, sin(t * 4.4) * 3.8) * pop
	var pulse := 1.0 + 0.07 * sin(t * 6.0)

	# Ground shadow
	draw_circle(Vector2(0.0, 12.0) * pop, 18.0 * pop, Color(0.06, 0.16, 0.04, 0.30))

	# Spinning segmented rainbow aura ring!
	var halo_r := (27.0 + 3.5 * sin(t * 5.0)) * pop
	draw_circle(Vector2.ZERO, halo_r, Color(1.0, 0.96, 0.72, 0.18))
	var seg_arc := TAU / float(RAINBOW_COLS.size())
	for i in range(RAINBOW_COLS.size()):
		var a0 := t * 2.2 + float(i) * seg_arc
		var a1 := a0 + seg_arc * 0.85
		draw_arc(Vector2.ZERO, halo_r, a0, a1, 6, Color(RAINBOW_COLS[i].r, RAINBOW_COLS[i].g, RAINBOW_COLS[i].b, 0.88), 3.4, false)

	# Remaining lifetime ring
	draw_arc(
		Vector2.ZERO,
		22.0 * pop,
		-PI * 0.5,
		-PI * 0.5 + TAU * remain,
		20,
		Color(1.0, 0.98, 0.86, 0.92),
		2.6,
		false
	)

	# Glossy cartoon candy orb with thick warm chocolate outline (matches Start Screen!)
	var badge_r := 18.0 * pop * pulse
	draw_circle(bob, badge_r + 2.4, Color(0.32, 0.16, 0.03))
	draw_circle(bob, badge_r, Color(1.0, 0.56, 0.08))
	draw_circle(bob + Vector2(0.0, -1.5 * pop), badge_r * 0.84, Color(1.0, 0.78, 0.16))
	# Cute white jelly shine highlight on top-left
	draw_circle(bob + Vector2(-badge_r * 0.36, -badge_r * 0.38), badge_r * 0.24, Color(1.0, 1.0, 0.94, 0.82))

	# Bold cartoon lightning bolt inside badge
	var s := pop * pulse
	var bolt := PackedVector2Array([
		bob + Vector2(2.2, -11.5) * s,
		bob + Vector2(-7.2, 1.2) * s,
		bob + Vector2(-0.8, 1.2) * s,
		bob + Vector2(-3.2, 11.5) * s,
		bob + Vector2(7.6, -1.8) * s,
		bob + Vector2(1.2, -1.8) * s,
	])
	draw_colored_polygon(bolt, Color(1.0, 1.0, 0.94))

	# Orbiting rainbow mini stars
	for i in range(4):
		var ang := t * 3.0 + float(i) * (TAU / 4.0)
		var sp := Vector2(cos(ang), sin(ang)) * 24.0 * pop
		draw_circle(sp, 2.8 * pop, RAINBOW_COLS[(i * 2) % RAINBOW_COLS.size()])
