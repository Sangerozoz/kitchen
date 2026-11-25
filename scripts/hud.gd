extends CanvasLayer
class_name GameHUD

signal start_requested()
signal restart_requested()
signal boost_pressed_changed(pressed: bool)

var joystick: ThumbJoystick

var _top_bar: Control
var _area_value_lbl: Label
var _area_bar: ProgressBar
var _timer_lbl: Label
var _timer_panel: PanelContainer
var _score_lbl: Label
var _mult_badge: Label

var _fever_bar_panel: PanelContainer
var _fever_lbl: Label
var _fever_bar: ProgressBar

var _status_panel: PanelContainer
var _status_lbl: Label
var _hint_lbl: Label

var _minimap: MinimapWidget
var _boost_btn: BoostButtonWidget

var _title_overlay: Control
var _title_best_lbl: Label

var _gameover_overlay: Control
var _go_grade_lbl: Label
var _go_score_lbl: Label
var _go_area_lbl: Label
var _go_special_lbl: Label
var _go_best_lbl: Label
var _go_new_record_lbl: Label

func _ready() -> void:
	layer = 20
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Virtual joystick layer (below buttons & overlays)
	joystick = ThumbJoystick.new()
	root.add_child(joystick)

	# --- TOP HUD BAR (Mobile Portrait Safe Area) ---
	_top_bar = Control.new()
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_top = 14.0
	_top_bar.offset_bottom = 104.0
	_top_bar.offset_left = 12.0
	_top_bar.offset_right = -12.0
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top_bar)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(hbox)

	# Left card: Area %
	var area_panel := _make_pill_panel(Color(0.08, 0.18, 0.10, 0.84), Color(0.45, 0.82, 0.34, 0.75))
	area_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area_panel.size_flags_stretch_ratio = 1.15
	hbox.add_child(area_panel)

	var area_vb := VBoxContainer.new()
	area_vb.add_theme_constant_override("separation", 3)
	area_panel.add_child(area_vb)

	var area_title := _make_label("割草面积", 12, Color(0.76, 0.94, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	area_vb.add_child(area_title)
	_area_value_lbl = _make_label("0.0%", 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	area_vb.add_child(_area_value_lbl)
	_area_bar = _make_progress_bar(Color(0.16, 0.30, 0.16), Color(0.46, 0.88, 0.30), 8.0)
	area_vb.add_child(_area_bar)

	# Center card: Countdown Timer
	_timer_panel = _make_pill_panel(Color(0.10, 0.18, 0.12, 0.90), Color(0.96, 0.84, 0.32, 0.85))
	_timer_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_panel.size_flags_stretch_ratio = 0.88
	hbox.add_child(_timer_panel)

	var timer_vb := VBoxContainer.new()
	timer_vb.add_theme_constant_override("separation", 0)
	timer_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_timer_panel.add_child(timer_vb)
	timer_vb.add_child(_make_label("倒计时", 12, Color(0.95, 0.90, 0.65), HORIZONTAL_ALIGNMENT_CENTER))
	_timer_lbl = _make_label("60s", 28, Color(1.0, 0.96, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	timer_vb.add_child(_timer_lbl)

	# Right card: Score & Multiplier
	var score_panel := _make_pill_panel(Color(0.08, 0.18, 0.10, 0.84), Color(1.0, 0.78, 0.24, 0.75))
	score_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_panel.size_flags_stretch_ratio = 1.15
	hbox.add_child(score_panel)

	var score_vb := VBoxContainer.new()
	score_vb.add_theme_constant_override("separation", 2)
	score_panel.add_child(score_vb)

	var score_top := HBoxContainer.new()
	score_top.alignment = BoxContainer.ALIGNMENT_CENTER
	score_top.add_theme_constant_override("separation", 5)
	score_vb.add_child(score_top)
	score_top.add_child(_make_label("得分", 12, Color(0.98, 0.88, 0.60), HORIZONTAL_ALIGNMENT_CENTER))
	_mult_badge = _make_label("2×翻倍!", 12, Color(1.0, 0.88, 0.18), HORIZONTAL_ALIGNMENT_CENTER)
	_mult_badge.visible = false
	score_top.add_child(_mult_badge)

	_score_lbl = _make_label("0", 24, Color(1.0, 0.95, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	score_vb.add_child(_score_lbl)

	# --- 2X FEVER BANNER (below top bar) ---
	_fever_bar_panel = _make_pill_panel(Color(0.32, 0.20, 0.04, 0.92), Color(1.0, 0.84, 0.18, 0.95))
	_fever_bar_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_fever_bar_panel.offset_top = 112.0
	_fever_bar_panel.offset_bottom = 154.0
	_fever_bar_panel.offset_left = -140.0
	_fever_bar_panel.offset_right = 140.0
	_fever_bar_panel.visible = false
	_fever_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fever_bar_panel)

	var fvb := VBoxContainer.new()
	fvb.add_theme_constant_override("separation", 4)
	_fever_bar_panel.add_child(fvb)
	_fever_lbl = _make_label("★ 双倍收割奖励 2× (6.0s) ★", 14, Color(1.0, 0.94, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	fvb.add_child(_fever_lbl)
	_fever_bar = _make_progress_bar(Color(0.24, 0.14, 0.04), Color(1.0, 0.82, 0.14), 6.0)
	fvb.add_child(_fever_bar)

	# --- STATUS ALERT BANNER (animal/rock effect) ---
	_status_panel = _make_pill_panel(Color(0.34, 0.10, 0.10, 0.90), Color(1.0, 0.45, 0.35, 0.9))
	_status_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_panel.offset_top = 160.0
	_status_panel.offset_bottom = 194.0
	_status_panel.offset_left = -135.0
	_status_panel.offset_right = 135.0
	_status_panel.visible = false
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_status_panel)

	_status_lbl = _make_label("", 15, Color(1.0, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_status_panel.add_child(_status_lbl)

	# --- BOTTOM-LEFT MINIMAP ---
	_minimap = MinimapWidget.new()
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_minimap.offset_left = 14.0
	_minimap.offset_right = 104.0
	_minimap.offset_top = -152.0
	_minimap.offset_bottom = -18.0
	root.add_child(_minimap)

	# --- BOTTOM-RIGHT BOOST BUTTON ---
	_boost_btn = BoostButtonWidget.new()
	_boost_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_boost_btn.offset_left = -114.0
	_boost_btn.offset_right = -16.0
	_boost_btn.offset_top = -124.0
	_boost_btn.offset_bottom = -26.0
	_boost_btn.pressed_changed.connect(func(p: bool) -> void: boost_pressed_changed.emit(p))
	root.add_child(_boost_btn)

	# --- SUBTLE MOBILE TOUCH HINT ---
	_hint_lbl = _make_label("按住屏幕任意位置拖动摇杆割草", 15, Color(1.0, 1.0, 1.0, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	_hint_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_lbl.offset_top = -224.0
	_hint_lbl.offset_bottom = -196.0
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_lbl)

	_build_title_overlay(root)
	_build_gameover_overlay(root)
	set_playing_ui_visible(false)

func _build_title_overlay(root: Control) -> void:
	_title_overlay = ColorRect.new()
	_title_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_overlay.color = Color(0.05, 0.14, 0.07, 0.62)
	root.add_child(_title_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_overlay.add_child(center)

	var card := _make_pill_panel(Color(0.09, 0.21, 0.12, 0.95), Color(0.56, 0.90, 0.36, 0.92), 22)
	card.custom_minimum_size = Vector2(440, 0)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	vb.add_child(_make_label("阳光割草大作战", 36, Color(1.0, 0.94, 0.42), HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(_make_label("60秒限时竖屏割草挑战", 16, Color(0.76, 0.96, 0.72), HORIZONTAL_ALIGNMENT_CENTER))

	var info_panel := _make_pill_panel(Color(0.06, 0.14, 0.08, 0.85), Color(0.32, 0.56, 0.28, 0.6), 14)
	vb.add_child(info_panel)
	var ivb := VBoxContainer.new()
	ivb.add_theme_constant_override("separation", 10)
	info_panel.add_child(ivb)

	ivb.add_child(_make_rule_label("● 滑动摇杆驾驶割草机，尽量割除更大面积草地", Color(0.88, 0.98, 0.84)))
	ivb.add_child(_make_rule_label("★ 特殊彩草 & 随机花朵：收割奖励直接翻倍 (2×)!", Color(1.0, 0.88, 0.34)))
	ivb.add_child(_make_rule_label("▲ 石头会震停刀片，树木会阻挡路线，注意绕行", Color(0.86, 0.88, 0.90)))
	ivb.add_child(_make_rule_label("◆ 绵羊顶撞 / 小狗眩晕 / 小猪泥巴打滑会干扰操控", Color(1.0, 0.68, 0.62)))
	ivb.add_child(_make_rule_label("» 按住右下角加速键冲刺，扩大割草宽度！", Color(0.60, 0.92, 1.0)))

	_title_best_lbl = _make_label("最高纪录：0 分", 16, Color(0.95, 0.92, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(_title_best_lbl)

	var start_btn := _make_action_button("开始割草", Color(0.24, 0.72, 0.26), Color(0.32, 0.84, 0.34))
	start_btn.pressed.connect(func() -> void: start_requested.emit())
	vb.add_child(start_btn)

func _build_gameover_overlay(root: Control) -> void:
	_gameover_overlay = ColorRect.new()
	_gameover_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameover_overlay.color = Color(0.04, 0.10, 0.06, 0.72)
	_gameover_overlay.visible = false
	root.add_child(_gameover_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameover_overlay.add_child(center)

	var card := _make_pill_panel(Color(0.09, 0.20, 0.12, 0.96), Color(1.0, 0.82, 0.26, 0.95), 22)
	card.custom_minimum_size = Vector2(430, 0)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	vb.add_child(_make_label("时间到！割草结算", 30, Color(1.0, 0.95, 0.62), HORIZONTAL_ALIGNMENT_CENTER))
	_go_grade_lbl = _make_label("S", 58, Color(1.0, 0.84, 0.16), HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(_go_grade_lbl)

	_go_new_record_lbl = _make_label("★ 刷新最高纪录！★", 17, Color(1.0, 0.56, 0.28), HORIZONTAL_ALIGNMENT_CENTER)
	_go_new_record_lbl.visible = false
	vb.add_child(_go_new_record_lbl)

	var stats_box := _make_pill_panel(Color(0.06, 0.13, 0.08, 0.88), Color(0.36, 0.64, 0.30, 0.65), 14)
	vb.add_child(stats_box)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 8)
	stats_box.add_child(svb)

	_go_score_lbl = _make_label("最终得分：0", 22, Color(1.0, 0.94, 0.50), HORIZONTAL_ALIGNMENT_CENTER)
	_go_area_lbl = _make_label("割草面积：0.0% (0.0 m²)", 18, Color(0.68, 0.96, 0.58), HORIZONTAL_ALIGNMENT_CENTER)
	_go_special_lbl = _make_label("彩草收割：0 格  |  幸运花朵：0 朵", 15, Color(1.0, 0.78, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	_go_best_lbl = _make_label("历史最高：0 分", 15, Color(0.84, 0.90, 0.84), HORIZONTAL_ALIGNMENT_CENTER)
	svb.add_child(_go_score_lbl)
	svb.add_child(_go_area_lbl)
	svb.add_child(_go_special_lbl)
	svb.add_child(_go_best_lbl)

	var retry_btn := _make_action_button("再来一局", Color(0.24, 0.72, 0.26), Color(0.32, 0.84, 0.34))
	retry_btn.pressed.connect(func() -> void: restart_requested.emit())
	vb.add_child(retry_btn)

func _process(_delta: float) -> void:
	if _boost_btn != null and joystick != null:
		joystick.excluded_rect = _boost_btn.get_global_rect().grow(18.0)

func set_playing_ui_visible(vis: bool) -> void:
	_top_bar.visible = vis
	_minimap.visible = vis
	_boost_btn.visible = vis
	_hint_lbl.visible = vis
	joystick.enabled = vis
	if not vis:
		_fever_bar_panel.visible = false
		_status_panel.visible = false

func show_title(best_score: int) -> void:
	_title_best_lbl.text = "历史最高纪录：%d 分" % best_score
	_title_overlay.visible = true
	_gameover_overlay.visible = false
	set_playing_ui_visible(false)

func show_playing() -> void:
	_title_overlay.visible = false
	_gameover_overlay.visible = false
	joystick.has_moved_once = false
	set_playing_ui_visible(true)

func show_gameover(score: int, area_ratio: float, sq_m: float, special_cells: int, flowers_count: int, best_score: int, is_new_record: bool) -> void:
	set_playing_ui_visible(false)
	_title_overlay.visible = false
	_gameover_overlay.visible = true

	var pct := area_ratio * 100.0
	var grade := "C"
	var grade_col := Color(0.76, 0.84, 0.78)
	if pct >= 82.0 or score >= 9500:
		grade = "S+"
		grade_col = Color(1.0, 0.84, 0.14)
	elif pct >= 66.0 or score >= 7000:
		grade = "S"
		grade_col = Color(1.0, 0.72, 0.22)
	elif pct >= 50.0 or score >= 4800:
		grade = "A"
		grade_col = Color(0.45, 0.94, 0.45)
	elif pct >= 34.0 or score >= 2800:
		grade = "B"
		grade_col = Color(0.46, 0.84, 1.0)

	_go_grade_lbl.text = grade
	_go_grade_lbl.add_theme_color_override("font_color", grade_col)
	_go_new_record_lbl.visible = is_new_record
	_go_score_lbl.text = "最终得分：%d" % score
	_go_area_lbl.text = "割草面积：%.1f%% (%.1f m²)" % [pct, sq_m]
	_go_special_lbl.text = "彩草收割：%d 格  |  幸运花朵：%d 朵" % [special_cells, flowers_count]
	_go_best_lbl.text = "历史最高：%d 分" % best_score

func update_hud(
	time_left: float,
	area_ratio: float,
	score: int,
	fever_time: float,
	fever_max: float,
	boost_energy: float,
	is_boosting: bool,
	status_code: String
) -> void:
	_area_value_lbl.text = "%.1f%%" % (area_ratio * 100.0)
	_area_bar.value = area_ratio * 100.0

	var secs := int(ceil(maxf(time_left, 0.0)))
	_timer_lbl.text = "%ds" % secs
	if secs <= 10:
		var urgent_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.32 + 0.3 * urgent_pulse, 0.25))
	else:
		_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72))

	_score_lbl.text = "%d" % score
	_mult_badge.visible = fever_time > 0.0

	if fever_time > 0.0:
		_fever_bar_panel.visible = true
		_fever_lbl.text = "★ 双倍收割奖励 2× (%.1fs) ★" % fever_time
		_fever_bar.value = clampf(fever_time / maxf(fever_max, 0.1), 0.0, 1.0) * 100.0
	else:
		_fever_bar_panel.visible = false

	match status_code:
		"rock":
			_status_panel.visible = true
			_status_lbl.text = "▲ 撞到石头！刀片短暂减速"
		"dizzy":
			_status_panel.visible = true
			_status_lbl.text = "◆ 小狗捣乱！转向短暂眩晕"
		"mud":
			_status_panel.visible = true
			_status_lbl.text = "◆ 踩到泥巴！车身打滑漂移"
		_:
			_status_panel.visible = false

	_boost_btn.set_state(boost_energy, is_boosting)
	if joystick.has_moved_once:
		_hint_lbl.visible = false

func hide_touch_hint() -> void:
	if _hint_lbl != null:
		_hint_lbl.visible = false

func update_minimap(tex: Texture2D, field_size: Vector2, mower_pos: Vector2, mower_angle: float, flowers: Array, animals: Array) -> void:
	_minimap.set_data(tex, field_size, mower_pos, mower_angle, flowers, animals)

func _make_pill_panel(bg: Color, border: Color, pad: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.75
	sb.content_margin_bottom = pad * 0.75
	p.add_theme_stylebox_override("panel", sb)
	return p

func _make_label(txt: String, sz: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.04, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	return l

func _make_rule_label(txt: String, col: Color) -> Label:
	var l := _make_label(txt, 15, col, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _make_progress_bar(bg_col: Color, fill_col: Color, h: float) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_col
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fill)
	return pb

func _make_action_button(txt: String, col: Color, hover_col: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = col
	normal.border_color = Color(0.84, 1.0, 0.72, 0.9)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(18)

	var hover := normal.duplicate()
	hover.bg_color = hover_col

	var pressed := normal.duplicate()
	pressed.bg_color = col.darkened(0.18)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	return b


class MinimapWidget extends Control:
	var _tex: Texture2D = null
	var _field_size: Vector2 = Vector2(1024, 1536)
	var _mower_pos: Vector2 = Vector2.ZERO
	var _mower_angle: float = 0.0
	var _flowers: Array = []
	var _animals: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_data(tex: Texture2D, fsize: Vector2, mpos: Vector2, mang: float, flowers: Array, animals: Array) -> void:
		_tex = tex
		_field_size = fsize
		_mower_pos = mpos
		_mower_angle = mang
		_flowers = flowers
		_animals = animals
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect.grow(3.0), Color(0.06, 0.14, 0.08, 0.88))
		if _tex != null:
			draw_texture_rect(_tex, rect, false)

		var sx := size.x / maxf(_field_size.x, 1.0)
		var sy := size.y / maxf(_field_size.y, 1.0)

		# Animals
		for a in _animals:
			if is_instance_valid(a):
				var p := Vector2(a.global_position.x * sx, a.global_position.y * sy)
				draw_circle(p, 2.6, a.get_minimap_color())

		# Pulsing flowers
		var pulse := 3.2 + 1.2 * sin(Time.get_ticks_msec() * 0.01)
		for fl in _flowers:
			if is_instance_valid(fl):
				var p := Vector2(fl.global_position.x * sx, fl.global_position.y * sy)
				draw_circle(p, pulse, Color(1.0, 0.92, 0.22, 0.95))

		# Player mower indicator
		var mp := Vector2(_mower_pos.x * sx, _mower_pos.y * sy)
		draw_circle(mp, 4.6, Color(1.0, 0.22, 0.18))
		draw_arc(mp, 4.8, 0.0, TAU, 16, Color.WHITE, 1.5, true)
		var tip := mp + Vector2.from_angle(_mower_angle) * 6.5
		draw_line(mp, tip, Color.WHITE, 1.8, true)

		# Border frame
		draw_rect(rect, Color(0.75, 0.95, 0.65, 0.8), false, 2.0)


class BoostButtonWidget extends Control:
	signal pressed_changed(pressed: bool)

	var _energy: float = 1.0
	var _boosting: bool = false
	var _touch_idx: int = -1
	var _pressed: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(energy: float, boosting: bool) -> void:
		_energy = energy
		_boosting = boosting
		queue_redraw()

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			if _pressed:
				_pressed = false
				_touch_idx = -1
				pressed_changed.emit(false)
			return
		var center := get_global_rect().get_center()
		var hit_r := size.x * 0.56
		if event is InputEventScreenTouch:
			var ev := event as InputEventScreenTouch
			if ev.pressed:
				if _touch_idx == -1 and ev.position.distance_to(center) <= hit_r:
					_touch_idx = ev.index
					_pressed = true
					pressed_changed.emit(true)
					queue_redraw()
			else:
				if ev.index == _touch_idx:
					_touch_idx = -1
					_pressed = false
					pressed_changed.emit(false)
					queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.44
		var bg := Color(0.95, 0.42, 0.12, 0.92) if _boosting else (Color(0.96, 0.62, 0.14, 0.88) if _energy >= 0.28 else Color(0.32, 0.36, 0.34, 0.78))
		if _pressed:
			r *= 0.94

		# Outer backing & radial energy ring
		draw_circle(c, r + 5.0, Color(0.08, 0.14, 0.08, 0.72))
		draw_arc(c, r + 2.5, -PI * 0.5, -PI * 0.5 + TAU * _energy, 36, Color(1.0, 0.92, 0.26, 0.95), 5.0, true)
		draw_circle(c, r - 2.0, bg)
		draw_arc(c, r - 2.0, 0.0, TAU, 32, Color(1.0, 0.96, 0.78, 0.85), 2.4, true)

		# Lightning bolt icon
		var bolt := PackedVector2Array([
			c + Vector2(3, -20),
			c + Vector2(-11, 2),
			c + Vector2(-1, 2),
			c + Vector2(-5, 20),
			c + Vector2(12, -3),
			c + Vector2(2, -3),
		])
		draw_colored_polygon(bolt, Color(1.0, 0.98, 0.86))
