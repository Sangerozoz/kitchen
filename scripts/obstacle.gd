extends StaticBody2D
class_name LawnObstacle

enum Kind { ROCK, TREE }

var kind: Kind = Kind.ROCK
var radius: float = 28.0
var canopy_radius: float = 54.0

var _seed_val: float = 0.0
var _rock_pts: PackedVector2Array = PackedVector2Array()
var _rock_hi_pts: PackedVector2Array = PackedVector2Array()
var _moss_pts: PackedVector2Array = PackedVector2Array()
var _canopy_node: Node2D = null
var _canopy_alpha: float = 1.0
var _mower_ref: Node2D = null

func setup(obs_kind: Kind, pos: Vector2, rad: float, mower: Node2D = null) -> void:
	kind = obs_kind
	position = pos
	radius = rad
	canopy_radius = rad * 2.45
	_mower_ref = mower
	_seed_val = randf() * 100.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	if kind == Kind.ROCK:
		add_to_group("rocks")
		z_index = 12
		_generate_rock_shape()
	else:
		add_to_group("trees")
		z_index = 12
		_build_tree_canopy()

	var shape := CircleShape2D.new()
	shape.radius = radius * (0.86 if kind == Kind.ROCK else 0.92)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	queue_redraw()

func _process(delta: float) -> void:
	if kind == Kind.TREE and _canopy_node != null:
		var target_alpha := 1.0
		if is_instance_valid(_mower_ref):
			var dist := global_position.distance_to(_mower_ref.global_position)
			if dist < canopy_radius + 26.0:
				target_alpha = 0.42
		_canopy_alpha = lerpf(_canopy_alpha, target_alpha, delta * 8.0)
		_canopy_node.modulate.a = _canopy_alpha
		_canopy_node.queue_redraw()

func _generate_rock_shape() -> void:
	var count := 9
	_rock_pts.clear()
	_rock_hi_pts.clear()
	_moss_pts.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_seed_val * 1000.0) + 17
	for i in range(count):
		var a := float(i) * TAU / float(count)
		var r := radius * rng.randf_range(0.84, 1.08)
		var pt := Vector2(cos(a) * r, sin(a) * r * 0.86)
		_rock_pts.append(pt)
		_rock_hi_pts.append(pt * 0.68 + Vector2(-radius * 0.14, -radius * 0.16))
	for i in range(5):
		var a := -2.2 + float(i) * 0.45
		var r := radius * rng.randf_range(0.6, 0.85)
		_moss_pts.append(Vector2(cos(a) * r, sin(a) * r * 0.72) + Vector2(-radius * 0.08, -radius * 0.1))

func _build_tree_canopy() -> void:
	_canopy_node = TreeCanopyDrawer.new()
	_canopy_node.canopy_radius = canopy_radius
	_canopy_node.seed_val = _seed_val
	_canopy_node.z_index = 40
	add_child(_canopy_node)

func _draw() -> void:
	if kind == Kind.ROCK:
		# Ground shadow
		draw_circle(Vector2(4.0, 6.0), radius * 0.98, Color(0.05, 0.12, 0.06, 0.34))
		# Main rock body
		if _rock_pts.size() >= 3:
			draw_colored_polygon(_rock_pts, Color(0.46, 0.48, 0.50))
			draw_colored_polygon(_rock_hi_pts, Color(0.64, 0.66, 0.68))
			if _moss_pts.size() >= 3:
				draw_colored_polygon(_moss_pts, Color(0.28, 0.56, 0.24, 0.78))
			# Subtle rock outline & crack
			var outline := _rock_pts.duplicate()
			outline.append(_rock_pts[0])
			draw_polyline(outline, Color(0.26, 0.28, 0.30, 0.85), 2.2, true)
			draw_line(
				Vector2(-radius * 0.22, radius * 0.05),
				Vector2(radius * 0.24, radius * 0.28),
				Color(0.30, 0.32, 0.34, 0.75),
				1.8,
				true
			)
	else:
		# Tree ground shadow & exposed roots + wooden trunk
		draw_circle(Vector2(10.0, 14.0), canopy_radius * 0.88, Color(0.04, 0.11, 0.05, 0.26))
		# Roots
		for i in range(5):
			var a := float(i) * TAU / 5.0 + _seed_val
			var tip := Vector2(cos(a), sin(a)) * (radius * 1.32)
			draw_line(Vector2.ZERO, tip, Color(0.38, 0.24, 0.13), 5.5, true)
		# Trunk base
		draw_circle(Vector2.ZERO, radius, Color(0.42, 0.26, 0.14))
		draw_circle(Vector2(-radius * 0.18, -radius * 0.18), radius * 0.62, Color(0.54, 0.36, 0.20))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.24, 0.14, 0.07), 2.2, true)


class TreeCanopyDrawer extends Node2D:
	var canopy_radius: float = 54.0
	var seed_val: float = 0.0

	func _draw() -> void:
		var t := Time.get_ticks_msec() * 0.001 + seed_val
		var sway := Vector2(sin(t * 1.5) * 3.0, cos(t * 1.2) * 1.8)
		var base := Vector2(0.0, -8.0) + sway

		# Outer dark foliage clusters
		var lobes := 6
		for i in range(lobes):
			var a := float(i) * TAU / float(lobes) + seed_val * 0.3
			var pos := base + Vector2(cos(a), sin(a)) * (canopy_radius * 0.44)
			draw_circle(pos, canopy_radius * 0.52, Color(0.12, 0.40, 0.17))

		# Mid bright foliage clusters
		for i in range(5):
			var a := float(i) * TAU / 5.0 + 0.5 + seed_val * 0.2
			var pos := base + Vector2(-4.0, -5.0) + Vector2(cos(a), sin(a)) * (canopy_radius * 0.32)
			draw_circle(pos, canopy_radius * 0.42, Color(0.20, 0.56, 0.22))

		# Sunlit crown highlight
		draw_circle(base + Vector2(-canopy_radius * 0.18, -canopy_radius * 0.20), canopy_radius * 0.34, Color(0.34, 0.72, 0.28, 0.92))
		draw_circle(base + Vector2(-canopy_radius * 0.25, -canopy_radius * 0.26), canopy_radius * 0.16, Color(0.50, 0.84, 0.36, 0.85))
