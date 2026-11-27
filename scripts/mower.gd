extends CharacterBody2D
class_name Lawnmower

signal hit_rock(pos: Vector2)
signal rock_shattered(rock: Node2D)
signal boost_started()

@export var max_speed: float = 250.0
@export var boost_speed: float = 385.0
@export var cut_radius: float = 34.0
@export var boost_cut_radius: float = 50.0

var mower_id: String = "classic"
var turn_mult: float = 1.0
var debuff_mult: float = 1.0
var immune_mud: bool = false
var immune_dizzy: bool = false
var immune_rock: bool = false

# Exclusive Mower Skills
var has_shield: bool = false
var shield_dur: float = 4.0
var shield_cd: float = 10.0
var shield_timer: float = 0.0
var _shield_cd_timer: float = 0.0

var has_smash: bool = false
var smash_max_rock_rad: float = 0.0
var smash_animals: bool = false

var has_whirlwind: bool = false
var whirlwind_dur: float = 3.5
var whirlwind_cd: float = 10.0
var whirlwind_timer: float = 0.0
var _whirlwind_cd_timer: float = 0.0

var control_enabled: bool = false
var play_bounds: Rect2 = Rect2(0, 0, 1024, 1536)

var joystick_input: Vector2 = Vector2.ZERO

# Power-up turbo boost timer (activated by picking up BoostPickup on the lawn)
var boost_timer: float = 0.0
var is_boosting: bool = false

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

# Smooth world-space rainbow ribbon trail during Turbo Boost!
var _rainbow_trail: Array[Dictionary] = []
var _trail_sample_dist: float = 0.0
var _last_trail_pos: Vector2 = Vector2.ZERO
var _mower_textures: Dictionary = {}

const RAINBOW_BANDS := [
	Color(1.00, 0.24, 0.32), # Red
	Color(1.00, 0.58, 0.12), # Orange
	Color(1.00, 0.90, 0.18), # Yellow
	Color(0.30, 0.88, 0.38), # Green
	Color(0.20, 0.82, 1.00), # Cyan-Blue
	Color(0.68, 0.38, 1.00), # Violet
]

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2 # Rocks & Trees
	z_index = 25

	for m_id in ["classic", "volt", "crusher", "cyclone", "rainbow"]:
		var tex: Texture2D = load("res://assets/sprites/mower_%s.png" % m_id)
		if tex != null:
			_mower_textures[m_id] = tex

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	col.shape = shape
	add_child(col)

func apply_loadout(stats: Dictionary) -> void:
	mower_id = String(stats.get("mower_id", "classic"))
	cut_radius = float(stats.get("cut_radius", 34.0))
	boost_cut_radius = float(stats.get("boost_cut_radius", 50.0))
	max_speed = float(stats.get("max_speed", 250.0))
	boost_speed = float(stats.get("boost_speed", 385.0))
	turn_mult = float(stats.get("turn_mult", 1.0))
	debuff_mult = float(stats.get("debuff_mult", 1.0))
	immune_mud = bool(stats.get("immune_mud", false))
	immune_dizzy = bool(stats.get("immune_dizzy", false))
	immune_rock = bool(stats.get("immune_rock", false))

	has_shield = bool(stats.get("has_shield", false))
	shield_dur = float(stats.get("shield_dur", 4.0))
	shield_cd = float(stats.get("shield_cd", 10.0))
	shield_timer = shield_dur if has_shield else 0.0
	_shield_cd_timer = 0.0

	has_smash = bool(stats.get("has_smash", false))
	smash_max_rock_rad = float(stats.get("smash_max_rock_rad", 0.0))
	smash_animals = bool(stats.get("smash_animals", false))

	has_whirlwind = bool(stats.get("has_whirlwind", false))
	whirlwind_dur = float(stats.get("whirlwind_dur", 3.5))
	whirlwind_cd = float(stats.get("whirlwind_cd", 10.0))
	whirlwind_timer = whirlwind_dur if has_whirlwind else 0.0
	_whirlwind_cd_timer = 0.0
	queue_redraw()

func is_shield_active() -> bool:
	return shield_timer > 0.0

func is_whirlwind_active() -> bool:
	return whirlwind_timer > 0.0

func reset_state(start_pos: Vector2, bounds: Rect2) -> void:
	position = start_pos
	play_bounds = bounds.grow(-24.0)
	velocity = Vector2.ZERO
	_knockback_vel = Vector2.ZERO
	facing_angle = -PI * 0.5
	boost_timer = 0.0
	is_boosting = false
	rock_stun_timer = 0.0
	dizzy_timer = 0.0
	mud_slip_timer = 0.0
	animal_grace_timer = 0.0
	fever_active = false
	_rock_hit_cooldown = 0.0
	if has_shield:
		shield_timer = shield_dur
		_shield_cd_timer = 0.0
	if has_whirlwind:
		whirlwind_timer = whirlwind_dur
		_whirlwind_cd_timer = 0.0
	_particles.clear()
	_rainbow_trail.clear()
	_last_trail_pos = start_pos
	queue_redraw()

func get_active_cut_radius() -> float:
	var base_r := boost_cut_radius if is_boosting else cut_radius
	if rock_stun_timer > 0.0 and not is_boosting:
		base_r *= 0.65
	if whirlwind_timer > 0.0:
		base_r = maxf(base_r, cut_radius * 1.65)
	return base_r

func activate_boost(duration: float = 5.0, max_stack: float = 10.0) -> void:
	boost_timer = minf(boost_timer + duration, maxf(max_stack, duration))
	is_boosting = true
	boost_started.emit()
	_last_trail_pos = global_position
	for i in range(RAINBOW_BANDS.size()):
		spawn_burst(global_position, 3, RAINBOW_BANDS[i], 190.0)

func apply_sheep_bump(push_dir: Vector2) -> bool:
	if animal_grace_timer > 0.0:
		return false
	if is_shield_active():
		spawn_burst(global_position, 8, Color(0.32, 0.86, 1.0), 150.0)
		animal_grace_timer = 0.8
		return false
	_knockback_vel = push_dir.normalized() * (440.0 * (0.45 + 0.55 * debuff_mult))
	animal_grace_timer = 1.6
	spawn_burst(global_position, 10, Color(0.98, 0.98, 0.94), 140.0)
	return true

func apply_dog_dizzy(push_dir: Vector2) -> bool:
	if animal_grace_timer > 0.0:
		return false
	if is_shield_active() or immune_dizzy:
		spawn_burst(global_position, 8, Color(0.32, 0.86, 1.0), 150.0)
		animal_grace_timer = 1.0
		return false
	dizzy_timer = maxf(0.35, 1.85 * debuff_mult)
	_knockback_vel = push_dir.normalized() * (210.0 * debuff_mult)
	animal_grace_timer = 2.6
	spawn_burst(global_position, 12, Color(1.0, 0.85, 0.2), 130.0)
	return true

func apply_mud_slip() -> bool:
	if mud_slip_timer > 0.35:
		return false
	if is_shield_active() or immune_mud:
		return false
	mud_slip_timer = maxf(0.30, 1.75 * debuff_mult)
	spawn_burst(global_position, 10, Color(0.45, 0.30, 0.16), 120.0)
	return true

func spawn_cut_particles(is_special: bool, count: int) -> void:
	if _particles.size() >= 40:
		return
	var n := mini(count, mini(5, 40 - _particles.size()))
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
	_update_rainbow_trail(delta)

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

	# Power-up turbo boost timer
	if boost_timer > 0.0:
		boost_timer = maxf(0.0, boost_timer - delta)
	is_boosting = boost_timer > 0.0

	# Mower-bound periodic Shield skill
	if has_shield:
		if shield_timer > 0.0:
			shield_timer = maxf(0.0, shield_timer - delta)
			if shield_timer <= 0.0:
				_shield_cd_timer = shield_cd
		else:
			_shield_cd_timer -= delta
			if _shield_cd_timer <= 0.0:
				shield_timer = shield_dur
				spawn_burst(global_position, 10, Color(0.32, 0.88, 1.0), 145.0)

	# Mower-bound periodic Whirlwind Blade Aura skill
	if has_whirlwind:
		if whirlwind_timer > 0.0:
			whirlwind_timer = maxf(0.0, whirlwind_timer - delta)
			if whirlwind_timer <= 0.0:
				_whirlwind_cd_timer = whirlwind_cd
		else:
			_whirlwind_cd_timer -= delta
			if _whirlwind_cd_timer <= 0.0:
				whirlwind_timer = whirlwind_dur
				spawn_burst(global_position, 12, Color(1.0, 0.90, 0.28), 165.0)

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
		var turn_speed := (6.0 if mud_slip_timer > 0.0 else 13.5) * turn_mult
		facing_angle = lerp_angle(facing_angle, steer_input.angle(), minf(delta * turn_speed, 1.0))
	elif velocity.length() > 25.0:
		facing_angle = lerp_angle(facing_angle, velocity.angle(), minf(delta * 6.0 * turn_mult, 1.0))

	move_and_slide()

	# Clamp neatly inside wooden fence
	position.x = clampf(position.x, play_bounds.position.x, play_bounds.end.x)
	position.y = clampf(position.y, play_bounds.position.y, play_bounds.end.y)

	# Rock collision: shatter if Crusher/Rainbow smash meets rock size, else resist or bounce
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider != null and collider.is_in_group("rocks"):
			if has_smash and collider is LawnObstacle:
				var rock_obs := collider as LawnObstacle
				if not rock_obs.is_shattered and rock_obs.radius <= smash_max_rock_rad:
					spawn_burst(rock_obs.global_position, 14, Color(0.68, 0.70, 0.72), 200.0)
					spawn_burst(rock_obs.global_position, 8, Color(1.0, 0.86, 0.22), 165.0)
					rock_shattered.emit(rock_obs)
					break
			if _rock_hit_cooldown <= 0.0 and (velocity.length() > 75.0 or steer_input.length() > 0.25):
				if is_shield_active() or immune_rock:
					_rock_hit_cooldown = 0.45
					spawn_burst(col.get_position(), 6, Color(0.36, 0.88, 1.0), 120.0)
					break
				_rock_hit_cooldown = 0.65
				rock_stun_timer = maxf(0.10, 0.42 * debuff_mult)
				var n := col.get_normal()
				_knockback_vel = n * (290.0 * debuff_mult)
				spawn_burst(col.get_position(), 11, Color(1.0, 0.85, 0.35), 165.0)
				hit_rock.emit(col.get_position())
				break

	# Visual animations
	var blade_spd := 28.0 if is_boosting else (18.0 if rock_stun_timer <= 0.0 else 4.0)
	_blade_angle += delta * blade_spd
	_engine_jiggle += delta * (34.0 if is_boosting else 24.0)

	# Rainbow sparkle confetti trailing behind mower during boost!
	if is_boosting:
		var back_dir := -Vector2.from_angle(facing_angle)
		var side_dir := Vector2(-back_dir.y, back_dir.x)
		var tail_pos := global_position + back_dir * 20.0
		if _rainbow_trail.is_empty() or tail_pos.distance_to(_last_trail_pos) >= 12.0:
			_rainbow_trail.append({
				"pos": tail_pos,
				"side": side_dir,
				"age": 0.0,
				"max_age": 0.58,
			})
			_last_trail_pos = tail_pos
			if _rainbow_trail.size() > 28:
				_rainbow_trail.pop_front()
		if velocity.length() > 30.0 and _particles.size() < 40 and randf() < 0.55:
			var band_col: Color = RAINBOW_BANDS[randi() % RAINBOW_BANDS.size()]
			var lateral := randf_range(-26.0, 26.0)
			_particles.append({
				"pos": tail_pos + side_dir * lateral,
				"vel": back_dir * randf_range(45.0, 115.0) + side_dir * randf_range(-28.0, 28.0),
				"col": band_col.lightened(0.2),
				"size": randf_range(3.2, 5.8),
				"life": randf_range(0.28, 0.48),
				"max_life": 0.48,
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

func _update_rainbow_trail(delta: float) -> void:
	var i := _rainbow_trail.size() - 1
	while i >= 0:
		var pt: Dictionary = _rainbow_trail[i]
		pt["age"] = float(pt["age"]) + delta
		if float(pt["age"]) >= float(pt["max_age"]):
			_rainbow_trail.remove_at(i)
		i -= 1

func _draw_rainbow_trail() -> void:
	if _rainbow_trail.size() < 2:
		return
	var num_bands := RAINBOW_BANDS.size()
	var total_half_w := 27.0
	var band_w := (total_half_w * 2.0) / float(num_bands)

	for i in range(_rainbow_trail.size() - 1):
		var a: Dictionary = _rainbow_trail[i]
		var b: Dictionary = _rainbow_trail[i + 1]
		var p0: Vector2 = Vector2(a["pos"]) - global_position
		var p1: Vector2 = Vector2(b["pos"]) - global_position
		var seg_len := p0.distance_to(p1)
		if seg_len < 0.5 or seg_len > 90.0:
			continue
		var s0: Vector2 = a["side"]
		var s1: Vector2 = b["side"]
		var life0 := clampf(1.0 - float(a["age"]) / float(a["max_age"]), 0.0, 1.0)
		var life1 := clampf(1.0 - float(b["age"]) / float(b["max_age"]), 0.0, 1.0)
		var taper0 := 0.35 + 0.65 * life0
		var taper1 := 0.35 + 0.65 * life1
		var alpha := minf(life0, life1) * 0.88
		if alpha <= 0.02:
			continue

		var draw_w := band_w * ((taper0 + taper1) * 0.5) + 1.6
		for k in range(num_bands):
			var center_off := -total_half_w + (float(k) + 0.5) * band_w
			var q0 := p0 + s0 * (center_off * taper0)
			var q1 := p1 + s1 * (center_off * taper1)
			var c: Color = RAINBOW_BANDS[k]
			c.a = alpha
			draw_line(q0, q1, c, draw_w, false)

func _draw() -> void:
	# Rainbow ribbon trail behind mower (drawn beneath mower & particles)
	_draw_rainbow_trail()

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
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(1.0, 0.90, 0.24, 0.78), 2.8, false)

	# Subtle mower blade cutting sweep circle + multi-layered skill VFX!
	var cut_r := get_active_cut_radius()
	var t_now := Time.get_ticks_msec() * 0.001
	if whirlwind_timer > 0.0:
		var wt := t_now * 12.0
		draw_circle(Vector2.ZERO, cut_r, Color(1.0, 0.90, 0.22, 0.16))
		draw_circle(Vector2.ZERO, cut_r * 0.68, Color(1.0, 0.96, 0.55, 0.12))
		for wi in range(4):
			var wa := wt + float(wi) * (PI * 0.5)
			draw_arc(Vector2.ZERO, cut_r, wa, wa + 1.05, 10, Color(1.0, 0.92, 0.26, 0.92), 5.0, false)
			draw_arc(Vector2.ZERO, cut_r * 0.84, wa + 0.25, wa + 1.10, 8, Color(1.0, 0.99, 0.78, 0.72), 2.8, false)
			draw_arc(Vector2.ZERO, cut_r * 0.62, -wa * 1.35, -wa * 1.35 + 0.95, 8, Color(0.55, 1.0, 0.68, 0.68), 3.0, false)
	if is_boosting:
		var t_ms := t_now * 4.2
		var bp := 1.0 + 0.05 * sin(t_ms * 3.5)
		draw_circle(Vector2.ZERO, cut_r * bp, Color(1.0, 0.96, 0.72, 0.14))
		var seg := TAU / float(RAINBOW_BANDS.size())
		for bi in range(RAINBOW_BANDS.size()):
			var a0 := t_ms + float(bi) * seg
			draw_arc(Vector2.ZERO, cut_r * bp, a0, a0 + seg * 0.92, 6, Color(RAINBOW_BANDS[bi].r, RAINBOW_BANDS[bi].g, RAINBOW_BANDS[bi].b, 0.90), 3.8, false)
	elif whirlwind_timer <= 0.0:
		draw_arc(Vector2.ZERO, cut_r, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.24), 2.0, false)

	# Ground shadow beneath mower
	draw_circle(Vector2(3.0, 7.0), 26.0, Color(0.04, 0.10, 0.04, 0.34))

	# Mower body transform (facing_angle = 0 points +X; sprites face UP so rotate by +PI/2)
	var vib := Vector2(sin(_engine_jiggle) * 0.65, cos(_engine_jiggle * 1.3) * 0.65) if control_enabled else Vector2.ZERO
	draw_set_transform(vib, facing_angle, Vector2.ONE)

	# Spinning metallic blades peeking out beneath deck
	var blade_col := Color(1.0, 0.94, 0.40, 0.80) if whirlwind_timer > 0.0 else Color(0.88, 0.95, 0.98, 0.55)
	var b1 := Vector2(cos(_blade_angle), sin(_blade_angle)) * (cut_r * 0.86)
	var b2 := Vector2(cos(_blade_angle + PI * 0.5), sin(_blade_angle + PI * 0.5)) * (cut_r * 0.86)
	draw_line(-b1, b1, blade_col, 3.4, false)
	draw_line(-b2, b2, blade_col, 2.4, false)

	# Fiery crusher ram sparks on front bumper when Smash skill is active
	if has_smash and velocity.length() > 80.0:
		var glow_a := 0.45 + 0.30 * sin(t_now * 16.0)
		draw_arc(Vector2(22.0, 0.0), 18.0, -0.95, 0.95, 10, Color(1.0, 0.58, 0.12, glow_a), 4.0, false)

	# Draw glossy studio-quality 3D-cartoon illustrated mower sprite!
	var sprite_tex: Texture2D = _mower_textures.get(mower_id, null)
	if sprite_tex != null:
		var sprite_sz := clampf(58.0 + (cut_radius - 34.0) * 0.42, 58.0, 76.0)
		var tint := Color.WHITE
		if rock_stun_timer > 0.0 and fmod(t_now * 20.0, 1.0) > 0.5:
			tint = Color(1.0, 0.72, 0.68)
		elif is_boosting:
			tint = Color(1.05, 1.02, 0.96)
		draw_set_transform(vib, facing_angle + PI * 0.5, Vector2.ONE)
		draw_texture_rect(sprite_tex, Rect2(-sprite_sz * 0.5, -sprite_sz * 0.5, sprite_sz, sprite_sz), false, tint)
	else:
		draw_rect(Rect2(-15.0, -16.0, 32.0, 32.0), Color(0.92, 0.22, 0.18))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Active Hexagonal Energy Shield Bubble (Volt mower skill!)
	if shield_timer > 0.0:
		var sp := 1.0 + 0.04 * sin(t_now * 10.0)
		var sr := 37.0 * sp
		draw_circle(Vector2.ZERO, sr, Color(0.18, 0.80, 1.0, 0.20))
		var hex := PackedVector2Array()
		for hi in range(7):
			var ha := t_now * 1.4 + float(hi) * (TAU / 6.0)
			hex.append(Vector2(cos(ha), sin(ha)) * sr)
		draw_polyline(hex, Color(0.55, 0.96, 1.0, 0.92), 3.2, false)
		draw_arc(Vector2.ZERO, sr * 0.82, -t_now * 2.6, -t_now * 2.6 + 2.4, 12, Color(0.88, 1.0, 1.0, 0.75), 2.4, false)

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
