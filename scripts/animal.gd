extends CharacterBody2D
class_name LawnAnimal

enum AnimalType { SHEEP, DOG, PIG }

signal interfered_with_mower(animal: LawnAnimal, kind: AnimalType, push_dir: Vector2)
signal spawned_mud(pos: Vector2)

var animal_type: AnimalType = AnimalType.SHEEP
var bounds: Rect2 = Rect2(60, 60, 900, 1400)
var mower_ref: Node2D = null
var preview_mode: bool = false

var _state: String = "wander" # wander, pause, chase, flee
var _state_timer: float = 2.0
var _move_dir: Vector2 = Vector2.RIGHT
var _facing: float = 0.0
var _walk_cycle: float = 0.0
var _hit_cooldown: float = 0.0
var _mud_timer: float = 2.4
var _alert_timer: float = 0.0
var _body_radius: float = 19.0
var _redraw_accum: float = 0.0

func setup(a_type: AnimalType, pos: Vector2, play_bounds: Rect2, mower: Node2D) -> void:
	animal_type = a_type
	position = pos
	bounds = play_bounds.grow(-34.0)
	mower_ref = mower
	_move_dir = Vector2.from_angle(randf() * TAU)
	_facing = _move_dir.angle()
	_state_timer = randf_range(1.2, 3.0)
	_mud_timer = randf_range(2.2, 3.8)
	match animal_type:
		AnimalType.SHEEP:
			_body_radius = 20.0
		AnimalType.DOG:
			_body_radius = 16.0
		AnimalType.PIG:
			_body_radius = 18.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 # Collide with rocks & trees only
	z_index = 22
	add_to_group("animals")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = _body_radius * 0.82
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	_alert_timer = maxf(0.0, _alert_timer - delta)
	_state_timer -= delta

	var dist_to_mower := 9999.0
	var to_mower := Vector2.ZERO
	if is_instance_valid(mower_ref):
		to_mower = mower_ref.global_position - global_position
		dist_to_mower = to_mower.length()

	var speed := 0.0
	if preview_mode:
		speed = _update_peaceful_wander(dist_to_mower, to_mower)
	else:
		match animal_type:
			AnimalType.SHEEP:
				speed = _update_sheep(delta, dist_to_mower, to_mower)
			AnimalType.DOG:
				speed = _update_dog(delta, dist_to_mower, to_mower)
			AnimalType.PIG:
				speed = _update_pig(delta, dist_to_mower, to_mower)

	velocity = _move_dir * speed
	if speed > 4.0:
		_facing = lerp_angle(_facing, _move_dir.angle(), minf(delta * 9.0, 1.0))
		_walk_cycle += delta * (speed * 0.11)

	move_and_slide()

	# Bounce smoothly off obstacles or fence bounds
	if get_slide_collision_count() > 0:
		var n := get_slide_collision(0).get_normal()
		_move_dir = _move_dir.bounce(n).normalized()
	if position.x < bounds.position.x:
		position.x = bounds.position.x
		_move_dir.x = absf(_move_dir.x)
	elif position.x > bounds.end.x:
		position.x = bounds.end.x
		_move_dir.x = -absf(_move_dir.x)
	if position.y < bounds.position.y:
		position.y = bounds.position.y
		_move_dir.y = absf(_move_dir.y)
	elif position.y > bounds.end.y:
		position.y = bounds.end.y
		_move_dir.y = -absf(_move_dir.y)

	# Check mower bump interference (disabled during Home screen peaceful preview)
	if not preview_mode and _hit_cooldown <= 0.0 and is_instance_valid(mower_ref):
		var contact_dist := _body_radius + 20.0
		if dist_to_mower < contact_dist:
			_hit_cooldown = 2.0
			var push_dir := to_mower.normalized() if dist_to_mower > 0.1 else Vector2.RIGHT
			interfered_with_mower.emit(self, animal_type, push_dir)
			_state = "flee"
			_state_timer = 1.6
			_move_dir = (-push_dir).rotated(randf_range(-0.5, 0.5)).normalized()

	_redraw_accum += delta
	if _redraw_accum >= 0.033:
		_redraw_accum = 0.0
		queue_redraw()

func _update_peaceful_wander(dist: float, to_mower: Vector2) -> float:
	_alert_timer = 0.0
	# Gently curve away from the parked mower so animals stroll around it peacefully
	if dist < 115.0 and dist > 0.1:
		var away := (-to_mower).normalized()
		var tangent := away.rotated(0.55)
		_move_dir = _move_dir.lerp(tangent, 0.16).normalized()
		_state = "wander"
		return 64.0
	if _state == "pause":
		if _state_timer <= 0.0:
			_state = "wander"
			_move_dir = Vector2.from_angle(randf() * TAU)
			_state_timer = randf_range(2.0, 3.8)
		return 0.0
	if _state_timer <= 0.0:
		if randf() < 0.30:
			_state = "pause"
			_state_timer = randf_range(1.0, 2.2)
		else:
			_move_dir = _move_dir.rotated(randf_range(-1.3, 1.3)).normalized()
			_state_timer = randf_range(1.8, 3.4)
	match animal_type:
		AnimalType.DOG:
			return 78.0
		AnimalType.PIG:
			return 64.0
		_:
			return 54.0

func _update_sheep(_delta: float, _dist: float, _to_mower: Vector2) -> float:
	if _state == "flee":
		if _state_timer <= 0.0:
			_state = "wander"
			_state_timer = randf_range(2.0, 3.6)
		return 145.0
	if _state == "pause":
		if _state_timer <= 0.0:
			_state = "wander"
			_move_dir = Vector2.from_angle(randf() * TAU)
			_state_timer = randf_range(2.0, 4.0)
		return 0.0
	# wander
	if _state_timer <= 0.0:
		if randf() < 0.42:
			_state = "pause"
			_state_timer = randf_range(1.2, 2.5)
		else:
			_move_dir = _move_dir.rotated(randf_range(-1.4, 1.4)).normalized()
			_state_timer = randf_range(1.8, 3.2)
	return 62.0

func _update_dog(_delta: float, dist: float, to_mower: Vector2) -> float:
	if _state == "flee":
		if _state_timer <= 0.0:
			_state = "wander"
			_state_timer = randf_range(1.5, 2.6)
		return 175.0
	# Playful dog spots mower within 205px and chases!
	if _hit_cooldown <= 0.0 and dist < 205.0:
		if _state != "chase":
			_state = "chase"
			_alert_timer = 0.75
		_move_dir = _move_dir.lerp(to_mower.normalized(), 0.12).normalized()
		return 152.0
	if _state == "chase" and dist >= 245.0:
		_state = "wander"
		_state_timer = randf_range(1.6, 2.8)
	if _state_timer <= 0.0:
		_move_dir = Vector2.from_angle(randf() * TAU)
		_state_timer = randf_range(1.4, 2.8)
	return 95.0

func _update_pig(delta: float, _dist: float, _to_mower: Vector2) -> float:
	_mud_timer -= delta
	if _mud_timer <= 0.0:
		_mud_timer = randf_range(2.8, 4.4)
		spawned_mud.emit(global_position)
	if _state == "flee":
		if _state_timer <= 0.0:
			_state = "wander"
			_state_timer = randf_range(2.0, 3.2)
		return 150.0
	if _state_timer <= 0.0:
		_move_dir = _move_dir.rotated(randf_range(-1.6, 1.6)).normalized()
		_state_timer = randf_range(1.6, 3.2)
	return 80.0

func get_minimap_color() -> Color:
	match animal_type:
		AnimalType.SHEEP:
			return Color(0.98, 0.98, 0.96)
		AnimalType.DOG:
			return Color(1.0, 0.56, 0.18)
		AnimalType.PIG:
			return Color(1.0, 0.56, 0.72)
	return Color.WHITE

func _draw() -> void:
	var hop := absf(sin(_walk_cycle)) * 3.2 if velocity.length() > 8.0 else 0.0
	# Shadow
	draw_circle(Vector2(2.0, 6.0), _body_radius * 0.92, Color(0.05, 0.12, 0.05, 0.30))

	draw_set_transform(Vector2(0.0, -hop), _facing, Vector2.ONE)
	match animal_type:
		AnimalType.SHEEP:
			_draw_sheep()
		AnimalType.DOG:
			_draw_dog()
		AnimalType.PIG:
			_draw_pig()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Alert exclamation mark when dog starts chasing!
	if _alert_timer > 0.0:
		var badge_pos := Vector2(0.0, -30.0 - hop)
		draw_circle(badge_pos, 9.5, Color(1.0, 0.30, 0.22))
		draw_line(badge_pos + Vector2(0, -5), badge_pos + Vector2(0, 1), Color.WHITE, 2.6, true)
		draw_circle(badge_pos + Vector2(0, 4.5), 1.6, Color.WHITE)

func _draw_sheep() -> void:
	# Fluffy white wool puffs
	var wool_col := Color(0.97, 0.96, 0.93)
	var shade_col := Color(0.84, 0.83, 0.80)
	draw_circle(Vector2(-10, 0), 10.5, shade_col)
	draw_circle(Vector2(-5, -9), 9.5, wool_col)
	draw_circle(Vector2(-5, 9), 9.5, wool_col)
	draw_circle(Vector2(4, -8), 9.0, wool_col)
	draw_circle(Vector2(4, 8), 9.0, wool_col)
	draw_circle(Vector2(-2, 0), 13.0, wool_col)
	# Dark face & ears pointing right (+X)
	draw_circle(Vector2(14, 0), 7.5, Color(0.22, 0.20, 0.22))
	draw_circle(Vector2(11, -7.5), 3.6, Color(0.22, 0.20, 0.22))
	draw_circle(Vector2(11, 7.5), 3.6, Color(0.22, 0.20, 0.22))
	# Cute wool tuft on head
	draw_circle(Vector2(10, 0), 4.5, wool_col)
	# Eyes
	draw_circle(Vector2(16.5, -2.8), 1.7, Color.WHITE)
	draw_circle(Vector2(16.5, 2.8), 1.7, Color.WHITE)
	draw_circle(Vector2(17.2, -2.8), 0.9, Color.BLACK)
	draw_circle(Vector2(17.2, 2.8), 0.9, Color.BLACK)

func _draw_dog() -> void:
	var fur := Color(0.92, 0.56, 0.20)
	var cream := Color(0.98, 0.90, 0.74)
	var wag := sin(Time.get_ticks_msec() * 0.022) * 5.0
	# Wagging tail
	draw_line(Vector2(-12, 0), Vector2(-21, wag), fur, 4.2, true)
	# Body
	draw_circle(Vector2(-4, 0), 11.0, fur)
	draw_circle(Vector2(3, 0), 10.0, fur)
	draw_circle(Vector2(2, 0), 6.5, cream)
	# Collar
	draw_line(Vector2(7, -8), Vector2(7, 8), Color(0.92, 0.20, 0.24), 3.2, true)
	# Head
	draw_circle(Vector2(12, 0), 8.5, fur)
	draw_circle(Vector2(15, 0), 5.2, cream)
	# Pointy Shiba ears
	draw_colored_polygon(PackedVector2Array([Vector2(7, -6), Vector2(12, -13), Vector2(14, -6)]), fur.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(7, 6), Vector2(12, 13), Vector2(14, 6)]), fur.darkened(0.1))
	# Nose & eyes
	draw_circle(Vector2(20, 0), 2.3, Color(0.14, 0.10, 0.10))
	draw_circle(Vector2(14.5, -3.5), 1.6, Color(0.12, 0.10, 0.10))
	draw_circle(Vector2(14.5, 3.5), 1.6, Color(0.12, 0.10, 0.10))

func _draw_pig() -> void:
	var pink := Color(0.98, 0.64, 0.74)
	var snout := Color(0.94, 0.48, 0.62)
	var mud := Color(0.42, 0.28, 0.16, 0.85)
	# Curly tail
	draw_arc(Vector2(-16, 0), 3.5, 0.0, TAU * 0.85, 10, snout, 2.2, true)
	# Plump body
	draw_circle(Vector2(-3, 0), 13.0, pink)
	draw_circle(Vector2(5, 0), 10.5, pink)
	# Mud spots on its back!
	draw_circle(Vector2(-6, -4), 4.5, mud)
	draw_circle(Vector2(-1, 5), 3.8, mud)
	draw_circle(Vector2(-10, 3), 2.8, mud)
	# Ears
	draw_circle(Vector2(8, -9.5), 4.5, snout)
	draw_circle(Vector2(8, 9.5), 4.5, snout)
	# Snout
	draw_circle(Vector2(16, 0), 5.2, snout)
	draw_circle(Vector2(17.5, -1.8), 1.1, Color(0.35, 0.15, 0.20))
	draw_circle(Vector2(17.5, 1.8), 1.1, Color(0.35, 0.15, 0.20))
	# Eyes
	draw_circle(Vector2(11.5, -4.0), 1.6, Color(0.14, 0.10, 0.12))
	draw_circle(Vector2(11.5, 4.0), 1.6, Color(0.14, 0.10, 0.12))
