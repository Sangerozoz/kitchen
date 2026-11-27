extends CanvasLayer
class_name GameHUD

signal start_requested()
signal start_ad_requested()
signal revive_ad_requested()
signal restart_requested()
signal home_requested()
signal mute_toggled()
signal star_landed(star_idx: int)

var joystick: ThumbJoystick

var _cute_font: Font
var _ui_font: Font

var _top_hud: TopHudWidget
var _buff_stack: VBoxContainer
var _fever_pill: BuffPillWidget
var _boost_pill: BuffPillWidget
var _status_pill: StatusComicPill

var _hint_panel: PanelContainer
var _minimap: MinimapWidget
var _sound_btn: SoundToggleButton

var _title_overlay: Control
var _title_logo: TextureRect
var _title_start_btn: GlossyStartButton
var _title_ad_btn: RewardAdButton
var _title_best_badge: CrownScoreBadge
var _title_fade_tween: Tween

var _safe_containers: Array[Control] = []
var _last_vp_size: Vector2 = Vector2.ZERO
var _safe_top: float = 18.0
var _safe_bottom: float = 24.0
var _safe_left: float = 0.0
var _safe_right: float = 0.0

var _gameover_overlay: Control
var _go_card: GameOverCardWidget
var _go_revive_btn: RewardAdButton
var _go_retry_btn: GlossyStartButton
var _go_home_btn: RoundBackButton
var _toast_banner: ToastBanner

var _tex_grass: Texture2D
var _tex_flower: Texture2D
var _tex_crown: Texture2D
var _tex_clock: Texture2D
var _tex_star_gold: Texture2D
var _tex_star_empty: Texture2D
var _tex_harvest_title: Texture2D

func _ready() -> void:
	layer = 20
	_load_assets()
	_build_ui()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	call_deferred("_apply_safe_area")

func _load_assets() -> void:
	var cf: FontFile = load("res://assets/fonts/cute_font.ttf")
	var uf: FontFile = load("res://assets/fonts/ui_font.ttf")
	if cf != null and uf != null:
		cf.fallbacks = [uf]
	_cute_font = cf if cf != null else uf
	_ui_font = uf if uf != null else cf

	_tex_grass = load("res://assets/ui/icon_grass.png")
	_tex_flower = load("res://assets/ui/icon_flower.png")
	_tex_crown = load("res://assets/ui/icon_crown.png")
	_tex_clock = load("res://assets/ui/icon_clock.png")
	_tex_star_gold = load("res://assets/ui/star_gold.png")
	_tex_star_empty = load("res://assets/ui/star_empty.png")
	_tex_harvest_title = load("res://assets/ui/harvest_title.png")

func _make_safe_container(parent: Control) -> Control:
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	_safe_containers.append(box)
	return box

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Virtual joystick layer (full edge-to-edge touch area, top HUD + mute excluded)
	joystick = ThumbJoystick.new()
	root.add_child(joystick)

	var hud_safe := _make_safe_container(root)

	# --- SLEEK CARTOON TOP HUD BAR (safe below notch / Dynamic Island!) ---
	_top_hud = TopHudWidget.new()
	_top_hud.cute_font = _cute_font
	_top_hud.tex_grass = _tex_grass
	_top_hud.tex_clock = _tex_clock
	_top_hud.tex_star = _tex_star_gold
	_top_hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_hud.offset_top = 6.0
	_top_hud.offset_bottom = 68.0
	_top_hud.offset_left = 12.0
	_top_hud.offset_right = -12.0
	hud_safe.add_child(_top_hud)

	# --- COMPACT CARTOON BUFF & FEEDBACK STACK ---
	_buff_stack = VBoxContainer.new()
	_buff_stack.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_buff_stack.offset_top = 78.0
	_buff_stack.offset_bottom = 220.0
	_buff_stack.offset_left = -90.0
	_buff_stack.offset_right = 90.0
	_buff_stack.add_theme_constant_override("separation", 6)
	_buff_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	_buff_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_safe.add_child(_buff_stack)

	_fever_pill = BuffPillWidget.new()
	_fever_pill.setup_style(BuffPillWidget.Style.FEVER, _cute_font, _tex_flower)
	_fever_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fever_pill.visible = false
	_buff_stack.add_child(_fever_pill)

	_boost_pill = BuffPillWidget.new()
	_boost_pill.setup_style(BuffPillWidget.Style.RAINBOW_BOOST, _cute_font, null)
	_boost_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boost_pill.visible = false
	_buff_stack.add_child(_boost_pill)

	_status_pill = StatusComicPill.new()
	_status_pill.cute_font = _cute_font
	_status_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_status_pill.visible = false
	_buff_stack.add_child(_status_pill)

	# --- TOP-LEFT CARTOON MINIMAP (right below top HUD grass pill, clear of notch!) ---
	_minimap = MinimapWidget.new()
	_minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_minimap.offset_left = 14.0
	_minimap.offset_right = 102.0
	_minimap.offset_top = 78.0
	_minimap.offset_bottom = 210.0
	hud_safe.add_child(_minimap)

	# --- ULTRA-COMPACT TOUCH HINT PILL (well above bottom safe margin) ---
	_hint_panel = _make_pill_panel(Color(0.99, 0.96, 0.85, 0.90), Color(0.38, 0.22, 0.08, 0.92), 8)
	_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_panel.offset_left = -68.0
	_hint_panel.offset_right = 68.0
	_hint_panel.offset_top = -176.0
	_hint_panel.offset_bottom = -142.0
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_safe.add_child(_hint_panel)

	var hint_lbl := _make_label("拖动割草", 17, Color(0.30, 0.17, 0.05), HORIZONTAL_ALIGNMENT_CENTER, true)
	hint_lbl.add_theme_constant_override("outline_size", 0)
	_hint_panel.add_child(hint_lbl)

	_build_title_overlay(root)
	_build_gameover_overlay(root)

	# Topmost safe layer so top-right Sound/BGM toggle & toast stay accessible across Title, Playing, and GameOver
	var top_controls_safe := _make_safe_container(root)
	_sound_btn = SoundToggleButton.new()
	_sound_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_sound_btn.offset_left = -78.0
	_sound_btn.offset_right = -14.0
	_sound_btn.offset_top = 8.0
	_sound_btn.offset_bottom = 72.0
	_sound_btn.pressed.connect(func() -> void: mute_toggled.emit())
	top_controls_safe.add_child(_sound_btn)

	_toast_banner = ToastBanner.new()
	_toast_banner.cute_font = _cute_font
	_toast_banner.anchor_left = 0.08
	_toast_banner.anchor_right = 0.92
	_toast_banner.anchor_top = 0.64
	_toast_banner.anchor_bottom = 0.64
	_toast_banner.offset_top = -24.0
	_toast_banner.offset_bottom = 24.0
	_toast_banner.visible = false
	top_controls_safe.add_child(_toast_banner)

	set_playing_ui_visible(false)

func _compute_safe_insets() -> Dictionary:
	var vp := get_viewport()
	if vp == null:
		return {"top": 18.0, "bottom": 24.0, "left": 0.0, "right": 0.0}
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return {"top": 18.0, "bottom": 24.0, "left": 0.0, "right": 0.0}

	var aspect := vp_size.y / vp_size.x
	var is_tall_phone := aspect >= 1.85
	var is_touch_mobile := false

	var rep_top := 0.0
	var rep_bottom := 0.0
	var rep_left := 0.0
	var rep_right := 0.0

	if OS.has_feature("web"):
		var raw = JavaScriptBridge.eval("window.__getSafeAreaInsets ? window.__getSafeAreaInsets() : ''")
		if raw is String and raw != "":
			var parts := (raw as String).split(",")
			if parts.size() >= 7:
				var css_t := parts[0].to_float()
				var css_b := parts[1].to_float()
				var css_l := parts[2].to_float()
				var css_r := parts[3].to_float()
				var inner_w := parts[4].to_float()
				var inner_h := parts[5].to_float()
				is_touch_mobile = parts[6].to_int() == 1
				if inner_h > 1.0 and inner_w > 1.0:
					var sy := vp_size.y / inner_h
					var sx := vp_size.x / inner_w
					rep_top = css_t * sy
					rep_bottom = css_b * sy
					rep_left = css_l * sx
					rep_right = css_r * sx
	elif OS.has_feature("ios") or OS.has_feature("android"):
		is_touch_mobile = true
		var win_size := Vector2(DisplayServer.window_get_size())
		var safe_rect := DisplayServer.get_display_safe_area()
		if win_size.x > 1.0 and win_size.y > 1.0 and safe_rect.size.x > 0 and safe_rect.size.y > 0:
			var sx := vp_size.x / win_size.x
			var sy := vp_size.y / win_size.y
			rep_top = maxf(0.0, float(safe_rect.position.y) * sy)
			rep_bottom = maxf(0.0, (win_size.y - float(safe_rect.end.y)) * sy)
			rep_left = maxf(0.0, float(safe_rect.position.x) * sx)
			rep_right = maxf(0.0, (win_size.x - float(safe_rect.end.x)) * sx)

	# Reserve clearance below BOTH notch/Dynamic Island AND TapTap mini-app top-right capsule (··· | ◯)
	var min_top := 128.0 if is_tall_phone else (104.0 if is_touch_mobile else 16.0)
	var min_bottom := 48.0 if is_tall_phone else (34.0 if is_touch_mobile else 22.0)
	var capsule_pad := 62.0 if (is_tall_phone or is_touch_mobile) else 8.0
	var final_top := maxf(rep_top + (capsule_pad if rep_top > 0.0 else 0.0), min_top)
	var final_bottom := maxf(rep_bottom + (8.0 if rep_bottom > 0.0 else 0.0), min_bottom)

	return {
		"top": clampf(final_top, 16.0, vp_size.y * 0.19),
		"bottom": clampf(final_bottom, 20.0, vp_size.y * 0.12),
		"left": clampf(rep_left, 0.0, vp_size.x * 0.08),
		"right": clampf(rep_right, 0.0, vp_size.x * 0.08),
	}

func _apply_safe_area() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	_last_vp_size = vp.get_visible_rect().size
	var insets := _compute_safe_insets()
	_safe_top = float(insets["top"])
	_safe_bottom = float(insets["bottom"])
	_safe_left = float(insets["left"])
	_safe_right = float(insets["right"])

	for box in _safe_containers:
		if is_instance_valid(box):
			box.offset_top = _safe_top
			box.offset_bottom = -_safe_bottom
			box.offset_left = _safe_left
			box.offset_right = -_safe_right

	if joystick != null:
		joystick.top_exclude_y = _safe_top + 78.0
		joystick.bottom_safe_margin = _safe_bottom

func _update_sound_btn_pos(in_gameplay: bool) -> void:
	if _sound_btn == null:
		return
	if in_gameplay:
		# Larger 64x64 button cleanly below score pill, symmetrically opposite top-left minimap
		_sound_btn.offset_top = 78.0
		_sound_btn.offset_bottom = 142.0
	else:
		# Clean top-right corner of safe area (below mini-app capsule) on Title & GameOver screens
		_sound_btn.offset_top = 8.0
		_sound_btn.offset_bottom = 72.0

func _process(_delta: float) -> void:
	var vp := get_viewport()
	if vp != null:
		var cur_sz := vp.get_visible_rect().size
		if cur_sz != _last_vp_size:
			_apply_safe_area()
	if _sound_btn != null and joystick != null:
		joystick.excluded_rect = _sound_btn.get_global_rect().grow(10.0)

func set_muted_visual(muted: bool) -> void:
	if _sound_btn != null:
		_sound_btn.is_muted = muted
		_sound_btn.queue_redraw()

func _build_title_overlay(root: Control) -> void:
	# Fullscreen illustrated Start Screen (blocks touch pass-through until Start button is tapped!)
	_title_overlay = Control.new()
	_title_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_title_overlay)

	# Fullscreen portrait meadow key art background (edge-to-edge behind safe area)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = load("res://assets/ui/start_bg.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_overlay.add_child(bg)

	var title_safe := _make_safe_container(_title_overlay)

	# Static Title Logo framed cleanly in upper sky inside safe area
	_title_logo = TextureRect.new()
	_title_logo.anchor_left = 0.05
	_title_logo.anchor_right = 0.95
	_title_logo.anchor_top = 0.03
	_title_logo.anchor_bottom = 0.36
	_title_logo.offset_left = 0.0
	_title_logo.offset_right = 0.0
	_title_logo.offset_top = 0.0
	_title_logo.offset_bottom = 0.0
	_title_logo.texture = load("res://assets/ui/title_logo.png")
	_title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_safe.add_child(_title_logo)

	# Visual Crown + Best Score badge neatly above the Start button
	_title_best_badge = CrownScoreBadge.new()
	_title_best_badge.cute_font = _cute_font
	_title_best_badge.tex_crown = _tex_crown
	_title_best_badge.anchor_left = 0.27
	_title_best_badge.anchor_right = 0.73
	_title_best_badge.anchor_top = 0.688
	_title_best_badge.anchor_bottom = 0.748
	_title_best_badge.offset_left = 0.0
	_title_best_badge.offset_right = 0.0
	_title_best_badge.offset_top = 0.0
	_title_best_badge.offset_bottom = 0.0
	_title_best_badge.visible = false
	title_safe.add_child(_title_best_badge)

	# Glossy Start Button ("开始割草") matching loading bar slot
	_title_start_btn = GlossyStartButton.new()
	_title_start_btn.text = "开始割草"
	_title_start_btn.art_texture = load("res://assets/ui/start_btn_text.png")
	_title_start_btn.cute_font = _cute_font
	_title_start_btn.anchor_left = 0.11
	_title_start_btn.anchor_right = 0.89
	_title_start_btn.anchor_top = 0.770
	_title_start_btn.anchor_bottom = 0.865
	_title_start_btn.offset_left = 0.0
	_title_start_btn.offset_right = 0.0
	_title_start_btn.offset_top = 0.0
	_title_start_btn.offset_bottom = 0.0
	_title_start_btn.pressed.connect(func() -> void: start_requested.emit())
	title_safe.add_child(_title_start_btn)

	# Optional Rewarded Video Start Buff Button (clearly separated below Start button)
	_title_ad_btn = RewardAdButton.new()
	_title_ad_btn.text = "看视频 · 开局冲刺+2×"
	_title_ad_btn.cute_font = _cute_font
	_title_ad_btn.font_size_override = 22
	_title_ad_btn.anchor_left = 0.14
	_title_ad_btn.anchor_right = 0.86
	_title_ad_btn.anchor_top = 0.890
	_title_ad_btn.anchor_bottom = 0.962
	_title_ad_btn.offset_left = 0.0
	_title_ad_btn.offset_right = 0.0
	_title_ad_btn.offset_top = 0.0
	_title_ad_btn.offset_bottom = 0.0
	_title_ad_btn.pressed.connect(func() -> void: start_ad_requested.emit())
	title_safe.add_child(_title_ad_btn)

func _build_gameover_overlay(root: Control) -> void:
	_gameover_overlay = ColorRect.new()
	_gameover_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameover_overlay.color = Color(0.08, 0.20, 0.06, 0.56)
	_gameover_overlay.visible = false
	root.add_child(_gameover_overlay)

	var go_safe := _make_safe_container(_gameover_overlay)

	# Clean, Airy Cartoon Settlement Card inside safe area!
	_go_card = GameOverCardWidget.new()
	_go_card.cute_font = _cute_font
	_go_card.harvest_title_tex = _tex_harvest_title
	_go_card.star_gold_tex = _tex_star_gold
	_go_card.star_empty_tex = _tex_star_empty
	_go_card.tex_grass = _tex_grass
	_go_card.tex_flower = _tex_flower
	_go_card.tex_crown = _tex_crown
	_go_card.star_landed.connect(func(idx: int) -> void: star_landed.emit(idx))
	_go_card.anchor_left = 0.08
	_go_card.anchor_right = 0.92
	_go_card.anchor_top = 0.075
	_go_card.anchor_bottom = 0.685
	_go_card.offset_left = 0.0
	_go_card.offset_right = 0.0
	_go_card.offset_top = 0.0
	_go_card.offset_bottom = 0.0
	go_safe.add_child(_go_card)

	# Rewarded Video Continue Button (+20s + Rainbow Boost, max 1x per round)
	_go_revive_btn = RewardAdButton.new()
	_go_revive_btn.text = "看视频 · 续时+20秒"
	_go_revive_btn.cute_font = _cute_font
	_go_revive_btn.font_size_override = 26
	_go_revive_btn.anchor_left = 0.11
	_go_revive_btn.anchor_right = 0.89
	_go_revive_btn.anchor_top = 0.716
	_go_revive_btn.anchor_bottom = 0.806
	_go_revive_btn.offset_left = 0.0
	_go_revive_btn.offset_right = 0.0
	_go_revive_btn.offset_top = 0.0
	_go_revive_btn.offset_bottom = 0.0
	_go_revive_btn.pressed.connect(func() -> void: revive_ad_requested.emit())
	go_safe.add_child(_go_revive_btn)

	# Clean Floating Action Row right below the card (safe bottom margin!)
	_go_home_btn = RoundBackButton.new()
	_go_home_btn.anchor_left = 0.11
	_go_home_btn.anchor_right = 0.27
	_go_home_btn.anchor_top = 0.834
	_go_home_btn.anchor_bottom = 0.926
	_go_home_btn.offset_left = 0.0
	_go_home_btn.offset_right = 0.0
	_go_home_btn.offset_top = 0.0
	_go_home_btn.offset_bottom = 0.0
	_go_home_btn.pressed.connect(func() -> void: home_requested.emit())
	go_safe.add_child(_go_home_btn)

	_go_retry_btn = GlossyStartButton.new()
	_go_retry_btn.text = "再来一局"
	_go_retry_btn.cute_font = _cute_font
	_go_retry_btn.font_size_override = 34
	_go_retry_btn.anchor_left = 0.30
	_go_retry_btn.anchor_right = 0.89
	_go_retry_btn.anchor_top = 0.832
	_go_retry_btn.anchor_bottom = 0.928
	_go_retry_btn.offset_left = 0.0
	_go_retry_btn.offset_right = 0.0
	_go_retry_btn.offset_top = 0.0
	_go_retry_btn.offset_bottom = 0.0
	_go_retry_btn.pressed.connect(func() -> void: restart_requested.emit())
	go_safe.add_child(_go_retry_btn)

func set_playing_ui_visible(vis: bool) -> void:
	_top_hud.visible = vis
	_minimap.visible = vis
	_hint_panel.visible = vis
	joystick.enabled = vis
	_update_sound_btn_pos(vis)
	if not vis:
		_fever_pill.visible = false
		_boost_pill.visible = false
		_status_pill.visible = false

func show_title(best_score: int) -> void:
	if _title_fade_tween != null and _title_fade_tween.is_valid():
		_title_fade_tween.kill()
	_title_best_badge.set_score(best_score)
	_title_best_badge.visible = best_score > 0
	_title_overlay.modulate.a = 1.0
	_title_overlay.visible = true
	if _title_start_btn != null:
		_title_start_btn.play_appear()
	_gameover_overlay.visible = false
	_top_hud.visible = false
	_minimap.visible = false
	_hint_panel.visible = false
	_fever_pill.visible = false
	_boost_pill.visible = false
	_status_pill.visible = false
	_update_sound_btn_pos(false)
	joystick.has_moved_once = false
	joystick.show_idle_ring = false
	joystick.enabled = false

func show_playing(from_home_drag: bool = false) -> void:
	if _title_fade_tween != null and _title_fade_tween.is_valid():
		_title_fade_tween.kill()
	_title_overlay.visible = false
	_title_overlay.modulate.a = 1.0
	_gameover_overlay.visible = false
	_top_hud.visible = true
	_minimap.visible = true
	_hint_panel.visible = not from_home_drag
	_update_sound_btn_pos(true)
	joystick.show_idle_ring = not from_home_drag
	if not from_home_drag:
		joystick.has_moved_once = false
	joystick.enabled = true

func show_gameover(score: int, area_ratio: float, sq_m: float, special_cells: int, flowers_count: int, best_score: int, is_new_record: bool, can_revive: bool = true) -> void:
	set_playing_ui_visible(false)
	_title_overlay.visible = false
	_gameover_overlay.visible = true
	_go_card.set_results(score, area_ratio, sq_m, special_cells, flowers_count, best_score, is_new_record)
	if _go_revive_btn != null:
		_go_revive_btn.visible = can_revive
		_go_revive_btn.set_loading(false)
		if can_revive:
			_go_home_btn.anchor_top = 0.834
			_go_home_btn.anchor_bottom = 0.926
			_go_retry_btn.anchor_top = 0.832
			_go_retry_btn.anchor_bottom = 0.928
		else:
			_go_home_btn.anchor_top = 0.746
			_go_home_btn.anchor_bottom = 0.840
			_go_retry_btn.anchor_top = 0.744
			_go_retry_btn.anchor_bottom = 0.842

func set_ad_buttons_loading(loading: bool) -> void:
	if _title_ad_btn != null:
		_title_ad_btn.set_loading(loading)
	if _go_revive_btn != null:
		_go_revive_btn.set_loading(loading)

func show_toast(msg: String, is_positive: bool = false) -> void:
	if _toast_banner != null:
		_toast_banner.show_message(msg, is_positive)

func update_hud(
	time_left: float,
	area_ratio: float,
	score: int,
	fever_time: float,
	fever_max: float,
	boost_time: float,
	boost_max: float,
	status_code: String
) -> void:
	_top_hud.set_values(area_ratio, time_left, score, fever_time > 0.0)

	if fever_time > 0.0:
		_fever_pill.visible = true
		_fever_pill.set_progress("2×  %.1fs" % fever_time, clampf(fever_time / maxf(fever_max, 0.1), 0.0, 1.0))
	else:
		_fever_pill.visible = false

	if boost_time > 0.0:
		_boost_pill.visible = true
		_boost_pill.set_progress("%.1fs" % boost_time, clampf(boost_time / maxf(boost_max, 0.1), 0.0, 1.0))
	else:
		_boost_pill.visible = false

	if status_code != "":
		_status_pill.visible = true
		_status_pill.set_status(status_code)
	else:
		_status_pill.visible = false

	if joystick.has_moved_once:
		_hint_panel.visible = false

func hide_touch_hint() -> void:
	if _hint_panel != null:
		_hint_panel.visible = false

func update_minimap(tex: Texture2D, field_size: Vector2, mower_pos: Vector2, mower_angle: float, flowers: Array, boosts: Array, animals: Array) -> void:
	_minimap.set_data(tex, field_size, mower_pos, mower_angle, flowers, boosts, animals)

func _make_pill_panel(bg: Color, border: Color, pad: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.65
	sb.content_margin_bottom = pad * 0.65
	p.add_theme_stylebox_override("panel", sb)
	return p

func _make_label(txt: String, sz: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, use_cute: bool = false) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = align
	if use_cute and _cute_font != null:
		l.add_theme_font_override("font", _cute_font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.14, 0.06, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	return l


# ==============================================================================
# SLEEK CARTOON TOP HUD STRIP (Compact 58px glossy cream & sunshine pills!)
# ==============================================================================
class TopHudWidget extends Control:
	var cute_font: Font = null
	var tex_grass: Texture2D = null
	var tex_clock: Texture2D = null
	var tex_star: Texture2D = null
	var _area: float = 0.0
	var _time_left: float = 60.0
	var _score: int = 0
	var _fever: bool = false
	var _score_pop: float = 0.0
	var _last_score: int = 0
	var _last_drawn_secs: int = -1
	var _last_drawn_area_milli: int = -1
	var _last_drawn_score: int = -1
	var _last_drawn_fever: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_values(area_ratio: float, time_left: float, score: int, fever_active: bool) -> void:
		if score > _last_score:
			_score_pop = 1.0
		_last_score = score
		_area = clampf(area_ratio, 0.0, 1.0)
		_time_left = maxf(time_left, 0.0)
		_score = score
		_fever = fever_active
		var secs := int(ceil(_time_left))
		var area_milli := int(round(_area * 1000.0))
		if secs != _last_drawn_secs or area_milli != _last_drawn_area_milli or _score != _last_drawn_score or _fever != _last_drawn_fever:
			_last_drawn_secs = secs
			_last_drawn_area_milli = area_milli
			_last_drawn_score = _score
			_last_drawn_fever = _fever
			queue_redraw()

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var need := false
		if _score_pop > 0.01:
			_score_pop = maxf(0.0, _score_pop - delta * 5.0)
			need = true
		if _time_left <= 10.0 or _fever:
			need = true
		if need:
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 120.0 or h < 30.0:
			return

		var t := Time.get_ticks_msec() * 0.001
		var font := cute_font if cute_font != null else ThemeDB.fallback_font
		var gap := 10.0
		var center_w := clampf(w * 0.25, 112.0, 136.0)
		var side_w := (w - center_w - gap * 2.0) * 0.5
		var pill_h := 48.0
		var py := (h - pill_h) * 0.5

		# 1. LEFT PILL: Mowed Area % + Real Glossy Grass Icon + Integrated Slim Green Progress Bar
		var left_rect := Rect2(0.0, py, side_w, pill_h)
		_draw_glossy_pill(left_rect, Color(0.99, 0.97, 0.87, 0.95), Color(0.28, 0.56, 0.14), Color(0.22, 0.44, 0.10))
		if tex_grass != null:
			draw_texture_rect(tex_grass, Rect2(left_rect.position.x + 8.0, left_rect.position.y + 4.0, 32.0, 32.0), false)
		var area_str := "%.1f%%" % (_area * 100.0)
		_draw_outlined_text(font, area_str, Vector2(left_rect.position.x + 38.0, left_rect.position.y + 29.0), left_rect.size.x - 46.0, 22, Color(0.18, 0.46, 0.12), Color(1.0, 0.99, 0.92, 0.85))
		# Slim progress bar inside lower rim of left pill
		var bar_r := Rect2(left_rect.position.x + 14.0, left_rect.end.y - 10.5, left_rect.size.x - 28.0, 6.0)
		_draw_capsule(bar_r, 3.0, Color(0.84, 0.88, 0.72))
		if _area > 0.005:
			var fill_w := maxf(6.0, bar_r.size.x * _area)
			_draw_capsule(Rect2(bar_r.position.x, bar_r.position.y, fill_w, bar_r.size.y), 3.0, Color(0.36, 0.82, 0.20))

		# 2. CENTER BADGE: Sunny Golden Clock Capsule + Real Glossy Clock Icon!
		var secs := int(ceil(_time_left))
		var urgent := secs <= 10 and _time_left > 0.0
		var center_h := 54.0
		var cy := (h - center_h) * 0.5
		var wobble_x := sin(t * 28.0) * 2.2 if urgent else 0.0
		var center_rect := Rect2(side_w + gap + wobble_x, cy, center_w, center_h)
		var c_bg := Color(1.0, 0.36, 0.28) if urgent else Color(1.0, 0.78, 0.16)
		var c_lip := Color(0.72, 0.14, 0.12) if urgent else Color(0.80, 0.44, 0.04)
		var c_border := Color(0.46, 0.08, 0.08) if urgent else Color(0.40, 0.21, 0.04)
		_draw_glossy_pill(center_rect, c_bg, c_border, c_lip)
		if tex_clock != null:
			draw_texture_rect(tex_clock, Rect2(center_rect.position.x + 8.0, center_rect.get_center().y - 17.0, 34.0, 34.0), false)
		var time_col := Color(1.0, 0.98, 0.90) if urgent else Color(0.28, 0.14, 0.03)
		var time_out := Color(0.45, 0.08, 0.06) if urgent else Color(1.0, 0.96, 0.74, 0.8)
		_draw_outlined_text(font, "%ds" % secs, Vector2(center_rect.position.x + 40.0, center_rect.get_center().y + 9.0), center_rect.size.x - 46.0, 26, time_col, time_out)

		# 3. RIGHT PILL: Score + Real Glossy Star Icon + Popping 2x Stamp!
		var right_rect := Rect2(side_w + center_w + gap * 2.0, py, side_w, pill_h)
		var r_border := Color(0.92, 0.52, 0.04) if _fever else Color(0.46, 0.27, 0.06)
		var r_lip := Color(0.86, 0.44, 0.02) if _fever else Color(0.78, 0.56, 0.18)
		_draw_glossy_pill(right_rect, Color(0.99, 0.96, 0.85, 0.95), r_border, r_lip)
		var star_sz := 32.0 * (1.0 + _score_pop * 0.16)
		if tex_star != null:
			var sc := Vector2(right_rect.position.x + 24.0, right_rect.get_center().y - 1.0)
			draw_texture_rect(tex_star, Rect2(sc.x - star_sz * 0.5, sc.y - star_sz * 0.5, star_sz, star_sz), false)
		var score_sz := int(24 + _score_pop * 3.0)
		_draw_outlined_text(font, "%d" % _score, Vector2(right_rect.position.x + 38.0, right_rect.get_center().y + 8.5), right_rect.size.x - 46.0, score_sz, Color(0.32, 0.16, 0.03), Color(1.0, 0.96, 0.78, 0.85))

		# Cute bouncing 2x stamp badge on right pill when double reward is active!
		if _fever:
			var bp := 1.0 + 0.08 * sin(t * 9.0)
			var bpos := Vector2(right_rect.end.x - 12.0, right_rect.position.y + 4.0)
			draw_circle(bpos, 14.5 * bp, Color(0.38, 0.18, 0.03))
			draw_circle(bpos, 12.2 * bp, Color(1.0, 0.36, 0.54))
			draw_string(font, bpos + Vector2(-11.0, 6.0), "2×", HORIZONTAL_ALIGNMENT_CENTER, 22.0, 15, Color(1.0, 0.98, 0.72))

	func _draw_glossy_pill(rect: Rect2, fill_col: Color, border_col: Color, lip_col: Color) -> void:
		var r := rect.size.y * 0.5
		# Soft shadow
		_draw_capsule(Rect2(rect.position.x + 2.0, rect.position.y + 5.0, rect.size.x - 4.0, rect.size.y), r, Color(0.06, 0.16, 0.04, 0.24))
		# 3D bottom lip
		_draw_capsule(Rect2(rect.position.x, rect.position.y + 3.0, rect.size.x, rect.size.y), r, lip_col)
		# Main capsule body
		_draw_capsule(rect, r, fill_col)
		# Upper glossy shine
		_draw_capsule(Rect2(rect.position.x + r * 0.45, rect.position.y + 3.0, rect.size.x - r * 0.9, rect.size.y * 0.26), rect.size.y * 0.13, Color(1.0, 1.0, 0.96, 0.48))
		# Crisp cartoon border
		_draw_capsule_outline(rect, r, border_col, 2.6)

	func _draw_outlined_text(font: Font, txt: String, pos: Vector2, max_w: float, sz: int, col: Color, glow_col: Color) -> void:
		draw_string(font, pos + Vector2(0.0, 1.5), txt, HORIZONTAL_ALIGNMENT_CENTER, max_w, sz, glow_col)
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, max_w, sz, col)

	func _draw_leaf_icon(c: Vector2, r: float) -> void:
		var pts := PackedVector2Array([
			c + Vector2(-r * 0.85, r * 0.55),
			c + Vector2(-r * 0.25, -r * 0.95),
			c + Vector2(r * 0.95, -r * 0.55),
			c + Vector2(r * 0.35, r * 0.85),
		])
		draw_colored_polygon(pts, Color(0.32, 0.80, 0.18))
		var out := pts.duplicate()
		out.append(pts[0])
		draw_polyline(out, Color(0.16, 0.38, 0.08), 2.0, true)
		draw_line(c + Vector2(-r * 0.55, r * 0.35), c + Vector2(r * 0.55, -r * 0.35), Color(0.76, 0.98, 0.52), 1.8, true)

	func _draw_clock_icon(c: Vector2, r: float, urgent: bool) -> void:
		var rim := Color(0.46, 0.08, 0.08) if urgent else Color(0.38, 0.20, 0.04)
		draw_circle(c, r + 1.8, rim)
		draw_circle(c, r, Color(1.0, 0.98, 0.90))
		draw_line(c, c + Vector2(0.0, -r * 0.58), rim, 2.2, true)
		draw_line(c, c + Vector2(r * 0.48, r * 0.16), Color(0.92, 0.26, 0.18), 2.0, true)
		draw_circle(c, 1.8, rim)

	func _draw_star_icon(c: Vector2, r: float, fill_col: Color, rim_col: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(10):
			var a := -PI * 0.5 + float(i) * (TAU / 10.0)
			var rad := r if i % 2 == 0 else r * 0.48
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, fill_col)
		var out := pts.duplicate()
		out.append(pts[0])
		draw_polyline(out, rim_col, 2.0, true)

	func _draw_capsule(rect: Rect2, radius: float, col: Color) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_circle(lc, r, col)
		draw_circle(rc, r, col)
		if rc.x > lc.x:
			draw_rect(Rect2(lc.x, rect.position.y, rc.x - lc.x, rect.size.y), col)

	func _draw_capsule_outline(rect: Rect2, radius: float, col: Color, width: float) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_arc(lc, r, PI * 0.5, PI * 1.5, 16, col, width, true)
		draw_arc(rc, r, -PI * 0.5, PI * 0.5, 16, col, width, true)
		draw_line(Vector2(lc.x, rect.position.y), Vector2(rc.x, rect.position.y), col, width, true)
		draw_line(Vector2(lc.x, rect.end.y), Vector2(rc.x, rect.end.y), col, width, true)


# ==============================================================================
# CARTOON GLOSSY BUFF PILL (2x Flower Fever & Rainbow Sprint Power-up)
# ==============================================================================
class BuffPillWidget extends Control:
	enum Style { FEVER, RAINBOW_BOOST }

	const RAINBOW := [
		Color(1.0, 0.28, 0.34),
		Color(1.0, 0.62, 0.14),
		Color(1.0, 0.90, 0.20),
		Color(0.32, 0.88, 0.38),
		Color(0.22, 0.84, 1.0),
		Color(0.70, 0.42, 1.0),
	]

	var _style: Style = Style.FEVER
	var _font: Font = null
	var _icon_tex: Texture2D = null
	var _text: String = ""
	var _ratio: float = 1.0

	func setup_style(st: Style, font: Font, icon_tex: Texture2D = null) -> void:
		_style = st
		_font = font
		_icon_tex = icon_tex
		custom_minimum_size = Vector2(154.0, 36.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_progress(txt: String, ratio: float) -> void:
		_text = txt
		_ratio = clampf(ratio, 0.0, 1.0)
		queue_redraw()

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var r := h * 0.5
		var font := _font if _font != null else ThemeDB.fallback_font

		var bg := Color(1.0, 0.94, 0.72, 0.95) if _style == Style.FEVER else Color(0.95, 0.98, 1.0, 0.95)
		var border := Color(0.86, 0.42, 0.08) if _style == Style.FEVER else Color(0.30, 0.18, 0.06)
		var lip := Color(0.90, 0.56, 0.10) if _style == Style.FEVER else Color(0.24, 0.70, 0.86)

		# Shadow + lip + capsule body
		_draw_capsule(Rect2(2.0, 4.0, w - 4.0, h), r, Color(0.08, 0.16, 0.04, 0.24))
		_draw_capsule(Rect2(0.0, 2.5, w, h), r, lip)
		_draw_capsule(Rect2(0.0, 0.0, w, h), r, bg)

		# Glossy progress fill along bottom half
		var bar_r := Rect2(16.0, h - 9.0, w - 32.0, 5.5)
		_draw_capsule(bar_r, 2.75, Color(0.86, 0.82, 0.70, 0.7))
		var fw := maxf(6.0, bar_r.size.x * _ratio)
		if _style == Style.FEVER:
			_draw_capsule(Rect2(bar_r.position.x, bar_r.position.y, fw, bar_r.size.y), 2.75, Color(1.0, 0.62, 0.12))
		else:
			# Mini rainbow segmented progress bar!
			var seg_w := fw / float(RAINBOW.size())
			for i in range(RAINBOW.size()):
				var sx := bar_r.position.x + float(i) * seg_w
				draw_rect(Rect2(sx, bar_r.position.y, seg_w + 0.5, bar_r.size.y), RAINBOW[i])

		# Crisp icon on left
		var ic := Vector2(20.0, h * 0.44)
		if _icon_tex != null:
			draw_texture_rect(_icon_tex, Rect2(ic.x - 13.0, ic.y - 13.0, 26.0, 26.0), false)
		else:
			var bolt := PackedVector2Array([
				ic + Vector2(1.5, -8.5),
				ic + Vector2(-5.5, 1.0),
				ic + Vector2(-0.5, 1.0),
				ic + Vector2(-2.5, 8.5),
				ic + Vector2(6.0, -1.2),
				ic + Vector2(1.0, -1.2),
			])
			draw_colored_polygon(bolt, Color(1.0, 0.56, 0.08))

		# Text (ultra concise: "2× 3.3s" or "3.4s")
		var txt_col := Color(0.46, 0.18, 0.04) if _style == Style.FEVER else Color(0.14, 0.34, 0.48)
		draw_string(font, Vector2(34.0, 22.0), _text, HORIZONTAL_ALIGNMENT_CENTER, w - 46.0, 18, txt_col)
		_draw_capsule_outline(Rect2(0.0, 0.0, w, h), r, border, 2.4)

	func _draw_capsule(rect: Rect2, radius: float, col: Color) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_circle(lc, r, col)
		draw_circle(rc, r, col)
		if rc.x > lc.x:
			draw_rect(Rect2(lc.x, rect.position.y, rc.x - lc.x, rect.size.y), col)

	func _draw_capsule_outline(rect: Rect2, radius: float, col: Color, width: float) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_arc(lc, r, PI * 0.5, PI * 1.5, 16, col, width, true)
		draw_arc(rc, r, -PI * 0.5, PI * 0.5, 16, col, width, true)
		draw_line(Vector2(lc.x, rect.position.y), Vector2(rc.x, rect.position.y), col, width, true)
		draw_line(Vector2(lc.x, rect.end.y), Vector2(rc.x, rect.end.y), col, width, true)


# ==============================================================================
# CUTE CARTOON INTERFERENCE FEEDBACK BUBBLE (Rock / Dog / Mud)
# ==============================================================================
class StatusComicPill extends Control:
	var cute_font: Font = null
	var _code: String = ""

	func _ready() -> void:
		custom_minimum_size = Vector2(114.0, 34.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_status(code: String) -> void:
		_code = code
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var r := h * 0.5
		var font := cute_font if cute_font != null else ThemeDB.fallback_font

		var msg := ""
		var bg := Color(1.0, 0.92, 0.86, 0.94)
		var border := Color(0.66, 0.24, 0.14)
		var ic_col := Color(0.95, 0.42, 0.22)
		match _code:
			"rock":
				msg = "减速"
				bg = Color(0.96, 0.94, 0.88, 0.95)
				border = Color(0.42, 0.38, 0.34)
				ic_col = Color(0.54, 0.56, 0.58)
			"dizzy":
				msg = "眩晕"
				bg = Color(1.0, 0.94, 0.80, 0.95)
				border = Color(0.76, 0.36, 0.08)
				ic_col = Color(1.0, 0.68, 0.12)
			"mud":
				msg = "打滑"
				bg = Color(0.96, 0.89, 0.80, 0.95)
				border = Color(0.46, 0.28, 0.14)
				ic_col = Color(0.48, 0.30, 0.16)

		_draw_capsule(Rect2(2.0, 3.5, w - 4.0, h), r, Color(0.08, 0.12, 0.04, 0.22))
		_draw_capsule(Rect2(0.0, 0.0, w, h), r, bg)
		# Distinct mini vector icon per status!
		var ic := Vector2(21.0, h * 0.5)
		if _code == "dizzy":
			var pts := PackedVector2Array()
			for i in range(10):
				var a := -PI * 0.5 + float(i) * (TAU / 10.0)
				pts.append(ic + Vector2(cos(a), sin(a)) * (9.0 if i % 2 == 0 else 4.2))
			draw_colored_polygon(pts, ic_col)
		elif _code == "mud":
			draw_circle(ic, 7.5, ic_col)
			draw_circle(ic + Vector2(-6.0, 4.0), 3.6, ic_col)
			draw_circle(ic + Vector2(6.5, -3.5), 3.2, ic_col)
		else:
			draw_colored_polygon(PackedVector2Array([
				ic + Vector2(-8, 4), ic + Vector2(-5, -6), ic + Vector2(4, -7), ic + Vector2(9, 2), ic + Vector2(3, 7)
			]), ic_col)
		draw_string(font, Vector2(34.0, h * 0.5 + 7.0), msg, HORIZONTAL_ALIGNMENT_CENTER, w - 44.0, 19, border)
		_draw_capsule_outline(Rect2(0.0, 0.0, w, h), r, border, 2.4)

	func _draw_capsule(rect: Rect2, radius: float, col: Color) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_circle(lc, r, col)
		draw_circle(rc, r, col)
		if rc.x > lc.x:
			draw_rect(Rect2(lc.x, rect.position.y, rc.x - lc.x, rect.size.y), col)

	func _draw_capsule_outline(rect: Rect2, radius: float, col: Color, width: float) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_arc(lc, r, PI * 0.5, PI * 1.5, 16, col, width, true)
		draw_arc(rc, r, -PI * 0.5, PI * 0.5, 16, col, width, true)
		draw_line(Vector2(lc.x, rect.position.y), Vector2(rc.x, rect.position.y), col, width, true)
		draw_line(Vector2(lc.x, rect.end.y), Vector2(rc.x, rect.end.y), col, width, true)


# ==============================================================================
# SUNNY CARTOON SETTLEMENT CARD (Matches《来割草 不烧心》Art Style!)
# ==============================================================================
class GameOverCardWidget extends Control:
	signal star_landed(star_idx: int)

	var cute_font: Font = null
	var harvest_title_tex: Texture2D = null
	var star_gold_tex: Texture2D = null
	var star_empty_tex: Texture2D = null
	var tex_grass: Texture2D = null
	var tex_flower: Texture2D = null
	var tex_crown: Texture2D = null

	var _score: int = 0
	var _area_ratio: float = 0.0
	var _sq_m: float = 0.0
	var _special_cells: int = 0
	var _flowers: int = 0
	var _best_score: int = 0
	var _is_new_record: bool = false
	var _stars: int = 2

	var _anim_elapsed: float = 0.0
	var _star_impacted: Array[bool] = [false, false, false]
	var _star_ring_t: Array[float] = [-1.0, -1.0, -1.0]
	var _sparkles: Array[Dictionary] = []

	func set_results(score: int, area_ratio: float, sq_m: float, special_cells: int, flowers_count: int, best_score: int, is_new_record: bool) -> void:
		_score = score
		_area_ratio = area_ratio
		_sq_m = sq_m
		_special_cells = special_cells
		_flowers = flowers_count
		_best_score = best_score
		_is_new_record = is_new_record
		_anim_elapsed = 0.0
		_star_impacted = [false, false, false]
		_star_ring_t = [-1.0, -1.0, -1.0]
		_sparkles.clear()

		var pct := area_ratio * 100.0
		if pct >= 62.0 or score >= 6200:
			_stars = 3
		elif pct >= 35.0 or score >= 3000:
			_stars = 2
		else:
			_stars = 1
		queue_redraw()

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_anim_elapsed += delta

		var cx := size.x * 0.5
		var star_y := size.y * 0.255
		var star_offsets: Array[Vector2] = [Vector2(-92.0, 12.0), Vector2(0.0, -10.0), Vector2(92.0, 12.0)]

		# Trigger sequential star landing impacts & sparkle bursts!
		for i in range(_stars):
			var start_delay := 0.22 + float(i) * 0.36
			var impact_time := start_delay + 0.16
			if not _star_impacted[i] and _anim_elapsed >= impact_time:
				_star_impacted[i] = true
				_star_ring_t[i] = 0.0
				star_landed.emit(i)
				_spawn_star_burst(Vector2(cx, star_y) + star_offsets[i], 14 if i < 2 else 20)

		for i in range(3):
			if _star_ring_t[i] >= 0.0:
				_star_ring_t[i] += delta * 2.4
				if _star_ring_t[i] >= 1.0:
					_star_ring_t[i] = -1.0

		var idx := _sparkles.size() - 1
		while idx >= 0:
			var sp: Dictionary = _sparkles[idx]
			sp["life"] = float(sp["life"]) - delta
			if float(sp["life"]) <= 0.0:
				_sparkles.remove_at(idx)
			else:
				sp["pos"] = Vector2(sp["pos"]) + Vector2(sp["vel"]) * delta
				sp["vel"] = Vector2(sp["vel"]) * maxf(0.0, 1.0 - delta * 3.8) + Vector2(0.0, 95.0 * delta)
			idx -= 1

		queue_redraw()

	func _spawn_star_burst(origin: Vector2, count: int) -> void:
		var cols := [Color(1.0, 0.92, 0.28), Color(1.0, 0.68, 0.12), Color(1.0, 1.0, 0.90), Color(1.0, 0.48, 0.66)]
		for k in range(count):
			var a := (TAU / float(count)) * float(k) + randf_range(-0.2, 0.2)
			var spd := randf_range(75.0, 195.0)
			_sparkles.append({
				"pos": origin,
				"vel": Vector2(cos(a), sin(a)) * spd + Vector2(0.0, -35.0),
				"col": cols[k % cols.size()],
				"size": randf_range(3.5, 7.2),
				"life": randf_range(0.45, 0.78),
				"max_life": 0.78,
			})

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 100.0 or h < 100.0:
			return

		var font := cute_font if cute_font != null else ThemeDB.fallback_font
		var cx := w * 0.5
		var t := Time.get_ticks_msec() * 0.001

		# 1. Soft ground shadow behind cartoon parchment panel
		_draw_rounded_rect(Rect2(6.0, 26.0, w - 12.0, h - 20.0), 30.0, Color(0.05, 0.14, 0.03, 0.36))

		# 2. Outer leafy-green 3D cartoon frame + warm wood lip
		_draw_rounded_rect(Rect2(0.0, 22.0, w, h - 22.0), 30.0, Color(0.24, 0.50, 0.10))
		_draw_rounded_rect(Rect2(0.0, 16.0, w, h - 22.0), 30.0, Color(0.40, 0.78, 0.18))
		_draw_rounded_rect_outline(Rect2(0.0, 16.0, w, h - 22.0), 30.0, Color(0.18, 0.36, 0.06), 4.0)

		# 3. Warm cream inner parchment panel
		var inner := Rect2(11.0, 27.0, w - 22.0, h - 44.0)
		_draw_rounded_rect(inner, 22.0, Color(1.0, 0.97, 0.87))
		_draw_rounded_rect_outline(inner, 22.0, Color(0.92, 0.82, 0.58), 2.5)

		# 4. Top Glossy Sunshine-Orange Ribbon Header with AI "割草大丰收" art lettering!
		var rib_w := w * 0.74
		var rib_h := 60.0
		var rib_r := Rect2(cx - rib_w * 0.5, -10.0, rib_w, rib_h)
		draw_colored_polygon(PackedVector2Array([
			Vector2(rib_r.position.x - 18.0, rib_r.position.y + 10.0),
			Vector2(rib_r.position.x + 14.0, rib_r.position.y + 10.0),
			Vector2(rib_r.position.x + 14.0, rib_r.end.y - 2.0),
			Vector2(rib_r.position.x - 18.0, rib_r.end.y - 2.0),
			Vector2(rib_r.position.x - 6.0, rib_r.get_center().y + 4.0),
		]), Color(0.84, 0.44, 0.04))
		draw_colored_polygon(PackedVector2Array([
			Vector2(rib_r.end.x + 18.0, rib_r.position.y + 10.0),
			Vector2(rib_r.end.x - 14.0, rib_r.position.y + 10.0),
			Vector2(rib_r.end.x - 14.0, rib_r.end.y - 2.0),
			Vector2(rib_r.end.x + 18.0, rib_r.end.y - 2.0),
			Vector2(rib_r.end.x + 6.0, rib_r.get_center().y + 4.0),
		]), Color(0.84, 0.44, 0.04))
		_draw_rounded_rect(Rect2(rib_r.position.x, rib_r.position.y + 4.0, rib_w, rib_h), 30.0, Color(0.80, 0.40, 0.02))
		_draw_rounded_rect(rib_r, 30.0, Color(1.0, 0.72, 0.12))
		_draw_rounded_rect(Rect2(rib_r.position.x + 10.0, rib_r.position.y + 4.0, rib_w - 20.0, rib_h * 0.34), 12.0, Color(1.0, 0.96, 0.72, 0.55))
		_draw_rounded_rect_outline(rib_r, 30.0, Color(0.38, 0.18, 0.03), 3.4)

		if harvest_title_tex != null:
			var tsz := harvest_title_tex.get_size()
			var max_tw := rib_w * 0.78
			var max_th := rib_h * 0.68
			var sc := minf(max_tw / maxf(tsz.x, 1.0), max_th / maxf(tsz.y, 1.0))
			var tw := tsz.x * sc
			var th := tsz.y * sc
			var tx := cx - tw * 0.5
			var ty := rib_r.position.y + (rib_h - th) * 0.5
			draw_texture_rect(harvest_title_tex, Rect2(tx, ty + 2.0, tw, th), false, Color(1.0, 0.96, 0.64, 0.35))
			draw_texture_rect(harvest_title_tex, Rect2(tx, ty, tw, th), false, Color.WHITE)
		else:
			draw_string(font, Vector2(rib_r.position.x, rib_r.position.y + 41.0), "割草大丰收", HORIZONTAL_ALIGNMENT_CENTER, rib_w, 30, Color(0.28, 0.13, 0.02))

		# 5. Three Big AI Cartoon Stars with Sequential Slam-In Rating Animation!
		var star_y := h * 0.255
		var star_offsets: Array[Vector2] = [Vector2(-92.0, 12.0), Vector2(0.0, -10.0), Vector2(92.0, 12.0)]
		var star_sizes: Array[float] = [84.0, 108.0, 84.0]
		var star_tilts: Array[float] = [-0.15, 0.0, 0.15]

		for i in range(3):
			var sc_pos: Vector2 = Vector2(cx, star_y) + star_offsets[i]
			var base_sz: float = star_sizes[i]
			var tilt: float = star_tilts[i]

			if star_empty_tex != null:
				draw_set_transform(sc_pos, tilt, Vector2.ONE)
				draw_texture_rect(star_empty_tex, Rect2(-base_sz * 0.5, -base_sz * 0.5, base_sz, base_sz), false, Color.WHITE)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

			if _star_ring_t[i] >= 0.0:
				var rt: float = _star_ring_t[i]
				var ring_r := base_sz * (0.35 + 0.55 * ease(rt, 0.35))
				var ring_a := clampf(1.0 - rt, 0.0, 1.0)
				draw_arc(sc_pos, ring_r, 0.0, TAU, 32, Color(1.0, 0.86, 0.20, ring_a * 0.85), 4.5 * ring_a, true)

			if i < _stars and star_gold_tex != null:
				var delay := 0.22 + float(i) * 0.36
				var lt := _anim_elapsed - delay
				if lt > 0.0:
					var star_scale := 1.0
					var star_alpha := 1.0
					var extra_rot := 0.0
					if lt < 0.16:
						var p := lt / 0.16
						star_scale = lerpf(2.45, 0.85, p * p)
						star_alpha = clampf(p * 2.5, 0.0, 1.0)
						extra_rot = lerpf(-0.42, 0.06, p)
					elif lt < 0.30:
						var p := (lt - 0.16) / 0.14
						star_scale = lerpf(0.85, 1.14, ease(p, 0.4))
						extra_rot = lerpf(0.06, -0.03, p)
					elif lt < 0.44:
						var p := (lt - 0.30) / 0.14
						star_scale = lerpf(1.14, 1.0, p)
						extra_rot = lerpf(-0.03, 0.0, p)
					else:
						star_scale = 1.0 + 0.025 * sin(t * 3.8 + float(i) * 1.1)

					var draw_sz := base_sz * star_scale
					draw_set_transform(sc_pos + Vector2(0.0, 4.0), tilt + extra_rot, Vector2.ONE)
					draw_texture_rect(star_gold_tex, Rect2(-draw_sz * 0.5, -draw_sz * 0.5, draw_sz, draw_sz), false, Color(0.32, 0.18, 0.02, 0.20 * star_alpha))
					draw_set_transform(sc_pos, tilt + extra_rot, Vector2.ONE)
					draw_texture_rect(star_gold_tex, Rect2(-draw_sz * 0.5, -draw_sz * 0.5, draw_sz, draw_sz), false, Color(1.0, 1.0, 1.0, star_alpha))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		for sp in _sparkles:
			var a := clampf(float(sp["life"]) / float(sp["max_life"]), 0.0, 1.0)
			var c: Color = sp["col"]
			c.a = a
			draw_circle(sp["pos"], float(sp["size"]) * (0.35 + 0.65 * a), c)

		# 6. Big Plump Rounded Score + Cute New Record Pill (Generous airy whitespace!)
		var score_y := h * 0.485
		var count_t := ease(clampf(_anim_elapsed / 0.85, 0.0, 1.0), 0.3)
		var shown_score := int(round(float(_score) * count_t))
		var score_str := "%d" % shown_score
		draw_string(font, Vector2(0.0, score_y + 20.0), score_str, HORIZONTAL_ALIGNMENT_CENTER, w, 62, Color(0.42, 0.18, 0.02, 0.22))
		draw_string(font, Vector2(0.0, score_y + 17.0), score_str, HORIZONTAL_ALIGNMENT_CENTER, w, 62, Color(0.96, 0.46, 0.04))

		if _is_new_record and _anim_elapsed >= 0.65:
			var np := 1.0 + 0.05 * sin(t * 7.0)
			var nr_w := 86.0 * np
			var nr_r := Rect2(cx - nr_w * 0.5, score_y + 26.0, nr_w, 26.0)
			_draw_rounded_rect(nr_r, 13.0, Color(1.0, 0.36, 0.32))
			_draw_rounded_rect_outline(nr_r, 13.0, Color(0.48, 0.10, 0.08), 2.2)
			draw_string(font, Vector2(nr_r.position.x, nr_r.position.y + 19.0), "NEW!", HORIZONTAL_ALIGNMENT_CENTER, nr_w, 16, Color(1.0, 0.98, 0.84))

		# 7. Three Clean, Airy Square Peach-Cream Reward Tiles (Just like reference Image 2!)
		var tile_gap := 14.0
		var pad_x := 28.0
		var tile_w := (w - pad_x * 2.0 - tile_gap * 2.0) / 3.0
		var tile_h := tile_w * 1.06
		var tile_y := h * 0.645

		var tiles := [
			{"tex": tex_grass, "val": "%.0f%%" % (_area_ratio * 100.0), "col": Color(0.20, 0.56, 0.12)},
			{"tex": tex_flower, "val": "×%d" % _flowers, "col": Color(0.88, 0.22, 0.50)},
			{"tex": tex_crown, "val": "%d" % _best_score, "col": Color(0.76, 0.38, 0.04)},
		]

		for i in range(3):
			var tx := pad_x + float(i) * (tile_w + tile_gap)
			var tr := Rect2(tx, tile_y, tile_w, tile_h)
			# Soft peach-beige tile card matching Image 2
			_draw_rounded_rect(Rect2(tr.position.x, tr.position.y + 3.0, tr.size.x, tr.size.y), 20.0, Color(0.88, 0.76, 0.58))
			_draw_rounded_rect(tr, 20.0, Color(0.98, 0.91, 0.78))
			_draw_rounded_rect_outline(tr, 20.0, Color(0.92, 0.80, 0.60), 2.0)

			var ic_tex: Texture2D = tiles[i]["tex"]
			if ic_tex != null:
				var ic_sz := tile_w * 0.62
				var ix := tr.get_center().x - ic_sz * 0.5
				var iy := tr.position.y + tile_h * 0.09
				draw_texture_rect(ic_tex, Rect2(ix, iy, ic_sz, ic_sz), false)

			# Crisp plump rounded value cleanly tucked at bottom of tile!
			var val_str: String = tiles[i]["val"]
			var val_col: Color = tiles[i]["col"]
			var v_sz := 23 if val_str.length() <= 4 else 19
			var vy := tr.end.y - 10.0
			draw_string(font, Vector2(tr.position.x, vy + 1.5), val_str, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, v_sz, Color(1.0, 0.98, 0.90))
			draw_string(font, Vector2(tr.position.x, vy), val_str, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, v_sz, val_col)

	func _draw_rounded_rect(rect: Rect2, radius: float, col: Color) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(radius))
		draw_style_box(sb, rect)

	func _draw_rounded_rect_outline(rect: Rect2, radius: float, col: Color, width: float) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = col
		sb.set_border_width_all(int(ceil(width)))
		sb.set_corner_radius_all(int(radius))
		draw_style_box(sb, rect)


# ==============================================================================
# START SCREEN GOLDEN CROWN HIGH-SCORE BADGE (Icon + Number, Zero Words!)
# ==============================================================================
class CrownScoreBadge extends Control:
	var cute_font: Font = null
	var tex_crown: Texture2D = null
	var _score: int = 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_score(val: int) -> void:
		_score = val
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 40.0 or h < 20.0:
			return
		var r := h * 0.5
		var font := cute_font if cute_font != null else ThemeDB.fallback_font

		# Soft shadow + green pill with warm golden border
		_draw_capsule(Rect2(2.0, 4.0, w - 4.0, h), r, Color(0.06, 0.16, 0.03, 0.30))
		_draw_capsule(Rect2(0.0, 0.0, w, h), r, Color(0.11, 0.28, 0.08, 0.86))
		_draw_capsule_outline(Rect2(0.0, 0.0, w, h), r, Color(1.0, 0.88, 0.36, 0.95), 3.0)

		# Real glossy AI golden crown icon on left!
		if tex_crown != null:
			var ic_sz := h * 0.78
			draw_texture_rect(tex_crown, Rect2(14.0, (h - ic_sz) * 0.5 - 1.0, ic_sz, ic_sz), false)

		# Big crisp plump rounded score number
		var txt := "%d" % _score
		draw_string(font, Vector2(56.0, h * 0.5 + 11.0), txt, HORIZONTAL_ALIGNMENT_CENTER, w - 72.0, 30, Color(1.0, 0.96, 0.72))

	func _draw_capsule(rect: Rect2, radius: float, col: Color) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_circle(lc, r, col)
		draw_circle(rc, r, col)
		if rc.x > lc.x:
			draw_rect(Rect2(lc.x, rect.position.y, rc.x - lc.x, rect.size.y), col)

	func _draw_capsule_outline(rect: Rect2, radius: float, col: Color, width: float) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_arc(lc, r, PI * 0.5, PI * 1.5, 16, col, width, true)
		draw_arc(rc, r, -PI * 0.5, PI * 0.5, 16, col, width, true)
		draw_line(Vector2(lc.x, rect.position.y), Vector2(rc.x, rect.position.y), col, width, true)
		draw_line(Vector2(lc.x, rect.end.y), Vector2(rc.x, rect.end.y), col, width, true)


# ==============================================================================
# GLOSSY CIRCULAR BACK / HOME BUTTON (Matches Reference Image 3 & 4!)
# ==============================================================================
class RoundBackButton extends Button:
	var _press_anim: float = 0.0

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		add_theme_stylebox_override("normal", empty)
		add_theme_stylebox_override("hover", empty)
		add_theme_stylebox_override("pressed", empty)
		add_theme_stylebox_override("focus", empty)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var target := 1.0 if is_pressed() else 0.0
		_press_anim = lerpf(_press_anim, target, minf(delta * 18.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.44
		var c := Vector2(size.x * 0.5, size.y * 0.5 - 2.0 + _press_anim * 3.5)
		# Soft shadow + 3D deep sky-blue lip
		draw_circle(c + Vector2(0.0, 7.0 - _press_anim * 2.5), r, Color(0.06, 0.16, 0.08, 0.30))
		draw_circle(c + Vector2(0.0, 4.5 - _press_anim * 3.0), r, Color(0.08, 0.44, 0.78))
		# Glossy sky-blue circle body
		draw_circle(c, r, Color(0.22, 0.72, 0.98))
		draw_circle(c + Vector2(0.0, -r * 0.14), r * 0.80, Color(0.42, 0.84, 1.0))
		draw_arc(c, r, 0.0, TAU, 32, Color(0.10, 0.40, 0.70), 2.8, true)
		# Jelly shine highlight on upper-left
		draw_circle(c + Vector2(-r * 0.38, -r * 0.38), r * 0.22, Color(1.0, 1.0, 1.0, 0.78))
		# Clean chunky white back arrow icon
		var s := r * 0.48
		var arrow := PackedVector2Array([
			c + Vector2(-s, 0.0),
			c + Vector2(-s * 0.05, -s * 0.82),
			c + Vector2(-s * 0.05, -s * 0.34),
			c + Vector2(s * 0.95, -s * 0.34),
			c + Vector2(s * 0.95, s * 0.34),
			c + Vector2(-s * 0.05, s * 0.34),
			c + Vector2(-s * 0.05, s * 0.82),
		])
		draw_colored_polygon(arrow, Color(1.0, 1.0, 0.96))


# ==============================================================================
# CARTOON MINIMAP (Warm wooden frame matching game aesthetic!)
# ==============================================================================
class MinimapWidget extends Control:
	var _tex: Texture2D = null
	var _field_size: Vector2 = Vector2(1024, 1536)
	var _mower_pos: Vector2 = Vector2.ZERO
	var _mower_angle: float = 0.0
	var _flowers: Array = []
	var _boosts: Array = []
	var _animals: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_data(tex: Texture2D, fsize: Vector2, mpos: Vector2, mang: float, flowers: Array, boosts: Array, animals: Array) -> void:
		_tex = tex
		_field_size = fsize
		_mower_pos = mpos
		_mower_angle = mang
		_flowers = flowers
		_boosts = boosts
		_animals = animals
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		# Warm wooden frame + shadow
		draw_rect(rect.grow(5.5), Color(0.22, 0.13, 0.04, 0.90))
		draw_rect(rect.grow(3.0), Color(0.96, 0.84, 0.54, 0.95))
		if _tex != null:
			draw_texture_rect(_tex, rect, false)

		var sx := size.x / maxf(_field_size.x, 1.0)
		var sy := size.y / maxf(_field_size.y, 1.0)

		for a in _animals:
			if is_instance_valid(a):
				var p := Vector2(a.global_position.x * sx, a.global_position.y * sy)
				draw_circle(p, 2.6, a.get_minimap_color())

		var pulse := 3.2 + 1.2 * sin(Time.get_ticks_msec() * 0.01)
		for fl in _flowers:
			if is_instance_valid(fl):
				var p := Vector2(fl.global_position.x * sx, fl.global_position.y * sy)
				draw_circle(p, pulse, Color(1.0, 0.92, 0.22, 0.95))

		for bp in _boosts:
			if is_instance_valid(bp):
				var p := Vector2(bp.global_position.x * sx, bp.global_position.y * sy)
				draw_circle(p, pulse, Color(0.28, 0.92, 1.0, 0.98))

		var mp := Vector2(_mower_pos.x * sx, _mower_pos.y * sy)
		draw_circle(mp, 4.6, Color(1.0, 0.22, 0.18))
		draw_arc(mp, 4.8, 0.0, TAU, 16, Color.WHITE, 1.5, true)
		var tip := mp + Vector2.from_angle(_mower_angle) * 6.5
		draw_line(mp, tip, Color.WHITE, 1.8, true)

		draw_rect(rect, Color(0.36, 0.20, 0.05, 0.95), false, 2.0)


# ==============================================================================
# GLOSSY JELLY CAPSULE BUTTON (Supports either AI art texture or cute font text!)
# ==============================================================================
class GlossyStartButton extends Button:
	var art_texture: Texture2D = null
	var cute_font: Font = null
	var font_size_override: int = 38
	var _press_anim: float = 0.0
	var _appear_t: float = 0.0

	func play_appear() -> void:
		_appear_t = 0.0

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		add_theme_stylebox_override("normal", empty)
		add_theme_stylebox_override("hover", empty)
		add_theme_stylebox_override("pressed", empty)
		add_theme_stylebox_override("focus", empty)
		add_theme_color_override("font_color", Color(0, 0, 0, 0))
		add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
		add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_appear_t = minf(1.0, _appear_t + delta * 3.8)
		var target := 1.0 if is_pressed() else 0.0
		_press_anim = lerpf(_press_anim, target, minf(delta * 18.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 10.0 or h < 10.0:
			return

		var t := Time.get_ticks_msec() * 0.001
		var pop_in := 1.0
		if _appear_t < 1.0:
			if _appear_t < 0.65:
				pop_in = lerpf(0.72, 1.06, ease(_appear_t / 0.65, 0.35))
			else:
				pop_in = lerpf(1.06, 1.0, (_appear_t - 0.65) / 0.35)
		var breathe := pop_in * (1.0 + 0.012 * sin(t * 3.0) * (1.0 - _press_anim))
		var cx := w * 0.5
		var cy := h * 0.5
		var bw := w * breathe
		var bh := (h - 8.0) * breathe
		var x0 := cx - bw * 0.5
		var y0 := cy - bh * 0.5 - 3.0 + _press_anim * 4.0
		var r := bh * 0.5

		# Soft drop shadow
		_draw_capsule(Rect2(x0 + 10.0, y0 + 9.0 - _press_anim * 3.0, bw - 20.0, bh - 2.0), r - 1.0, Color(0.18, 0.34, 0.04, 0.30))
		# 3D bottom lip
		var lip_offset := 5.5 - _press_anim * 3.5
		_draw_capsule(Rect2(x0, y0 + lip_offset, bw, bh), r, Color(0.84, 0.44, 0.02))
		# Warm orange-gold jelly body
		_draw_capsule(Rect2(x0, y0, bw, bh), r, Color(1.0, 0.62, 0.02))
		_draw_capsule(Rect2(x0 + 2.0, y0 + 1.5, bw - 4.0, bh * 0.82), r * 0.86, Color(1.0, 0.76, 0.10))
		_draw_capsule(Rect2(x0 + 4.0, y0 + 2.5, bw - 8.0, bh * 0.56), r * 0.64, Color(1.0, 0.88, 0.28))
		_draw_capsule_outline(Rect2(x0, y0, bw, bh), r, Color(0.92, 0.54, 0.05, 0.65), 2.2)

		# Top glossy sheen & left jelly highlights
		_draw_capsule(Rect2(x0 + r * 0.55, y0 + 4.0, bw - r * 1.1, bh * 0.18), bh * 0.09, Color(1.0, 0.99, 0.84, 0.58))
		draw_set_transform(Vector2(x0 + r * 0.58, y0 + r * 0.42), -0.42, Vector2(1.45, 0.62))
		draw_circle(Vector2.ZERO, r * 0.26, Color(1.0, 1.0, 0.95, 0.86))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2(x0 + r * 0.30, y0 + r * 0.76), r * 0.09, Color(1.0, 1.0, 0.95, 0.78))
		draw_set_transform(Vector2(x0 + bw - r * 0.55, y0 + r * 0.42), 0.42, Vector2(1.2, 0.5))
		draw_circle(Vector2.ZERO, r * 0.20, Color(1.0, 0.99, 0.86, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Either AI glossy art lettering OR cute_font text
		if art_texture != null:
			var tex_sz := art_texture.get_size()
			var max_tw := bw * 0.62
			var max_th := bh * 0.64
			var s := minf(max_tw / maxf(tex_sz.x, 1.0), max_th / maxf(tex_sz.y, 1.0))
			var tw := tex_sz.x * s
			var th := tex_sz.y * s
			var tx := cx - tw * 0.5
			var ty := y0 + (bh - th) * 0.5 - 1.0
			draw_texture_rect(art_texture, Rect2(tx, ty + 2.0, tw, th), false, Color(1.0, 0.96, 0.64, 0.35))
			draw_texture_rect(art_texture, Rect2(tx, ty, tw, th), false, Color.WHITE)
		else:
			var font := cute_font if cute_font != null else ThemeDB.fallback_font
			var ty := y0 + bh * 0.5 + float(font_size_override) * 0.34
			draw_string(font, Vector2(x0, ty + 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, bw, font_size_override, Color(1.0, 0.96, 0.68, 0.65))
			draw_string(font, Vector2(x0, ty), text, HORIZONTAL_ALIGNMENT_CENTER, bw, font_size_override, Color(0.26, 0.13, 0.02))

	func _draw_capsule(rect: Rect2, radius: float, col: Color) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_circle(lc, r, col)
		draw_circle(rc, r, col)
		if rc.x > lc.x:
			draw_rect(Rect2(lc.x, rect.position.y, rc.x - lc.x, rect.size.y), col)

	func _draw_capsule_outline(rect: Rect2, radius: float, col: Color, width: float) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_arc(lc, r, PI * 0.5, PI * 1.5, 20, col, width, true)
		draw_arc(rc, r, -PI * 0.5, PI * 0.5, 20, col, width, true)
		draw_line(Vector2(lc.x, rect.position.y), Vector2(rc.x, rect.position.y), col, width, true)
		draw_line(Vector2(lc.x, rect.end.y), Vector2(rc.x, rect.end.y), col, width, true)

class HomeDragCue extends Control:
	var cute_font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 20.0 or h < 20.0:
			return
		var t := Time.get_ticks_msec() * 0.001
		var cx := w * 0.5
		var ring_y := h * 0.42
		var track_rx := 52.0
		var ring_r := 32.0

		# Soft figure-8 / horizontal glide path showing "drag to steer"
		var glide := sin(t * 2.5)
		var knob_pos := Vector2(cx + glide * track_rx, ring_y + sin(t * 5.0) * 6.5)

		# Subtle dotted arc track
		for i in range(9):
			var u := -1.0 + float(i) * 0.25
			var px := cx + u * track_rx
			var py := ring_y + sin(u * PI) * 5.0
			draw_circle(Vector2(px, py), 3.4, Color(1.0, 0.98, 0.86, 0.42))

		# Outer pulsing joystick halo
		var pulse := 1.0 + 0.06 * sin(t * 4.2)
		draw_circle(Vector2(cx, ring_y), ring_r * pulse, Color(0.10, 0.22, 0.06, 0.22))
		draw_arc(Vector2(cx, ring_y), ring_r * pulse, 0.0, TAU, 36, Color(1.0, 0.98, 0.88, 0.65), 3.0, true)

		# Gliding glossy golden thumb knob
		draw_circle(knob_pos + Vector2(0.0, 4.0), 22.0, Color(0.12, 0.24, 0.04, 0.30))
		draw_circle(knob_pos, 22.0, Color(0.36, 0.19, 0.04))
		draw_circle(knob_pos, 18.8, Color(1.0, 0.72, 0.10))
		draw_circle(knob_pos + Vector2(0.0, -2.0), 14.5, Color(1.0, 0.88, 0.30))
		draw_circle(knob_pos + Vector2(-5.0, -6.0), 4.6, Color(1.0, 1.0, 0.94, 0.86))

		# Ultra-concise cartoon pill label underneath: "拖动开始"
		var pill_w := 134.0
		var pill_h := 34.0
		var px0 := cx - pill_w * 0.5
		var py0 := ring_y + 44.0
		var pr := pill_h * 0.5
		_draw_pill(Rect2(px0, py0 + 3.0, pill_w, pill_h), pr, Color(0.10, 0.24, 0.05, 0.28))
		_draw_pill(Rect2(px0, py0, pill_w, pill_h), pr, Color(1.0, 0.97, 0.86, 0.94))
		_draw_pill_outline(Rect2(px0, py0, pill_w, pill_h), pr, Color(0.38, 0.22, 0.06, 0.92), 2.8)
		var font := cute_font if cute_font != null else ThemeDB.fallback_font
		draw_string(font, Vector2(px0, py0 + pill_h * 0.5 + 7.5), "拖动开始", HORIZONTAL_ALIGNMENT_CENTER, pill_w, 20, Color(0.30, 0.16, 0.04))

	func _draw_pill(rect: Rect2, r: float, col: Color) -> void:
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_circle(lc, r, col)
		draw_circle(rc, r, col)
		if rc.x > lc.x:
			draw_rect(Rect2(lc.x, rect.position.y, rc.x - lc.x, rect.size.y), col)

	func _draw_pill_outline(rect: Rect2, r: float, col: Color, width: float) -> void:
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_arc(lc, r, PI * 0.5, PI * 1.5, 16, col, width, true)
		draw_arc(rc, r, -PI * 0.5, PI * 0.5, 16, col, width, true)
		draw_line(Vector2(lc.x, rect.position.y), Vector2(rc.x, rect.position.y), col, width, true)
		draw_line(Vector2(lc.x, rect.end.y), Vector2(rc.x, rect.end.y), col, width, true)

class SoundToggleButton extends Button:
	var is_muted: bool = false
	var _press_anim: float = 0.0

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		add_theme_stylebox_override("normal", empty)
		add_theme_stylebox_override("hover", empty)
		add_theme_stylebox_override("pressed", empty)
		add_theme_stylebox_override("focus", empty)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var target := 1.0 if is_pressed() else 0.0
		var next_val := lerpf(_press_anim, target, minf(delta * 18.0, 1.0))
		if absf(next_val - _press_anim) > 0.002:
			_press_anim = next_val
			queue_redraw()

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5 - 2.0
		if r < 6.0:
			return
		var s := r / 23.0
		var c := size * 0.5 + Vector2(0.0, _press_anim * 2.5)
		# Cartoon cream-gold badge (larger, clearer touch target!)
		draw_circle(c + Vector2(0.0, 4.0 - _press_anim * 2.0), r, Color(0.14, 0.28, 0.05, 0.34))
		draw_circle(c, r, Color(0.36, 0.20, 0.05))
		draw_circle(c, r - 3.0 * s, Color(1.0, 0.96, 0.84) if not is_muted else Color(0.88, 0.86, 0.80))
		draw_circle(c + Vector2(-r * 0.30, -r * 0.32), r * 0.20, Color(1.0, 1.0, 0.96, 0.72))

		var ink := Color(0.32, 0.17, 0.04) if not is_muted else Color(0.55, 0.45, 0.38)
		# Bold scaled speaker cone
		var cone := PackedVector2Array([
			c + Vector2(-10.5, -4.8) * s,
			c + Vector2(-4.6, -4.8) * s,
			c + Vector2(2.6, -10.5) * s,
			c + Vector2(2.6, 10.5) * s,
			c + Vector2(-4.6, 4.8) * s,
			c + Vector2(-10.5, 4.8) * s,
		])
		draw_colored_polygon(cone, ink)
		if is_muted:
			draw_line(c + Vector2(5.5, -5.8) * s, c + Vector2(13.0, 5.8) * s, Color(0.88, 0.24, 0.20), 3.2 * s, false)
			draw_line(c + Vector2(13.0, -5.8) * s, c + Vector2(5.5, 5.8) * s, Color(0.88, 0.24, 0.20), 3.2 * s, false)
		else:
			draw_arc(c + Vector2(3.6, 0.0) * s, 6.8 * s, -0.72, 0.72, 10, Color(0.24, 0.66, 0.16), 2.8 * s, false)
			draw_arc(c + Vector2(3.6, 0.0) * s, 11.2 * s, -0.78, 0.78, 12, Color(0.24, 0.66, 0.16), 2.6 * s, false)


# ==============================================================================
# GLOSSY REWARDED VIDEO AD BUTTON (Fresh Meadow-Emerald Pill + Video Play Badge)
# ==============================================================================
class RewardAdButton extends Button:
	var cute_font: Font = null
	var font_size_override: int = 24
	var _press_anim: float = 0.0
	var _is_loading: bool = false

	func set_loading(loading: bool) -> void:
		_is_loading = loading
		disabled = loading
		queue_redraw()

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		add_theme_stylebox_override("normal", empty)
		add_theme_stylebox_override("hover", empty)
		add_theme_stylebox_override("pressed", empty)
		add_theme_stylebox_override("disabled", empty)
		add_theme_stylebox_override("focus", empty)
		add_theme_color_override("font_color", Color(0, 0, 0, 0))
		add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
		add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
		add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0))

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var target := 1.0 if (is_pressed() and not disabled) else 0.0
		var next_val := lerpf(_press_anim, target, minf(delta * 18.0, 1.0))
		if absf(next_val - _press_anim) > 0.002:
			_press_anim = next_val
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 40.0 or h < 20.0:
			return

		var bw := w
		var bh := h - 6.0
		var x0 := 0.0
		var y0 := 1.0 + _press_anim * 3.5
		var r := bh * 0.5

		# Soft drop shadow + 3D deep emerald lip
		_draw_capsule(Rect2(x0 + 8.0, y0 + 7.5 - _press_anim * 2.5, bw - 16.0, bh - 2.0), r - 1.0, Color(0.05, 0.20, 0.08, 0.30))
		var lip_offset := 4.8 - _press_anim * 3.0
		var lip_col := Color(0.07, 0.42, 0.20) if not _is_loading else Color(0.28, 0.38, 0.32)
		var base_col := Color(0.11, 0.66, 0.32) if not _is_loading else Color(0.42, 0.56, 0.46)
		var mid_col := Color(0.18, 0.78, 0.40) if not _is_loading else Color(0.48, 0.62, 0.52)
		var top_col := Color(0.32, 0.88, 0.52) if not _is_loading else Color(0.56, 0.68, 0.60)
		_draw_capsule(Rect2(x0, y0 + lip_offset, bw, bh), r, lip_col)
		_draw_capsule(Rect2(x0, y0, bw, bh), r, base_col)
		_draw_capsule(Rect2(x0 + 2.0, y0 + 1.5, bw - 4.0, bh * 0.80), r * 0.86, mid_col)
		_draw_capsule(Rect2(x0 + 4.0, y0 + 2.5, bw - 8.0, bh * 0.52), r * 0.62, top_col)
		_draw_capsule_outline(Rect2(x0, y0, bw, bh), r, Color(0.06, 0.36, 0.16, 0.85), 2.4)

		# Glossy top highlight
		_draw_capsule(Rect2(x0 + r * 0.55, y0 + 3.5, bw - r * 1.1, bh * 0.16), bh * 0.08, Color(0.92, 1.0, 0.94, 0.45))

		# Clean circular glossy video-play badge on the left
		var badge_rad := clampf(bh * 0.34, 14.0, 20.0)
		var bc := Vector2(x0 + clampf(r * 0.78, 22.0, 32.0) + badge_rad * 0.35, y0 + bh * 0.5)
		draw_circle(bc + Vector2(0.0, 1.8), badge_rad + 1.4, Color(0.06, 0.34, 0.14, 0.45))
		draw_circle(bc, badge_rad, Color(1.0, 0.97, 0.84))
		draw_arc(bc, badge_rad, 0.0, TAU, 24, Color(0.08, 0.44, 0.18, 0.70), 1.8, false)
		# Crisp play triangle inside video badge
		var ts := badge_rad * 0.48
		var tc := bc + Vector2(1.4, 0.0)
		var tri := PackedVector2Array([
			tc + Vector2(-ts * 0.72, -ts),
			tc + Vector2(-ts * 0.72, ts),
			tc + Vector2(ts * 1.05, 0.0),
		])
		draw_colored_polygon(tri, Color(0.09, 0.56, 0.24))

		# Crisp outlined label clearly stating reward rule
		var font := cute_font if cute_font != null else ThemeDB.fallback_font
		var label_txt := "广告加载中..." if _is_loading else text
		var text_left := bc.x + badge_rad + 8.0
		var text_w := bw - text_left - 16.0
		var fsz := int(clampf(float(font_size_override), 16.0, bh * 0.44))
		var ty := y0 + bh * 0.5 + float(fsz) * 0.35
		draw_string(font, Vector2(text_left, ty + 2.0), label_txt, HORIZONTAL_ALIGNMENT_CENTER, text_w, fsz, Color(0.05, 0.28, 0.12, 0.85))
		draw_string(font, Vector2(text_left, ty), label_txt, HORIZONTAL_ALIGNMENT_CENTER, text_w, fsz, Color(1.0, 0.99, 0.92))

	func _draw_capsule(rect: Rect2, radius: float, col: Color) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_circle(lc, r, col)
		draw_circle(rc, r, col)
		if rc.x > lc.x:
			draw_rect(Rect2(lc.x, rect.position.y, rc.x - lc.x, rect.size.y), col)

	func _draw_capsule_outline(rect: Rect2, radius: float, col: Color, width: float) -> void:
		var r := minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
		var lc := Vector2(rect.position.x + r, rect.position.y + rect.size.y * 0.5)
		var rc := Vector2(rect.end.x - r, rect.position.y + rect.size.y * 0.5)
		draw_arc(lc, r, PI * 0.5, PI * 1.5, 16, col, width, false)
		draw_arc(rc, r, -PI * 0.5, PI * 0.5, 16, col, width, false)
		draw_line(Vector2(lc.x, rect.position.y), Vector2(rc.x, rect.position.y), col, width, false)
		draw_line(Vector2(lc.x, rect.end.y), Vector2(rc.x, rect.end.y), col, width, false)


# ==============================================================================
# LIGHTWEIGHT NON-BLOCKING TOAST BANNER (Ad status & reward confirmation)
# ==============================================================================
class ToastBanner extends Control:
	var cute_font: Font = null
	var _msg: String = ""
	var _is_positive: bool = false
	var _timer: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_message(msg: String, is_positive: bool = false) -> void:
		_msg = msg
		_is_positive = is_positive
		_timer = 2.4
		modulate.a = 1.0
		visible = true
		queue_redraw()

	func _process(delta: float) -> void:
		if not visible:
			return
		_timer -= delta
		if _timer <= 0.0:
			visible = false
			return
		if _timer < 0.45:
			modulate.a = clampf(_timer / 0.45, 0.0, 1.0)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 40.0 or h < 20.0 or _msg == "":
			return
		var r := h * 0.5
		var bg := Color(0.10, 0.52, 0.22, 0.94) if _is_positive else Color(0.24, 0.16, 0.07, 0.92)
		var border := Color(0.94, 0.98, 0.72, 0.95) if _is_positive else Color(1.0, 0.84, 0.42, 0.92)
		var lc := Vector2(r, h * 0.5)
		var rc := Vector2(w - r, h * 0.5)
		draw_circle(lc + Vector2(0.0, 3.0), r, Color(0.0, 0.0, 0.0, 0.24))
		draw_circle(rc + Vector2(0.0, 3.0), r, Color(0.0, 0.0, 0.0, 0.24))
		if rc.x > lc.x:
			draw_rect(Rect2(lc.x, 3.0, rc.x - lc.x, h), Color(0.0, 0.0, 0.0, 0.24))
		draw_circle(lc, r, bg)
		draw_circle(rc, r, bg)
		if rc.x > lc.x:
			draw_rect(Rect2(lc.x, 0.0, rc.x - lc.x, h), bg)
		draw_arc(lc, r, PI * 0.5, PI * 1.5, 14, border, 2.5, false)
		draw_arc(rc, r, -PI * 0.5, PI * 0.5, 14, border, 2.5, false)
		draw_line(Vector2(lc.x, 0.0), Vector2(rc.x, 0.0), border, 2.5, false)
		draw_line(Vector2(lc.x, h), Vector2(rc.x, h), border, 2.5, false)
		var font := cute_font if cute_font != null else ThemeDB.fallback_font
		draw_string(font, Vector2(14.0, h * 0.5 + 7.5), _msg, HORIZONTAL_ALIGNMENT_CENTER, w - 28.0, 20, Color(1.0, 0.99, 0.92))
