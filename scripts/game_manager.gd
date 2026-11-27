extends Node2D
class_name GameManager

const MATCH_DURATION := 60.0
const YARD_CLEAR_RATIO := 0.960
const YARD_CLEAR_TIME_BONUS := 12.0
const YARD_TRANSITION_DELAY := 0.95
const FEVER_DURATION := 6.5
const BOOST_DURATION := 5.0

enum GameState { TITLE, PLAYING, GAME_OVER }

var state: GameState = GameState.TITLE
var time_left: float = MATCH_DURATION
var score: int = 0
var fever_timer: float = 0.0
var special_cells_cut: int = 0
var flowers_harvested: int = 0
var yard_level: int = 1
var yards_cleared: int = 0

var _last_whole_sec: int = 60
var _yard_transition_timer: float = 0.0
var _shake_intensity: float = 0.0
var _special_popup_accum: int = 0
var _special_popup_timer: float = 0.0
var _minimap_refresh_accum: float = 0.0
var _round_bonus_coins: int = 0
var _last_round_coins: int = 0
var _double_coins_claimed: bool = false
var _active_stats: Dictionary = {}

var _progress: ProgressManager
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
	_progress = ProgressManager.new()
	_progress.load_data()
	_build_scene_nodes()
	_setup_round(false)
	_hud.show_title(_progress.best_score, _progress.coins, _progress.has_any_affordable_upgrade())

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
	_mower.rock_shattered.connect(_on_mower_rock_shattered)
	_mower.boost_started.connect(func() -> void: _sfx.play_boost())
	add_child(_mower)

	_camera = Camera2D.new()
	_camera.enabled = true
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.5
	_camera.zoom = Vector2(0.95, 0.95)
	add_child(_camera)

	_hud = GameHUD.new()
	_hud.start_requested.connect(_on_normal_start_requested)
	_hud.start_ad_requested.connect(_on_start_ad_requested)
	_hud.double_coins_ad_requested.connect(_on_double_coins_ad_requested)
	_hud.garage_requested.connect(_on_garage_requested)
	_hud.restart_requested.connect(_on_normal_start_requested)
	_hud.home_requested.connect(_return_to_title)
	_hud.mute_toggled.connect(_on_mute_toggled)
	_hud.star_landed.connect(func(idx: int) -> void: _sfx.play_star(idx))
	add_child(_hud)
	_hud.joystick.input_changed.connect(func(v: Vector2) -> void: _mower.joystick_input = v)

	# Wire Garage Overlay signals
	_hud.garage.closed.connect(_on_garage_closed)
	_hud.garage.stat_upgrade_clicked.connect(_on_garage_stat_upgrade)
	_hud.garage.mower_buy_clicked.connect(_on_garage_mower_buy)
	_hud.garage.mower_equip_clicked.connect(_on_garage_mower_equip)
	_hud.garage.mower_skill_upgrade_clicked.connect(_on_garage_skill_upgrade)
	_hud.garage.mower_trial_ad_clicked.connect(_on_garage_trial_ad)
	_hud.garage.free_coins_ad_clicked.connect(_on_garage_free_coins_ad)

func _input(event: InputEvent) -> void:
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
	_progress.trial_mower = ""
	_setup_round(false)
	state = GameState.TITLE
	_sfx.stop_engine()
	_sfx.set_bgm_ducked(true)
	_hud.show_title(_progress.best_score, _progress.coins, _progress.has_any_affordable_upgrade())

func _on_normal_start_requested() -> void:
	_progress.trial_mower = ""
	_start_game()

func _start_game() -> void:
	_setup_round(true)
	state = GameState.PLAYING
	_mower.control_enabled = true
	_hud.show_playing(false)
	_sfx.start_bgm(true)
	_sfx.start_engine()

	# Apply mower's exclusive Start Rainbow Boost skill (Classic Lv.1-10 = 3s..10s, Rainbow = 5s..10s)!
	var start_boost := float(_active_stats.get("start_boost_dur", 0.0))
	if start_boost > 0.1:
		_mower.activate_boost(start_boost, maxf(10.0, start_boost))
		_spawn_floating_text("开局冲刺 %.1fs!" % start_boost, _mower.global_position + Vector2(0, -38), Color(1.0, 0.94, 0.28), 26, 1.25)

	if bool(_active_stats.get("is_trial", false)):
		var m_name := String(ProgressManager.MOWER_DEFS[String(_active_stats["mower_id"])]["name"])
		_hud.show_toast("试驾中：%s（技能Lv.4体验）" % m_name, true)

func _start_game_with_ad_buff() -> void:
	_progress.trial_mower = ""
	_start_game()
	fever_timer = FEVER_DURATION
	var ad_boost := maxf(BOOST_DURATION, float(_active_stats.get("start_boost_dur", 0.0)) + 2.5)
	_mower.activate_boost(ad_boost, maxf(12.0, ad_boost))
	_sfx.play_flower()
	_update_hud_frame(true)
	_spawn_floating_text("开局冲刺 2×!", _mower.global_position + Vector2(0, -42), Color(1.0, 0.94, 0.28), 28, 1.35)
	_hud.show_toast("开局冲刺 + 双倍得分已激活！", true)

func _on_garage_requested() -> void:
	if state == GameState.PLAYING:
		return
	_hud.garage.open_with_progress(_progress, 1)

func _on_garage_closed() -> void:
	_hud.update_wallet_ui(_progress.coins, _progress.has_any_affordable_upgrade())
	_active_stats = _progress.compute_effective_stats()
	_mower.apply_loadout(_active_stats)

func _on_garage_stat_upgrade(stat_key: String) -> void:
	if _progress.upgrade_stat(stat_key):
		_sfx.play_star(1)
		_hud.garage.refresh()
		_hud.update_wallet_ui(_progress.coins, _progress.has_any_affordable_upgrade())
		var lv := _progress.get_stat_level(stat_key)
		var nm := String(ProgressManager.STAT_META[stat_key]["name"])
		if lv == 10 or lv == 20 or lv == 30:
			_sfx.play_flower()
			_hud.show_toast("%s 达 Lv.%d 解锁新特性！" % [nm, lv], true)

func _on_garage_mower_buy(mower_id: String) -> void:
	if _progress.buy_mower(mower_id):
		_sfx.play_finish()
		_hud.garage.refresh()
		_hud.update_wallet_ui(_progress.coins, _progress.has_any_affordable_upgrade())
		var nm := String(ProgressManager.MOWER_DEFS[mower_id]["name"])
		_hud.show_toast("解锁并装备「%s」！" % nm, true)

func _on_garage_mower_equip(mower_id: String) -> void:
	if _progress.equip_mower(mower_id):
		_sfx.play_star(0)
		_hud.garage.refresh()
		var nm := String(ProgressManager.MOWER_DEFS[mower_id]["name"])
		_hud.show_toast("已切换「%s」" % nm, true)

func _on_garage_skill_upgrade(mower_id: String) -> void:
	if _progress.upgrade_mower_skill(mower_id):
		_sfx.play_star(2)
		_hud.garage.refresh()
		_hud.update_wallet_ui(_progress.coins, _progress.has_any_affordable_upgrade())
		var sk_nm := String(ProgressManager.MOWER_DEFS[mower_id]["skill_name"])
		var lv := _progress.get_skill_level(mower_id)
		_hud.show_toast("技能「%s」升至 Lv.%d！" % [sk_nm, lv], true)

func _on_garage_trial_ad(mower_id: String) -> void:
	if _ad_manager == null or _ad_manager.is_busy():
		return
	_ad_manager.show_rewarded_video("trial:" + mower_id)

func _on_garage_free_coins_ad() -> void:
	if _ad_manager == null or _ad_manager.is_busy():
		return
	_ad_manager.show_rewarded_video("free_coins")

func _on_start_ad_requested() -> void:
	if state != GameState.TITLE or _ad_manager == null or _ad_manager.is_busy():
		return
	_ad_manager.show_rewarded_video("start_buff")

func _on_double_coins_ad_requested() -> void:
	if state != GameState.GAME_OVER or _double_coins_claimed or _last_round_coins <= 0:
		return
	if _ad_manager == null or _ad_manager.is_busy():
		return
	_ad_manager.show_rewarded_video("double_coins")

func _on_ad_started(_placement: String) -> void:
	_sfx.set_ad_paused(true)
	_hud.set_ad_buttons_loading(true)

func _on_ad_finished(placement: String, rewarded: bool, status: String, _error_msg: String) -> void:
	_sfx.set_ad_paused(false)
	_hud.set_ad_buttons_loading(false)
	if rewarded:
		if placement == "start_buff":
			_start_game_with_ad_buff()
		elif placement == "double_coins":
			if not _double_coins_claimed and _last_round_coins > 0:
				_double_coins_claimed = true
				_progress.add_coins(_last_round_coins)
				_sfx.play_flower()
				_hud.mark_double_coins_claimed(_last_round_coins * 2)
				_hud.update_wallet_ui(_progress.coins, _progress.has_any_affordable_upgrade())
				_hud.show_toast("翻倍成功！额外获得 +%d 金币" % _last_round_coins, true)
		elif placement == "free_coins":
			_progress.add_coins(ProgressManager.AD_FREE_COINS)
			_sfx.play_flower()
			_hud.garage.refresh()
			_hud.update_wallet_ui(_progress.coins, _progress.has_any_affordable_upgrade())
			_hud.show_toast("已领取 +%d 金币！" % ProgressManager.AD_FREE_COINS, true)
		elif placement.begins_with("trial:"):
			var trial_id := placement.substr(6)
			if ProgressManager.MOWER_DEFS.has(trial_id):
				_progress.trial_mower = trial_id
				_hud.garage.visible = false
				_start_game()
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

func _get_yard_config(level: int) -> Dictionary:
	match level:
		1:
			return {
				"grid_w": 38, "grid_h": 52, "theme": 0,
				"trees": 3, "rocks": 4,
				"animals": [LawnAnimal.AnimalType.SHEEP, LawnAnimal.AnimalType.SHEEP, LawnAnimal.AnimalType.DOG],
				"special_patches": 2, "flowers": 2, "boost_chance": 0.50, "score_mult": 1.0,
			}
		2:
			return {
				"grid_w": 42, "grid_h": 58, "theme": 1,
				"trees": 4, "rocks": 5,
				"animals": [LawnAnimal.AnimalType.SHEEP, LawnAnimal.AnimalType.SHEEP, LawnAnimal.AnimalType.DOG, LawnAnimal.AnimalType.PIG],
				"special_patches": 2, "flowers": 2, "boost_chance": 0.55, "score_mult": 1.2,
			}
		3:
			return {
				"grid_w": 46, "grid_h": 64, "theme": 2,
				"trees": 5, "rocks": 6,
				"animals": [LawnAnimal.AnimalType.SHEEP, LawnAnimal.AnimalType.SHEEP, LawnAnimal.AnimalType.DOG, LawnAnimal.AnimalType.DOG, LawnAnimal.AnimalType.PIG],
				"special_patches": 2, "flowers": 2, "boost_chance": 0.60, "score_mult": 1.5,
			}
		_:
			return {
				"grid_w": 50, "grid_h": 70, "theme": (level - 1) % 4,
				"trees": 5, "rocks": 7,
				"animals": [LawnAnimal.AnimalType.SHEEP, LawnAnimal.AnimalType.SHEEP, LawnAnimal.AnimalType.DOG, LawnAnimal.AnimalType.DOG, LawnAnimal.AnimalType.PIG, LawnAnimal.AnimalType.PIG],
				"special_patches": 2, "flowers": 2, "boost_chance": 0.60, "score_mult": 1.5 + float(level - 3) * 0.25,
			}

func _setup_round(clear_start_grass: bool) -> void:
	_active_stats = _progress.compute_effective_stats()
	_mower.apply_loadout(_active_stats)

	time_left = MATCH_DURATION
	_last_whole_sec = int(MATCH_DURATION)
	score = 0
	fever_timer = 0.0
	special_cells_cut = 0
	flowers_harvested = 0
	yard_level = 1
	yards_cleared = 0
	_yard_transition_timer = 0.0
	_shake_intensity = 0.0
	_special_popup_accum = 0
	_special_popup_timer = 0.0
	_round_bonus_coins = 0
	_last_round_coins = 0
	_double_coins_claimed = false
	_load_yard(yard_level, clear_start_grass)

func _load_yard(level: int, active_play: bool) -> void:
	for child in _world_objects.get_children():
		child.queue_free()
	_obstacles.clear()
	_animals.clear()
	_flowers.clear()
	_boost_pickups.clear()
	_mud_puddles.clear()

	var cfg := _get_yard_config(level)
	_lawn.configure_yard(int(cfg["grid_w"]), int(cfg["grid_h"]), int(cfg["theme"]))

	var rect := _lawn.get_play_rect()
	var center := rect.get_center()
	_mower.reset_state(center, rect)
	_mower.control_enabled = active_play
	_camera.position = center
	_camera.limit_left = int(rect.position.x - 64.0)
	_camera.limit_top = int(rect.position.y - 128.0)
	_camera.limit_right = int(rect.end.x + 64.0)
	_camera.limit_bottom = int(rect.end.y + 116.0)

	# All yard elements are pre-placed upfront (ZERO mid-game viewport pop-in!)
	_generate_obstacles(rect, center, int(cfg["trees"]), int(cfg["rocks"]))
	_generate_animals(rect, center, cfg["animals"], not active_play)
	_populate_yard_pickups(center, int(cfg["special_patches"]), int(cfg["flowers"]), float(cfg["boost_chance"]))

	if active_play:
		_lawn.mow_circle(center, _mower.cut_radius * 0.9)

	_update_hud_frame(true)

func _generate_obstacles(rect: Rect2, safe_center: Vector2, tree_count: int, rock_count: int) -> void:
	var placed: Array[Dictionary] = []

	for _i in range(tree_count):
		var rad := randf_range(21.0, 26.0)
		var pos := _pick_non_overlapping_pos(rect, 78.0, safe_center, 145.0, placed, rad + 84.0)
		if pos.x >= 0.0:
			var tree := LawnObstacle.new()
			tree.setup(LawnObstacle.Kind.TREE, pos, rad, _mower)
			_world_objects.add_child(tree)
			_obstacles.append(tree)
			_lawn.mark_obstacle_circle(pos, rad + 4.0)
			placed.append({"pos": pos, "rad": rad})

	for _i in range(rock_count):
		var rad := randf_range(19.0, 29.0)
		var pos := _pick_non_overlapping_pos(rect, 66.0, safe_center, 125.0, placed, rad + 68.0)
		if pos.x >= 0.0:
			var rock := LawnObstacle.new()
			rock.setup(LawnObstacle.Kind.ROCK, pos, rad, _mower)
			_world_objects.add_child(rock)
			_obstacles.append(rock)
			_lawn.mark_obstacle_circle(pos, rad + 2.0)
			placed.append({"pos": pos, "rad": rad})

func _generate_animals(rect: Rect2, safe_center: Vector2, animal_types: Array, is_preview: bool = false) -> void:
	var avoid: Array[Dictionary] = []
	for obs in _obstacles:
		avoid.append({"pos": obs.position, "rad": obs.radius})

	for t in animal_types:
		var kind: LawnAnimal.AnimalType = t
		var pos := _pick_non_overlapping_pos(rect, 72.0, safe_center, 170.0, avoid, 62.0)
		if pos.x < 0.0:
			pos = Vector2(randf_range(90.0, rect.size.x - 90.0), randf_range(90.0, rect.size.y - 90.0))
		var animal := LawnAnimal.new()
		animal.setup(kind, pos, rect, _mower)
		animal.preview_mode = is_preview
		animal.interfered_with_mower.connect(_on_animal_interfered)
		animal.spawned_mud.connect(_on_pig_spawned_mud)
		_world_objects.add_child(animal)
		_animals.append(animal)
		avoid.append({"pos": pos, "rad": 40.0})

func _populate_yard_pickups(safe_center: Vector2, patch_count: int, flower_count: int, boost_chance: float) -> void:
	var avoid := _collect_obstacle_positions()
	avoid.append(safe_center)

	# 1. Special colored 2x grass patches (independent of flowers!)
	for i in range(patch_count):
		var spot := _lawn.find_unmowed_spot(74.0, avoid, 95.0)
		if spot.x >= 0.0:
			_lawn.spawn_special_patch(spot, randf_range(46.0, 62.0), i % 2 == 1)
			avoid.append(spot)

	# 2. Independent Lucky Flowers blooming cleanly on normal green grass
	var kinds := [SpecialFlower.FlowerKind.SUNFLOWER, SpecialFlower.FlowerKind.MAGENTA_STAR, SpecialFlower.FlowerKind.BLUE_BELL]
	for _j in range(flower_count):
		var fl_spot := _lawn.find_unmowed_spot(76.0, avoid, 105.0)
		if fl_spot.x >= 0.0:
			var fl := SpecialFlower.new()
			fl.setup(fl_spot, kinds[randi() % kinds.size()], 999.0)
			fl.lifetime_paused = true
			fl.collected.connect(_on_flower_collected)
			fl.expired.connect(func(f: SpecialFlower) -> void: _flowers.erase(f))
			_world_objects.add_child(fl)
			_flowers.append(fl)
			avoid.append(fl_spot)

	# 3. Rare 5s Rainbow Turbo Boost pickup (max 1 per yard)
	if randf() < boost_chance:
		var bp_spot := _lawn.find_unmowed_spot(80.0, avoid, 115.0)
		if bp_spot.x >= 0.0:
			var pickup := BoostPickup.new()
			pickup.setup(bp_spot, 999.0)
			pickup.lifetime_paused = true
			pickup.collected.connect(_on_boost_pickup_collected)
			pickup.expired.connect(func(p: BoostPickup) -> void: _boost_pickups.erase(p))
			_world_objects.add_child(pickup)
			_boost_pickups.append(pickup)

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
		if is_instance_valid(o) and not o.is_shattered:
			pts.append(o.position)
	return pts

func _process(delta: float) -> void:
	var target_cam := _mower.global_position
	if state == GameState.PLAYING and _yard_transition_timer <= 0.0:
		target_cam += _mower.velocity * 0.18
	_camera.position = _camera.position.lerp(target_cam, minf(delta * 7.5, 1.0))

	if _shake_intensity > 0.1:
		_camera.offset = Vector2(randf_range(-_shake_intensity, _shake_intensity), randf_range(-_shake_intensity, _shake_intensity))
		_shake_intensity = lerpf(_shake_intensity, 0.0, minf(delta * 10.0, 1.0))
	else:
		_camera.offset = Vector2.ZERO

	if state != GameState.PLAYING:
		_sfx.update_engine(0.0, false, false)
		return

	if _yard_transition_timer > 0.0:
		_yard_transition_timer -= delta
		_sfx.update_engine(0.0, false, false)
		if _yard_transition_timer <= 0.0:
			yard_level += 1
			_load_yard(yard_level, true)
			var clr_boost := float(_active_stats.get("clear_boost_dur", 1.2))
			_mower.activate_boost(clr_boost, maxf(10.0, clr_boost))
			_spawn_floating_text("第%d关 开始!" % yard_level, _mower.global_position + Vector2(0, -38), Color(1.0, 0.96, 0.34), 28, 1.15)
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

	if fever_timer > 0.0:
		fever_timer = maxf(0.0, fever_timer - delta)
	_mower.fever_active = fever_timer > 0.0
	_lawn.set_fever_strength(clampf(fever_timer / 1.5, 0.0, 1.0))

	# Mow grass beneath the mower
	var active_cut_r := _mower.get_active_cut_radius()
	var cut_res := _lawn.mow_circle(_mower.global_position, active_cut_r)
	var normal_cut: int = cut_res["normal"]
	var special_cut: int = cut_res["special"]

	# Auto-vacuum stray grass blades around nearby tree trunks & rocks (ZERO annoying edge slivers!)
	var edge_snap := float(_active_stats.get("edge_snap_radius", 14.0))
	for obs in _obstacles:
		if is_instance_valid(obs) and not obs.is_shattered:
			var trigger_d := obs.radius + active_cut_r + edge_snap
			if _mower.global_position.distance_squared_to(obs.global_position) <= trigger_d * trigger_d:
				var snap_res := _lawn.snap_clear_around_point(obs.global_position, obs.radius + edge_snap + 6.0)
				normal_cut += int(snap_res["normal"])
				special_cut += int(snap_res["special"])

	var total_cut := normal_cut + special_cut
	if total_cut > 0:
		var fever_mult := 2 if fever_timer > 0.0 else 1
		var yard_mult: float = float(_get_yard_config(yard_level)["score_mult"])
		var blade_mult: float = float(_active_stats.get("blade_score_mult", 1.0))
		var raw_pts := float(normal_cut * 2 * fever_mult + special_cut * 4 * fever_mult) * yard_mult * blade_mult
		score += int(round(raw_pts))
		special_cells_cut += special_cut
		_mower.spawn_cut_particles(special_cut > 0, total_cut)
		_sfx.play_cut(special_cut > 0)

		if special_cut > 0:
			_special_popup_accum += int(round(float(special_cut * 4 * fever_mult) * yard_mult * blade_mult))
			if _special_popup_timer <= 0.0:
				_special_popup_timer = 0.28

	if _special_popup_timer > 0.0:
		_special_popup_timer -= delta
		if _special_popup_timer <= 0.0 and _special_popup_accum > 0:
			var tag := "4× +%d" if fever_timer > 0.0 else "2× +%d"
			_spawn_floating_text(tag % _special_popup_accum, _mower.global_position + Vector2(0, -34), Color(1.0, 0.90, 0.22), 24)
			_special_popup_accum = 0

	# Check 96% -> 100% auto-sweep yard clear!
	if _lawn.get_mowed_ratio() >= YARD_CLEAR_RATIO:
		_trigger_yard_clear()
		return

	# Check flower harvesting
	for i in range(_flowers.size() - 1, -1, -1):
		var fl := _flowers[i]
		if not is_instance_valid(fl):
			_flowers.remove_at(i)
		elif fl.try_collect(_mower.global_position, active_cut_r * 0.72):
			_flowers.remove_at(i)

	# Check turbo boost pickup collection
	for i in range(_boost_pickups.size() - 1, -1, -1):
		var bp := _boost_pickups[i]
		if not is_instance_valid(bp):
			_boost_pickups.remove_at(i)
		elif bp.try_collect(_mower.global_position, active_cut_r * 0.72):
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

	if _mower.velocity.length() > 35.0 or (MATCH_DURATION - time_left) > 4.5:
		_hud.hide_touch_hint()

	var spd_ratio := _mower.velocity.length() / maxf(_mower.max_speed, 1.0)
	_sfx.update_engine(spd_ratio, _mower.is_boosting, true)
	_minimap_refresh_accum += delta
	_update_hud_frame(_minimap_refresh_accum >= 0.10)
	if _minimap_refresh_accum >= 0.10:
		_minimap_refresh_accum = 0.0

func _trigger_yard_clear() -> void:
	_lawn.complete_all_remaining()
	yards_cleared += 1
	var clear_bonus := 500 * yard_level
	score += clear_bonus
	time_left += YARD_CLEAR_TIME_BONUS
	_last_whole_sec = int(ceil(time_left))
	_mower.control_enabled = false
	_yard_transition_timer = YARD_TRANSITION_DELAY
	_shake_intensity = maxf(_shake_intensity, 6.0)
	_sfx.play_finish()
	_mower.spawn_burst(_mower.global_position, 28, Color(1.0, 0.92, 0.24), 240.0)
	_mower.spawn_burst(_mower.global_position, 18, Color(0.35, 0.92, 0.45), 210.0)
	_spawn_floating_text("100%%清空! +%d" % clear_bonus, _mower.global_position + Vector2(0, -40), Color(1.0, 0.96, 0.30), 28, 1.1)
	_hud.show_toast("第%d关 100%%完美清场！+12秒" % yard_level, true)
	_update_hud_frame(true)

func _on_mower_rock_shattered(rock_node: Node2D) -> void:
	if not (rock_node is LawnObstacle):
		return
	var obs := rock_node as LawnObstacle
	if obs.is_shattered:
		return
	var pos := obs.global_position
	var rad := obs.radius
	obs.shatter()
	_lawn.clear_obstacle_cells(pos, rad + 4.0)
	_round_bonus_coins += 25
	score += 150
	_sfx.play_rock()
	_sfx.play_star(1)
	_shake_intensity = maxf(_shake_intensity, 6.5)
	_spawn_floating_text("碎石 +25金!", pos + Vector2(0, -28), Color(1.0, 0.92, 0.26), 24, 1.1)

func _on_flower_collected(fl: SpecialFlower) -> void:
	flowers_harvested += 1
	var bonus := 240 if fever_timer > 0.0 else 120
	score += bonus
	fever_timer = minf(fever_timer + FEVER_DURATION, FEVER_DURATION * 1.6)
	_sfx.play_flower()
	_mower.spawn_burst(fl.position, 18, fl.get_primary_color(), 190.0)
	_spawn_floating_text("2× +%d" % bonus, fl.position + Vector2(0, -24), Color(1.0, 0.94, 0.28), 26, 1.15)

func _on_boost_pickup_collected(pickup: BoostPickup) -> void:
	_mower.activate_boost(BOOST_DURATION, maxf(10.0, BOOST_DURATION * 1.4))
	_shake_intensity = maxf(_shake_intensity, 4.5)
	_spawn_floating_text("冲刺!", pickup.position + Vector2(0, -26), Color(1.0, 0.94, 0.34), 26, 1.05)

func _on_mower_hit_rock(_pos: Vector2) -> void:
	_sfx.play_rock()
	_shake_intensity = maxf(_shake_intensity, 7.5)

func _on_animal_interfered(animal: LawnAnimal, kind: LawnAnimal.AnimalType, push_dir: Vector2) -> void:
	if state != GameState.PLAYING or _yard_transition_timer > 0.0:
		return
	# Crusher / Rainbow Smash skill: knock interfering animals flying + earn bonus coins!
	if _mower.smash_animals and is_instance_valid(animal):
		animal.knock_flying(-push_dir)
		_round_bonus_coins += 15
		score += 80
		_sfx.play_star(0)
		_shake_intensity = maxf(_shake_intensity, 4.5)
		_mower.spawn_burst(animal.global_position, 12, Color(1.0, 0.92, 0.30), 170.0)
		_spawn_floating_text("撞飞 +15金!", animal.global_position + Vector2(0, -28), Color(1.0, 0.92, 0.28), 24)
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
	if state != GameState.PLAYING or _yard_transition_timer > 0.0:
		return
	if _mud_puddles.size() >= 8:
		var old: MudPuddle = _mud_puddles.pop_front()
		if is_instance_valid(old):
			old.queue_free()
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
		maxf(BOOST_DURATION, _mower.boost_timer),
		_mower.get_status_label(),
		_mower.shield_timer,
		maxf(_mower.shield_dur, 1.0),
		_mower.whirlwind_timer,
		maxf(_mower.whirlwind_dur, 1.0)
	)
	if refresh_minimap:
		_hud.update_minimap(
			_lawn.get_minimap_texture(),
			_lawn.get_play_rect().size,
			_mower.global_position,
			_mower.facing_angle,
			_flowers,
			_boost_pickups,
			_animals,
			yard_level
		)

func _end_game() -> void:
	state = GameState.GAME_OVER
	_mower.control_enabled = false
	_sfx.stop_engine()
	_sfx.set_bgm_ducked(true)
	_sfx.play_finish()

	var is_new_record := score > _progress.best_score
	if is_new_record:
		_progress.best_score = score

	# Calculate round Grass Coins (score + cleared yards + smash bonuses) * coin_mult
	var base_coins := maxi(25, int(round(float(score) / 28.0)) + yards_cleared * 45 + _round_bonus_coins)
	var coin_mult := float(_active_stats.get("coin_mult", 1.0))
	_last_round_coins = maxi(25, int(round(float(base_coins) * coin_mult)))
	_double_coins_claimed = false
	_progress.trial_mower = ""
	_progress.add_coins(_last_round_coins)

	_hud.show_gameover(
		score,
		_lawn.get_mowed_ratio(),
		_lawn.get_mowed_sq_meters(),
		special_cells_cut,
		flowers_harvested,
		_progress.best_score,
		is_new_record,
		_last_round_coins,
		yards_cleared,
		_progress.coins,
		_progress.has_any_affordable_upgrade()
	)
