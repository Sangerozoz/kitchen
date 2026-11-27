extends StaticBody2D
class_name LawnObstacle

enum Kind { ROCK, TREE }

var kind: Kind = Kind.ROCK
var radius: float = 28.0
var canopy_radius: float = 54.0
var is_shattered: bool = false

var _seed_val: float = 0.0
var _rock_pts: PackedVector2Array = PackedVector2Array()
var _rock_hi_pts: PackedVector2Array = PackedVector2Array()
var _moss_pts: PackedVector2Array = PackedVector2Array()
var _canopy_node: Node2D = null
var _canopy_alpha: float = 1.0
var _mower_ref: Node2D = null
var _rock_tex: Texture2D = null
var _rot_angle: float = 0.0

func setup(obs_kind: Kind, pos: Vector2, rad: float, mower: Node2D = null) -> void:
	kind = obs_kind
	position = pos
	radius = rad
	canopy_radius = rad * 2.55
	_mower_ref = mower
	_seed_val = randf() * 100.0
	_rot_angle = randf() * TAU

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	if kind == Kind.ROCK:
		add_to_group("rocks")
		z_index = 12
		_rock_tex = load("res://assets/sprites/rock_boulder.png")
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

func shatter() -> void:
	if is_shattered:
		return
	is_shattered = true
	collision_layer = 0
	collision_mask = 0
	visible = false
	queue_free()

func _process(delta: float) -> void:
	if kind == Kind.TREE and _canopy_node != null:
		var target_alpha := 1.0
		if is_instance_valid(_mower_ref):
			var dist_sq := global_position.distance_squared_to(_mower_ref.global_position)
			var check_r := canopy_radius + 26.0
			if dist_sq < check_r * check_r:
				target_alpha = 0.42
		if absf(_canopy_alpha - target_alpha) > 0.005:
			_canopy_alpha = lerpf(_canopy_alpha, target_alpha, minf(delta * 8.0, 1.0))
			_canopy_node.modulate.a = _canopy_alpha
		# Gentle GPU-free node transform sway instead of rebuilding 13 draw_circles 60x/sec!
		var t := Time.get_ticks_msec() * 0.001 + _seed_val
		_canopy_node.position = Vector2(sin(t * 1.5) * 3.0, cos(t * 1.2) * 1.8)

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
		draw_circle(Vector2(4.0, 6.0), radius * 1.04, Color(0.05, 0.12, 0.06, 0.34))
		if _rock_tex != null:
			var sz := radius * 2.35
			draw_set_transform(Vector2.ZERO, _rot_angle, Vector2.ONE)
			draw_texture_rect(_rock_tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif _rock_pts.size() >= 3:
			draw_colored_polygon(_rock_pts, Color(0.46, 0.48, 0.50))
			draw_colored_polygon(_rock_hi_pts, Color(0.64, 0.66, 0.68))
	else:
		# Tree ground shadow & exposed roots + wooden trunk
		draw_circle(Vector2(10.0, 14.0), canopy_radius * 0.86, Color(0.04, 0.11, 0.05, 0.28))
		for i in range(5):
			var a := float(i) * TAU / 5.0 + _seed_val
			var tip := Vector2(cos(a), sin(a)) * (radius * 1.32)
			draw_line(Vector2.ZERO, tip, Color(0.38, 0.24, 0.13), 5.5, false)
		draw_circle(Vector2.ZERO, radius, Color(0.42, 0.26, 0.14))
		draw_circle(Vector2(-radius * 0.18, -radius * 0.18), radius * 0.62, Color(0.54, 0.36, 0.20))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0.24, 0.14, 0.07), 2.2, false)


class TreeCanopyDrawer extends Node2D:
	var canopy_radius: float = 54.0
	var seed_val: float = 0.0
	var _tex: Texture2D = null

	func _ready() -> void:
		_tex = load("res://assets/sprites/tree_canopy.png")

	func _draw() -> void:
		if _tex != null:
			var sz := canopy_radius * 2.15
			draw_set_transform(Vector2(0.0, -8.0), fmod(seed_val, TAU), Vector2.ONE)
			draw_texture_rect(_tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(Vector2(0.0, -8.0), canopy_radius * 0.8, Color(0.18, 0.52, 0.20))
