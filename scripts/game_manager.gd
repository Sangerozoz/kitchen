extends Node2D
class_name GameManager

const MATCH_DURATION := 60.0
const REVIVE_BONUS_TIME := 20.0
const REVIVE_BOOST_DURATION := 4.0
const FEVER_DURATION := 6.5
const BOOST_DURATION := 5.5
const MAX_ACTIVE_FLOWERS := 4
const MAX_ACTIVE_BOOSTS := 2
const MAX_TOTAL_BOOSTS_PER_ROUND := 6
const SAVE_PATH := "user://lawn_high_score.cfg"

enum GameState { TITLE, PLAYING, GAME_OVER }

var state: GameState = GameState.TITLE
var time_left: float = MATCH_DURATION
var score: int = 0
var best_score: int = 0
var fever_timer: float = 0.0
var special_cells_cut: int = 0
var flowers_harvested: int = 0

var _last_whole_sec: int = 60
var _special_patch_timer: float = 4.5
var _flower_spawn_timer: float = 5.0
var _boost_spawn_timer: float = 10.5
var _boosts_spawned_total: int = 0
var _shake_intensity: float = 0.0
var _special_popup_accum: int = 0
var _special_popup_timer: float = 0.0
var _minimap_refresh_accum: float = 0.0
var _has_revived_this_round: bool = false

var _lawn: LawnField
var _mower: Lawnmower
var _camera: Camera2D
var _sfx: SfxManager
var _ad_manager: AdManager
var _hud: GameHUD

var _world_objects: Node2D
var _obstacles: Array[LawnObstacle] = []
var _animals: Array[LawnAnimal] = []
var _flowers: Array[SpecialFlower] = []
var _boost_pickups: Array[BoostPickup] = []
var _mud_puddles: Array[MudPuddle] = []

func _ready() -> void:
	# Stop editor-only MCP autoload file polling in exported Web builds (avoids 60Hz VFS overhead on Android!)
	if OS.has_feature("web"):
		for mcp_name in ["MCPGameInspector", "MCPGameInput"]:
			var mcp_node := get_node_or_null("/root/" + mcp_name)
			if mcp_node != null:
				mcp_node.set_process(false)
				mcp_node.set_physics_process(false)
				mcp_node.set_process_input(false)
	randomize()
	_load_high_score()
	_build_scene_nodes()
	_setup_round(false)
	_hud.show_title(best_score)

func _build_scene_nodes() -> void:
	_sfx = SfxManager.new()
	add_child(_sfx)

	_ad_manager = AdManager.new()
	_ad_manager.ad_started.connect(_on_ad_started)
	_ad_manager.ad_finished.connect(_on_ad_finished)
	add_child(_ad_manager)

	_lawn = LawnField.new()
	add_child(_lawn)

	_world_objects = Node2D.new()
	add_child(_world_objects)

	_mower = Lawnmower.new()
	_mower.hit_rock.connect(_on_mower_hit_rock)
	_mower.boost_started.connect(func() -> void: _sfx.play_boost())
	add_child(_mower)

	_camera = Camera2D.new()
	_camera.enabled = true
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.5
	_camera.zoom = Vector2(0.95, 0.95)
	var rect := _lawn.get_play_rect()
	_camera.limit_left = int(rect.position.x - 56.0)
	_camera.limit_top = int(rect.position.y - 108.0)
	_camera.limit_right = int(rect.end.x + 56.0)
	_camera.limit_bottom = int(rect.end.y + 100.0)
	add_child(_camera)

	_hud = GameHUD.new()
	_hud.start_requested.connect(_start_game)
	_hud.start_ad_requested.connect(_on_start_ad_requested)
	_hud.revive_ad_requested.connect(_on_revive_ad_requested)
	_hud.restart_requested.connect(_start_game)
	_hud.home_requested.connect(_return_to_title)
	_hud.mute_toggled.connect(_on_mute_toggled)
	_hud.star_landed.connect(func(idx: int) -> void: _sfx.play_star(idx))
	add_child(_hud)
	_hud.joystick.input_changed.connect(func(v: Vector2) -> void: _mower.joystick_input = v)

func _input(event: InputEvent) -> void:
	# Wake Web Audio & BGM on the very first user gesture (iOS Safari / Chrome requirement)
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_sfx.start_bgm(state == GameState.PLAYING)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_sfx.start_bgm(state == GameState.PLAYING)
	elif event is InputEventKey and (event as InputEventKey).pressed:
		_sfx.start_bgm(state == GameState.PLAYING)

func _on_mute_toggled() -> void:
	var muted := _sfx.toggle_mute()
	_hud.set_muted_visual(muted)

func _return_to_title() -> void:
	_setup_round(false)
	state = GameState.TITLE
	_sfx.stop_engine()
	_sfx.set_bgm_ducked(true)
	_hud.show_title(best_score)

func _begin_play_from_home() -> void:
	if state != GameState.TITLE:
		return
	state = GameState.PLAYING
	_mower.control_enabled = true
	for a in _animals:
		if is_instance_valid(a):
			a.preview_mode = false
	for fl in _flowers:
		if is_instance_valid(fl):
			fl.lifetime_paused = false
	for bp in _boost_pickups:
		if is_instance_valid(bp):
			bp.lifetime_paused = false
	# Cut the small circle directly under the starting mower position
	_lawn.mow_circle(_mower.global_position, _mower.cut_radius * 0.9)
	_hud.show_playing(true)
	_sfx.start_bgm(true)
	_sfx.start_engine()

func _start_game() -> void:
	_setup_round(true)
	state = GameState.PLAYING
	_mower.control_enabled = true
	_hud.show_playing(false)
	_sfx.start_bgm(true)
	_sfx.start_engine()

func _start_game_with_ad_buff() -> void:
	_start_game()
	fever_timer = FEVER_DURATION
	_mower.activate_boost(BOOST_DURATION, BOOST_DURATION * 1.6)
	_sfx.play_flower()
	_update_hud_frame(true)
	_spawn_floating_text("开局冲刺 2×!", _mower.global_position + Vector2(0, -38), Color(1.0, 0.94, 0.28), 28, 1.35)
	_hud.show_toast("开局冲刺 + 双倍得分已激活！", true)

func _continue_round_with_revive() -> void:
	if state != GameState.GAME_OVER or _has_revived_this_round:
		return
	_has_revived_this_round = true
	time_left = REVIVE_BONUS_TIME
	_last_whole_sec = int(REVIVE_BONUS_TIME)
	state = GameState.PLAYING
	_mower.control_enabled = true
	_mower.activate_boost(REVIVE_BOOST_DURATION, BOOST_DURATION * 1.6)
	_hud.show_playing(true)
	_sfx.start_bgm(true)
	_sfx.start_engine()
	_update_hud_frame(true)
	_spawn_floating_text("+20秒 冲刺!", _mower.global_position + Vector2(0, -38), Color(1.0, 0.95, 0.30), 28, 1.35)
	_hud.show_toast("续时成功！+20秒 冲刺开启！", true)

func _on_start_ad_requested() -> void:
	if state != GameState.TITLE or _ad_manager == null or _ad_manager.is_busy():
		return
	_ad_manager.show_rewarded_video("start_buff")

func _on_revive_ad_requested() -> void:
	if state != GameState.GAME_OVER or _has_revived_this_round:
		return
	if _lawn.get_mowed_ratio() >= 0.995:
		return
	if _ad_manager == null or _ad_manager.is_busy():
		return
	_ad_manager.show_rewarded_video("revive_20s")

func _on_ad_started(_placement: String) -> void:
	_sfx.set_ad_paused(true)
	_hud.set_ad_buttons_loading(true)

func _on_ad_finished(placement: String, rewarded: bool, status: String, _error_msg: String) -> void:
	_sfx.set_ad_paused(false)
	_hud.set_ad_buttons_loading(false)
	if rewarded:
		if placement == "start_buff":
			_start_game_with_ad_buff()
		elif placement == "revive_20s":
			_continue_round_with_revive()
		return
	match status:
		"cancelled":
			_hud.show_toast("完整观看视频才能获得奖励哦", false)
		"unsupported":
			_hud.show_toast("请在 TapTap App 内观看视频领福利", false)
		"missing_unit_id":
			_hud.show_toast("广告位配置中，请稍后再试", false)
		_:
			_hud.show_toast("广告加载失败，请稍后再试", false)

func _setup_round(clear_start_grass: bool) -> void:
	# Clear dynamic entities from previous round
	for child in _world_objects.get_children():
		child.queue_free()
	_obstacles.clear()
	_animals.clear()
	_flowers.clear()
	_boost_pickups.clear()
	_mud_puddles.clear()

	_lawn.reset_field()

	var rect := _lawn.get_play_rect()
	var center := rect.get_center()
	_mower.reset_state(center, rect)
	_mower.control_enabled = false
	_camera.position = center

	time_left = MATCH_DURATION
	_last_whole_sec = int(MATCH_DURATION)
	score = 0
	fever_timer = 0.0
	special_cells_cut = 0
	flowers_harvested = 0
	_special_patch_timer = 4.2
	_flower_spawn_timer = 5.5
	_boost_spawn_timer = randf_range(10.0, 12.0)
	_boosts_spawned_total = 0
	_shake_intensity = 0.0
	_special_popup_accum = 0
	_special_popup_timer = 0.0
	_has_revived_this_round = false

	_generate_obstacles(rect, center)
	_generate_animals(rect, center, not clear_start_grass)
	_spawn_initial_specials(center, not clear_start_grass)

	if clear_start_grass:
		# Cut the small circle directly under the starting mower position
		_lawn.mow_circle(center, _mower.cut_radius * 0.9)

	_update_hud_frame()

func _generate_obstacles(rect: Rect2, safe_center: Vector2) -> void:
	var placed: Array[Dictionary] = []

	# 7 Trees with big leafy canopies (spread cleanly across the portrait yard)
	for _i in range(7):
		var rad := randf_range(22.0, 27.0)
		var pos := _pick_non_overlapping_pos(rect, 92.0, safe_center, 150.0, placed, rad + 95.0)
		if pos.x >= 0.0:
			var tree := LawnObstacle.new()
			tree.setup(LawnObstacle.Kind.TREE, pos, rad, _mower)
			_world_objects.add_child(tree)
			_obstacles.append(tree)
			_lawn.mark_obstacle_circle(pos, rad + 4.0)
			placed.append({"pos": pos, "rad": rad})

	# 10 Rocks of varying sizes
	for _i in range(10):
		var rad := randf_range(20.0, 31.0)
		var pos := _pick_non_overlapping_pos(rect, 76.0, safe_center, 130.0, placed, rad + 72.0)
		if pos.x >= 0.0:
			var rock := LawnObstacle.new()
			rock.setup(LawnObstacle.Kind.ROCK, pos, rad, _mower)
			_world_objects.add_child(rock)
			_obstacles.append(rock)
			_lawn.mark_obstacle_circle(pos, rad + 2.0)
			placed.append({"pos": pos, "rad": rad})

func _generate_animals(rect: Rect2, safe_center: Vector2, is_preview: bool = false) -> void:
	var types := [
		LawnAnimal.AnimalType.SHEEP,
		LawnAnimal.AnimalType.SHEEP,
		LawnAnimal.AnimalType.SHEEP,
		LawnAnimal.AnimalType.DOG,
		LawnAnimal.AnimalType.DOG,
		LawnAnimal.AnimalType.PIG,
		LawnAnimal.AnimalType.PIG,
	]
	var avoid: Array[Dictionary] = []
	for obs in _obstacles:
		avoid.append({"pos": obs.position, "rad": obs.radius})

	for t in types:
		var pos := _pick_non_overlapping_pos(rect, 88.0, safe_center, 195.0, avoid, 68.0)
		if pos.x < 0.0:
			pos = Vector2(randf_range(120, rect.size.x - 120), randf_range(120, rect.size.y - 120))
		var animal := LawnAnimal.new()
		animal.setup(t, pos, rect, _mower)
		animal.preview_mode = is_preview
		animal.interfered_with_mower.connect(_on_animal_interfered)
		animal.spawned_mud.connect(_on_pig_spawned_mud)
		_world_objects.add_child(animal)
		_animals.append(animal)
		avoid.append({"pos": pos, "rad": 42.0})

func _spawn_initial_specials(safe_center: Vector2, pause_lifetimes: bool = false) -> void:
	# Spawn 4 special colored grass patches & 2 lucky flowers right away so players see them immediately!
	var avoid := _collect_obstacle_positions()
	avoid.append(safe_center)
	for i in range(4):
		var spot := _lawn.find_unmowed_spot(84.0, avoid, 95.0)
		if spot.x >= 0.0:
			_lawn.spawn_special_patch(spot, randf_range(54.0, 74.0), i % 2 == 1)
			avoid.append(spot)

	for _j in range(2):
		var fl := _spawn_random_flower()
		if fl != null:
			fl.lifetime_paused = pause_lifetimes

	# Spawn 1 turbo boost pickup right at the start so the player can spot & grab it!
	var bp := _spawn_random_boost_pickup()
	if bp != null:
		bp.lifetime_paused = pause_lifetimes

func _pick_non_overlapping_pos(rect: Rect2, edge_pad: float, safe_center: Vector2, safe_rad: float, existing: Array[Dictionary], min_clearance: float) -> Vector2:
	for _attempt in range(60):
		var p := Vector2(
			randf_range(rect.position.x + edge_pad, rect.end.x - edge_pad),
			randf_range(rect.position.y + edge_pad, rect.end.y - edge_pad)
		)
		if p.distance_to(safe_center) < safe_rad:
			continue
		var ok := true
		for item in existing:
			if p.distance_to(item["pos"]) < float(item["rad"]) + min_clearance:
				ok = false
				break
		if ok:
			return p
	return Vector2(-1.0, -1.0)

func _collect_obstacle_positions() -> Array:
	var pts: Array = []
	for o in _obstacles:
		if is_instance_valid(o):
			pts.append(o.position)
	return pts

func _process(delta: float) -> void:
	# Smooth camera follow + look-ahead + shake
	var target_cam := _mower.global_position
	if state == GameState.PLAYING:
		target_cam += _mower.velocity * 0.18
	_camera.position = _camera.position.lerp(target_cam, minf(delta * 7.5, 1.0))

	if _shake_intensity > 0.1:
		_camera.offset = Vector2(randf_range(-_shake_intensity, _shake_intensity), randf_range(-_shake_intensity, _shake_intensity))
		_shake_intensity = lerpf(_shake_intensity, 0.0, minf(delta * 10.0, 1.0))
	else:
		_camera.offset = Vector2.ZERO

	if state == GameState.TITLE:
		_sfx.update_engine(0.0, false, false)
		return

	if state != GameState.PLAYING:
		_sfx.update_engine(0.0, false, false)
		return

	# Countdown timer
	time_left = maxf(0.0, time_left - delta)
	var whole := int(ceil(time_left))
	if whole != _last_whole_sec:
		_last_whole_sec = whole
		if whole > 0 and whole <= 10:
			_sfx.play_tick(whole <= 3)

	if time_left <= 0.0:
		_end_game()
		return

	# 2x Fever timer
	if fever_timer > 0.0:
		fever_timer = maxf(0.0, fever_timer - delta)
	_mower.fever_active = fever_timer > 0.0
	_lawn.set_fever_strength(clampf(fever_timer / 1.5, 0.0, 1.0))

	# Mow grass beneath the mower
	var cut_res := _lawn.mow_circle(_mower.global_position, _mower.get_active_cut_radius())
	var normal_cut: int = cut_res["normal"]
	var special_cut: int = cut_res["special"]
	var total_cut: int = cut_res["total"]

	if total_cut > 0:
		var fever_mult := 2 if fever_timer > 0.0 else 1
		# Normal grass = 2 pts/cell, Special colored grass = 4 pts/cell (2x reward!), Fever doubles both!
		var pts := normal_cut * 2 * fever_mult + special_cut * 4 * fever_mult
		score += pts
		special_cells_cut += special_cut
		_mower.spawn_cut_particles(special_cut > 0, total_cut)
		_sfx.play_cut(special_cut > 0)

		if special_cut > 0:
			_special_popup_accum += special_cut * 4 * fever_mult
			if _special_popup_timer <= 0.0:
				_special_popup_timer = 0.28

	if _special_popup_timer > 0.0:
		_special_popup_timer -= delta
		if _special_popup_timer <= 0.0 and _special_popup_accum > 0:
			var tag := "4× +%d" if fever_timer > 0.0 else "2× +%d"
			_spawn_floating_text(tag % _special_popup_accum, _mower.global_position + Vector2(0, -34), Color(1.0, 0.90, 0.22), 24)
			_special_popup_accum = 0

	# Check early 100% lawn completion!
	if _lawn.get_mowed_ratio() >= 0.995:
		var time_bonus := int(ceil(time_left)) * 50
		score += time_bonus
		_spawn_floating_text("100%%! +%d" % time_bonus, _mower.global_position, Color(1.0, 0.95, 0.3), 28)
		_end_game()
		return

	# Check flower harvesting
	for i in range(_flowers.size() - 1, -1, -1):
		var fl := _flowers[i]
		if not is_instance_valid(fl):
			_flowers.remove_at(i)
		elif fl.try_collect(_mower.global_position, _mower.get_active_cut_radius() * 0.72):
			_flowers.remove_at(i)

	# Check turbo boost pickup collection
	for i in range(_boost_pickups.size() - 1, -1, -1):
		var bp := _boost_pickups[i]
		if not is_instance_valid(bp):
			_boost_pickups.remove_at(i)
		elif bp.try_collect(_mower.global_position, _mower.get_active_cut_radius() * 0.72):
			_boost_pickups.remove_at(i)

	# Check mud puddles from Muddy Pig
	for i in range(_mud_puddles.size() - 1, -1, -1):
		var puddle := _mud_puddles[i]
		if not is_instance_valid(puddle):
			_mud_puddles.remove_at(i)
		elif puddle.contains_point(_mower.global_position, 8.0):
			if _mower.apply_mud_slip():
				_sfx.play_mud()
				_spawn_floating_text("打滑!", _mower.global_position + Vector2(0, -34), Color(0.95, 0.74, 0.48), 22)

	# Periodic random spawns of special colored grass & flowers!
	_special_patch_timer -= delta
	if _special_patch_timer <= 0.0:
		_special_patch_timer = randf_range(6.8, 9.2)
		if _lawn.count_unmowed_special_cells() < 220:
			_spawn_random_special_grass()

	_flower_spawn_timer -= delta
	if _flower_spawn_timer <= 0.0:
		_flower_spawn_timer = randf_range(5.8, 8.2)
		if _flowers.size() < MAX_ACTIVE_FLOWERS:
			_spawn_random_flower()

	_boost_spawn_timer -= delta
	if _boost_spawn_timer <= 0.0:
		_boost_spawn_timer = randf_range(10.5, 13.5)
		if _boost_pickups.size() < MAX_ACTIVE_BOOSTS and _boosts_spawned_total < MAX_TOTAL_BOOSTS_PER_ROUND:
			_spawn_random_boost_pickup()

	if _mower.velocity.length() > 35.0 or (MATCH_DURATION - time_left) > 4.5:
		_hud.hide_touch_hint()

	# Update mower engine sound & HUD
	var spd_ratio := _mower.velocity.length() / maxf(_mower.max_speed, 1.0)
	_sfx.update_engine(spd_ratio, _mower.is_boosting, true)
	_minimap_refresh_accum += delta
	_update_hud_frame(_minimap_refresh_accum >= 0.10)
	if _minimap_refresh_accum >= 0.10:
		_minimap_refresh_accum = 0.0

func _spawn_random_special_grass() -> void:
	var avoid := _collect_obstacle_positions()
	avoid.append(_mower.global_position)
	var spot := _lawn.find_unmowed_spot(78.0, avoid, 90.0)
	if spot.x >= 0.0:
		_lawn.spawn_special_patch(spot, randf_range(50.0, 72.0), randf() < 0.45)

func _spawn_random_flower() -> SpecialFlower:
	var avoid := _collect_obstacle_positions()
	avoid.append(_mower.global_position)
	for fl in _flowers:
		if is_instance_valid(fl):
			avoid.append(fl.position)
	var spot := _lawn.find_unmowed_spot(84.0, avoid, 105.0)
	if spot.x < 0.0:
		# Fallback anywhere in bounds away from obstacles
		var rect := _lawn.get_play_rect().grow(-84.0)
		spot = Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))
	var fl := SpecialFlower.new()
	var kinds := [SpecialFlower.FlowerKind.SUNFLOWER, SpecialFlower.FlowerKind.MAGENTA_STAR, SpecialFlower.FlowerKind.BLUE_BELL]
	fl.setup(spot, kinds[randi() % kinds.size()], 18.0)
	fl.collected.connect(_on_flower_collected)
	fl.expired.connect(func(f: SpecialFlower) -> void: _flowers.erase(f))
	_world_objects.add_child(fl)
	_flowers.append(fl)
	# Also bless a small colorful turf circle beneath the flower!
	_lawn.spawn_special_patch(spot, 44.0, true)
	return fl

func _on_flower_collected(fl: SpecialFlower) -> void:
	flowers_harvested += 1
	var bonus := 240 if fever_timer > 0.0 else 120
	score += bonus
	fever_timer = minf(fever_timer + FEVER_DURATION, FEVER_DURATION * 1.6)
	_sfx.play_flower()
	_mower.spawn_burst(fl.position, 18, fl.get_primary_color(), 190.0)
	_spawn_floating_text("2× +%d" % bonus, fl.position + Vector2(0, -24), Color(1.0, 0.94, 0.28), 26, 1.15)

func _spawn_random_boost_pickup() -> BoostPickup:
	var avoid := _collect_obstacle_positions()
	avoid.append(_mower.global_position)
	for fl in _flowers:
		if is_instance_valid(fl):
			avoid.append(fl.position)
	for bp in _boost_pickups:
		if is_instance_valid(bp):
			avoid.append(bp.position)
	var spot := _lawn.find_unmowed_spot(84.0, avoid, 110.0)
	if spot.x < 0.0:
		var rect := _lawn.get_play_rect().grow(-84.0)
		spot = Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))
	var pickup := BoostPickup.new()
	pickup.setup(spot, 18.0)
	pickup.collected.connect(_on_boost_pickup_collected)
	pickup.expired.connect(func(p: BoostPickup) -> void: _boost_pickups.erase(p))
	_world_objects.add_child(pickup)
	_boost_pickups.append(pickup)
	_boosts_spawned_total += 1
	return pickup

func _on_boost_pickup_collected(pickup: BoostPickup) -> void:
	_mower.activate_boost(BOOST_DURATION, BOOST_DURATION * 1.6)
	_shake_intensity = maxf(_shake_intensity, 4.5)
	_spawn_floating_text("冲刺!", pickup.position + Vector2(0, -26), Color(1.0, 0.94, 0.34), 26, 1.05)

func _on_mower_hit_rock(_pos: Vector2) -> void:
	_sfx.play_rock()
	_shake_intensity = maxf(_shake_intensity, 7.5)

func _on_animal_interfered(_animal: LawnAnimal, kind: LawnAnimal.AnimalType, push_dir: Vector2) -> void:
	if state != GameState.PLAYING:
		return
	match kind:
		LawnAnimal.AnimalType.SHEEP:
			if _mower.apply_sheep_bump(push_dir):
				_sfx.play_sheep()
				_shake_intensity = maxf(_shake_intensity, 8.5)
				_spawn_floating_text("咩!", _mower.global_position + Vector2(0, -34), Color(1.0, 0.98, 0.90), 24)
		LawnAnimal.AnimalType.DOG:
			if _mower.apply_dog_dizzy(push_dir):
				_sfx.play_dog()
				_shake_intensity = maxf(_shake_intensity, 7.0)
				_spawn_floating_text("眩晕!", _mower.global_position + Vector2(0, -36), Color(1.0, 0.82, 0.25), 24)
		LawnAnimal.AnimalType.PIG:
			if _mower.apply_mud_slip():
				_sfx.play_mud()
				_shake_intensity = maxf(_shake_intensity, 5.5)
				_spawn_floating_text("打滑!", _mower.global_position + Vector2(0, -34), Color(1.0, 0.72, 0.80), 24)

func _on_pig_spawned_mud(pos: Vector2) -> void:
	if state != GameState.PLAYING:
		return
	if _mud_puddles.size() >= 10:
		return
	var puddle := MudPuddle.new()
	puddle.setup(pos, randf_range(22.0, 28.0))
	_world_objects.add_child(puddle)
	_mud_puddles.append(puddle)

func _spawn_floating_text(msg: String, pos: Vector2, col: Color, sz: int = 20, dur: float = 0.95) -> void:
	var ft := FloatingText.new()
	ft.setup(msg, pos, col, sz, dur)
	_world_objects.add_child(ft)

func _update_hud_frame(refresh_minimap: bool = true) -> void:
	_hud.update_hud(
		time_left,
		_lawn.get_mowed_ratio(),
		score,
		fever_timer,
		FEVER_DURATION,
		_mower.boost_timer,
		BOOST_DURATION,
		_mower.get_status_label()
	)
	if refresh_minimap:
		_hud.update_minimap(
			_lawn.get_minimap_texture(),
			_lawn.get_play_rect().size,
			_mower.global_position,
			_mower.facing_angle,
			_flowers,
			_boost_pickups,
			_animals
		)

func _end_game() -> void:
	state = GameState.GAME_OVER
	_mower.control_enabled = false
	_sfx.stop_engine()
	_sfx.set_bgm_ducked(true)
	_sfx.play_finish()

	var is_new_record := score > best_score
	if is_new_record:
		best_score = score
		_save_high_score()

	var can_revive := (not _has_revived_this_round) and (_lawn.get_mowed_ratio() < 0.995)
	_hud.show_gameover(
		score,
		_lawn.get_mowed_ratio(),
		_lawn.get_mowed_sq_meters(),
		special_cells_cut,
		flowers_harvested,
		best_score,
		is_new_record,
		can_revive
	)

func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("records", "best_score", 0))

func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_score", best_score)
	cfg.save(SAVE_PATH)
