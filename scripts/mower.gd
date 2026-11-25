extends CharacterBody2D
class_name Lawnmower

signal hit_rock(pos: Vector2)
signal boost_started()

@export var max_speed: float = 250.0
@export var boost_speed: float = 385.0
@export var cut_radius: float = 34.0
@export var boost_cut_radius: float = 42.0

var control_enabled: bool = false
var play_bounds: Rect2 = Rect2(0, 0, 1024, 1536)

var joystick_input: Vector2 = Vector2.ZERO
var touch_boost_pressed: bool = false

# Boost gauge (0..1)
var boost_energy: float = 1.0
var is_boosting: bool = false
var _boost_exhausted: bool = false

# Status effects from rocks & animals
var rock_stun_timer: float = 0.0
var dizzy_timer: float = 0.0
var mud_slip_timer: float = 0.0
var animal_grace_timer: float = 0.0
var fever_active: bool = false

var facing_angle: float = -PI * 0.5
var _blade_angle: float = 0.0
var _engine_jiggle: float = 0.0
var _rock_hit_cooldown: float = 0.0
var _knockback_vel: Vector2 = Vector2.ZERO

# Lightweight procedural particles (grass clippings, sparks, mud drops, sparkles)
var _particles: Array[Dictionary] = []

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2 # Rocks & Trees
	z_index = 25

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	col.shape = shape
	add_child(col)

func reset_state(start_pos: Vector2, bounds: Rect2) -> void:
	position = start_pos
	play_bounds = bounds.grow(-24.0)
	velocity = Vector2.ZERO
	_knockback_vel = Vector2.ZERO
	facing_angle = -PI * 0.5
	boost_energy = 1.0
	is_boosting = false
	_boost_exhausted = false
	rock_stun_timer = 0.0
	dizzy_timer = 0.0
	mud_slip_timer = 0.0
	animal_grace_timer = 0.0
	fever_active = false
	_rock_hit_cooldown = 0.0
	_particles.clear()
	queue_redraw()

func get_active_cut_radius() -> float:
	if rock_stun_timer > 0.0:
		return cut_radius * 0.65
	if is_boosting:
		return boost_cut_radius
	return cut_radius

func apply_sheep_bump(push_dir: Vector2) -> bool:
	if animal_grace_timer > 0.0:
		return false
	_knockback_vel = push_dir.normalized() * 440.0
	animal_grace_timer = 1.6
	spawn_burst(global_position, 10, Color(0.98, 0.98, 0.94), 140.0)
	return true

func apply_dog_dizzy(push_dir: Vector2) -> bool:
	if animal_grace_timer > 0.0:
		return false
	dizzy_timer = 1.85
	_knockback_vel = push_dir.normalized() * 210.0
	animal_grace_timer = 2.6
	spawn_burst(global_position, 12, Color(1.0, 0.85, 0.2), 130.0)
	return true

func apply_mud_slip() -> bool:
	if mud_slip_timer > 0.35:
		return false
	mud_slip_timer = 1.75
	spawn_burst(global_position, 10, Color(0.45, 0.30, 0.16), 120.0)
	return true

func spawn_cut_particles(is_special: bool, count: int) -> void:
	var n := mini(count, 7)
	var chute_dir := Vector2.from_angle(facing_angle + PI * 0.58)
	var origin := global_position + chute_dir * 16.0
	for _i in range(n):
		var col := Color(0.28, 0.72, 0.24)
		if is_special:
			col = Color(1.0, 0.86, 0.18) if randf() < 0.6 else Color(1.0, 0.42, 0.74)
		elif fever_active:
			col = Color(0.68, 0.92, 0.26)
		var v := chute_dir.rotated(randf_range(-0.55, 0.55)) * randf_range(75.0, 175.0)
		_particles.append({
			"pos": origin + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"vel": v,
			"col": col,
			"size": randf_range(3.0, 5.8) if is_special else randf_range(2.6, 4.5),
			"life": randf_range(0.26, 0.48),
			"max_life": 0.48,
		})

func spawn_burst(world_pos: Vector2, count: int, col: Color, spd: float = 150.0) -> void:
	for _i in range(count):
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(spd * 0.35, spd)
		_particles.append({
			"pos": world_pos,
			"vel": v,
			"col": col.lightened(randf_range(-0.1, 0.2)),
			"size": randf_range(3.2, 6.2),
			"life": randf_range(0.32, 0.58),
			"max_life": 0.58,
		})

func get_status_label() -> String:
	if rock_stun_timer > 0.0:
		return "rock"
	if dizzy_timer > 0.0:
		return "dizzy"
	if mud_slip_timer > 0.0:
		return "mud"
	return ""

func _physics_process(delta: float) -> void:
	_rock_hit_cooldown = maxf(0.0, _rock_hit_cooldown - delta)
	rock_stun_timer = maxf(0.0, rock_stun_timer - delta)
	dizzy_timer = maxf(0.0, dizzy_timer - delta)
	mud_slip_timer = maxf(0.0, mud_slip_timer - delta)
	animal_grace_timer = maxf(0.0, animal_grace_timer - delta)

	_update_particles(delta)

	if not control_enabled:
		velocity = velocity.lerp(Vector2.ZERO, minf(delta * 8.0, 1.0))
		_blade_angle += delta * 6.0
		queue_redraw()
		return

	# Combine mobile joystick + keyboard input seamlessly
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var raw_input := joystick_input if joystick_input.length() > 0.05 else kb
	if raw_input.length() > 1.0:
		raw_input = raw_input.normalized()

	# Dizzy steering interference from playful Dog!
	var steer_input := raw_input
	if dizzy_timer > 0.0 and steer_input.length() > 0.05:
		var wobble := PI * 0.72 + sin(Time.get_ticks_msec() * 0.015) * 0.55
		steer_input = steer_input.rotated(wobble)

	# Boost energy management
	var wants_boost := (touch_boost_pressed or Input.is_action_pressed("boost")) and steer_input.length() > 0.15 and rock_stun_timer <= 0.0
	if _boost_exhausted and boost_energy >= 0.28:
		_boost_exhausted = false
	var was_boosting := is_boosting
	if wants_boost and not _boost_exhausted and boost_energy > 0.02:
		is_boosting = true
		boost_energy = maxf(0.0, boost_energy - delta * 0.44)
		if boost_energy <= 0.02:
			_boost_exhausted = true
			is_boosting = false
	else:
		is_boosting = false
		boost_energy = minf(1.0, boost_energy + delta * 0.24)

	if is_boosting and not was_boosting:
		boost_started.emit()

	# Speed & traction calculation
	var target_max := boost_speed if is_boosting else max_speed
	if fever_active:
		target_max *= 1.12
	if rock_stun_timer > 0.0:
		target_max *= 0.42
	elif mud_slip_timer > 0.0:
		target_max *= 0.78

	var target_vel := steer_input * target_max
	# Mud makes mower drift/slide with low grip!
	var accel_rate := 2.4 if mud_slip_timer > 0.0 else (11.5 if steer_input.length() > 0.05 else 9.0)
	velocity = velocity.lerp(target_vel, minf(delta * accel_rate, 1.0))

	# Blend knockback impulse
	if _knockback_vel.length() > 5.0:
		velocity += _knockback_vel * delta * 8.5
		_knockback_vel = _knockback_vel.lerp(Vector2.ZERO, minf(delta * 9.5, 1.0))
	else:
		_knockback_vel = Vector2.ZERO

	# Smooth mower heading
	if steer_input.length() > 0.08:
		var turn_speed := 6.0 if mud_slip_timer > 0.0 else 13.5
		facing_angle = lerp_angle(facing_angle, steer_input.angle(), minf(delta * turn_speed, 1.0))
	elif velocity.length() > 25.0:
		facing_angle = lerp_angle(facing_angle, velocity.angle(), minf(delta * 6.0, 1.0))

	move_and_slide()

	# Clamp neatly inside wooden fence
	position.x = clampf(position.x, play_bounds.position.x, play_bounds.end.x)
	position.y = clampf(position.y, play_bounds.position.y, play_bounds.end.y)

	# Rock collision bounce & blade stun
	if _rock_hit_cooldown <= 0.0:
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i)
			var collider := col.get_collider()
			if collider != null and collider.is_in_group("rocks"):
				if velocity.length() > 75.0 or steer_input.length() > 0.25:
					_rock_hit_cooldown = 0.65
					rock_stun_timer = 0.42
					var n := col.get_normal()
					_knockback_vel = n * 290.0
					spawn_burst(col.get_position(), 11, Color(1.0, 0.85, 0.35), 165.0)
					hit_rock.emit(col.get_position())
					break

	# Visual animations
	var blade_spd := 28.0 if is_boosting else (18.0 if rock_stun_timer <= 0.0 else 4.0)
	_blade_angle += delta * blade_spd
	_engine_jiggle += delta * (34.0 if is_boosting else 24.0)

	# Boost flame or fever sparkles
	if is_boosting and randf() < 0.65:
		var back := global_position - Vector2.from_angle(facing_angle) * 24.0
		_particles.append({
			"pos": back + Vector2(randf_range(-5, 5), randf_range(-5, 5)),
			"vel": -Vector2.from_angle(facing_angle) * randf_range(60.0, 120.0),
			"col": Color(1.0, 0.68, 0.16) if randf() < 0.6 else Color(1.0, 0.94, 0.55),
			"size": randf_range(3.5, 6.0),
			"life": 0.25,
			"max_life": 0.25,
		})
	elif mud_slip_timer > 0.0 and velocity.length() > 35.0 and randf() < 0.45:
		var back := global_position - Vector2.from_angle(facing_angle) * 16.0
		_particles.append({
			"pos": back + Vector2(randf_range(-8, 8), randf_range(-8, 8)),
			"vel": -velocity.normalized() * randf_range(30.0, 70.0),
			"col": Color(0.42, 0.28, 0.14),
			"size": randf_range(3.0, 5.2),
			"life": 0.35,
			"max_life": 0.35,
		})

	queue_redraw()

func _update_particles(delta: float) -> void:
	var i := _particles.size() - 1
	while i >= 0:
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)
		else:
			p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
			p["vel"] = Vector2(p["vel"]) * maxf(0.0, 1.0 - delta * 4.5)
		i -= 1

func _draw() -> void:
	# World-space particles drawn relative to mower position
	for p in _particles:
		var local_p: Vector2 = Vector2(p["pos"]) - global_position
		var a := clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var c: Color = p["col"]
		c.a = a
		draw_circle(local_p, float(p["size"]) * (0.4 + 0.6 * a), c)

	# 2x Fever golden aura ring
	if fever_active:
		var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.012)
		var r := get_active_cut_radius() * pulse
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.85, 0.16, 0.16))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 0.90, 0.24, 0.78), 2.8, true)

	# Subtle mower blade cutting sweep circle under mower
	var cut_r := get_active_cut_radius()
	draw_arc(Vector2.ZERO, cut_r, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.20 if not is_boosting else 0.42), 1.8, true)

	# Ground shadow
	draw_circle(Vector2(3.0, 6.0), 22.0, Color(0.04, 0.10, 0.04, 0.34))

	# Mower body transform (points along +X)
	var vib := Vector2(sin(_engine_jiggle) * 0.7, cos(_engine_jiggle * 1.3) * 0.7) if control_enabled else Vector2.ZERO
	draw_set_transform(vib, facing_angle, Vector2.ONE)

	# Spinning metallic blades beneath deck
	var blade_col := Color(0.85, 0.92, 0.96, 0.55)
	var b1 := Vector2(cos(_blade_angle), sin(_blade_angle)) * (cut_r * 0.86)
	var b2 := Vector2(cos(_blade_angle + PI * 0.5), sin(_blade_angle + PI * 0.5)) * (cut_r * 0.86)
	draw_line(-b1, b1, blade_col, 3.2, true)
	draw_line(-b2, b2, blade_col, 2.2, true)

	# Grass catcher bag at back (-X)
	draw_rect(Rect2(-27.0, -11.5, 13.0, 23.0), Color(0.18, 0.20, 0.22))
	draw_rect(Rect2(-25.0, -9.5, 9.0, 19.0), Color(0.28, 0.32, 0.34))

	# 4 dark rubber wheels
	var wheel_col := Color(0.14, 0.14, 0.16)
	draw_rect(Rect2(-14.0, -21.0, 12.0, 6.0), wheel_col)
	draw_rect(Rect2(-14.0, 15.0, 12.0, 6.0), wheel_col)
	draw_rect(Rect2(7.0, -20.0, 11.0, 5.5), wheel_col)
	draw_rect(Rect2(7.0, 14.5, 11.0, 5.5), wheel_col)

	# Side grass discharge chute (+Y side)
	draw_rect(Rect2(-3.0, 13.0, 11.0, 7.0), Color(0.22, 0.24, 0.26))

	# Main vibrant red mower chassis (turns golden-orange during boost / stunned flash)
	var chassis_col := Color(0.92, 0.22, 0.18)
	if is_boosting:
		chassis_col = Color(1.0, 0.44, 0.12)
	elif rock_stun_timer > 0.0 and fmod(Time.get_ticks_msec() * 0.02, 1.0) > 0.5:
		chassis_col = Color(1.0, 0.72, 0.68)

	draw_rect(Rect2(-15.0, -16.0, 32.0, 32.0), chassis_col)
	# Rounded front bumper nose
	draw_circle(Vector2(15.0, 0.0), 15.5, chassis_col)
	# Gloss highlight stripe
	draw_rect(Rect2(-11.0, -12.0, 24.0, 6.0), chassis_col.lightened(0.25))

	# Engine motor cap on center
	draw_circle(Vector2(2.0, 0.0), 9.5, Color(0.20, 0.22, 0.25))
	draw_circle(Vector2(2.0, 0.0), 5.5, Color(0.75, 0.78, 0.82))
	draw_circle(Vector2(2.0, 0.0), 2.5, Color(0.95, 0.78, 0.18))

	# Front direction bumper / headlights
	draw_circle(Vector2(26.0, -7.0), 3.0, Color(1.0, 0.96, 0.72))
	draw_circle(Vector2(26.0, 7.0), 3.0, Color(1.0, 0.96, 0.72))

	# Push handlebar extending behind
	draw_line(Vector2(-14.0, -12.0), Vector2(-31.0, -14.0), Color(0.84, 0.86, 0.90), 3.2, true)
	draw_line(Vector2(-14.0, 12.0), Vector2(-31.0, 14.0), Color(0.84, 0.86, 0.90), 3.2, true)
	draw_line(Vector2(-31.0, -14.5), Vector2(-31.0, 14.5), Color(0.16, 0.16, 0.18), 4.6, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Dizzy stars orbiting overhead when dog interferes!
	if dizzy_timer > 0.0:
		var t := Time.get_ticks_msec() * 0.008
		for i in range(3):
			var a := t + float(i) * (TAU / 3.0)
			var sp := Vector2(cos(a) * 20.0, -32.0 + sin(a) * 7.0)
			draw_circle(sp, 4.6, Color(1.0, 0.90, 0.18))
			draw_circle(sp, 2.2, Color.WHITE)

	# Mud splash ring when slipping!
	if mud_slip_timer > 0.0:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color(0.45, 0.29, 0.15, 0.75), 3.5, true)
