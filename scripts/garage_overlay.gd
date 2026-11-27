extends Control
class_name GarageOverlay

signal closed()
signal stat_upgrade_clicked(stat_key: String)
signal mower_buy_clicked(mower_id: String)
signal mower_equip_clicked(mower_id: String)
signal mower_skill_upgrade_clicked(mower_id: String)
signal mower_trial_ad_clicked(mower_id: String)
signal free_coins_ad_clicked()

var cute_font: Font = null
var _progress: ProgressManager = null
var _active_tab: int = 0 # 0 = 基础升级, 1 = 割草机 & 技能
var _selected_mower: String = "classic"

var _safe_box: Control
var _coins_lbl: Label
var _tab_stats_btn: Button
var _tab_mowers_btn: Button
var _content_box: VBoxContainer
var _ad_coins_btn: Button

var _tex_coin: Texture2D
var _tex_stat_icons: Dictionary = {}
var _tex_skill_icons: Dictionary = {}
var _tex_mowers: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_load_textures()
	_build_ui()

func _load_textures() -> void:
	_tex_coin = load("res://assets/sprites/icon_coin.png")
	_tex_stat_icons = {
		"blade": load("res://assets/sprites/skill_whirlwind.png"),
		"engine": load("res://assets/sprites/skill_speed.png"),
		"chassis": load("res://assets/sprites/skill_smash.png"),
		"greed": _tex_coin,
	}
	_tex_skill_icons = {
		"classic": load("res://assets/sprites/skill_speed.png"),
		"volt": load("res://assets/sprites/skill_shield.png"),
		"crusher": load("res://assets/sprites/skill_smash.png"),
		"cyclone": load("res://assets/sprites/skill_whirlwind.png"),
		"rainbow": load("res://assets/sprites/pickup_boost.png"),
	}
	for m_raw in ProgressManager.MOWER_ORDER:
		var m_id: String = String(m_raw)
		_tex_mowers[m_id] = load("res://assets/sprites/mower_%s.png" % m_id)

func set_safe_insets(top: float, bottom: float, left: float, right: float) -> void:
	if _safe_box != null:
		_safe_box.offset_top = top
		_safe_box.offset_bottom = -bottom
		_safe_box.offset_left = left
		_safe_box.offset_right = -right

func open_with_progress(prog: ProgressManager, initial_tab: int = 1) -> void:
	_progress = prog
	_active_tab = initial_tab
	_selected_mower = prog.equipped_mower
	visible = true
	refresh()

func set_ad_loading(loading: bool) -> void:
	if _ad_coins_btn != null:
		_ad_coins_btn.disabled = loading

func refresh() -> void:
	if _progress == null or not is_instance_valid(_content_box):
		return
	_coins_lbl.text = "%d" % _progress.coins
	_style_tab_button(_tab_stats_btn, _active_tab == 0)
	_style_tab_button(_tab_mowers_btn, _active_tab == 1)

	for ch in _content_box.get_children():
		ch.queue_free()

	if _active_tab == 0:
		_build_stats_tab()
	else:
		_build_mowers_showcase_tab()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.14, 0.04, 0.76)
	add_child(dim)

	_safe_box = Control.new()
	_safe_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_box)

	# Outer glossy cartoon green-framed parchment frame
	var panel := PanelContainer.new()
	panel.anchor_left = 0.03
	panel.anchor_right = 0.97
	panel.anchor_top = 0.035
	panel.anchor_bottom = 0.945
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(1.0, 0.97, 0.88)
	psb.border_color = Color(0.24, 0.56, 0.14)
	psb.set_border_width_all(6)
	psb.set_corner_radius_all(28)
	psb.shadow_color = Color(0.04, 0.12, 0.02, 0.35)
	psb.shadow_size = 12
	psb.content_margin_left = 14
	psb.content_margin_right = 14
	psb.content_margin_top = 12
	psb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", psb)
	_safe_box.add_child(panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 10)
	panel.add_child(root_v)

	# Header Row: Title + Glossy Coin Pill (with real coin icon!) + Free Ad Coins + Close X
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 7)
	root_v.add_child(hdr)

	var title_lbl := _make_lbl("割草机车库", 23, Color(0.28, 0.14, 0.03), false)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title_lbl)

	var coin_pill := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(1.0, 0.90, 0.38)
	csb.border_color = Color(0.46, 0.24, 0.04)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(18)
	csb.content_margin_left = 8
	csb.content_margin_right = 12
	csb.content_margin_top = 3
	csb.content_margin_bottom = 3
	coin_pill.add_theme_stylebox_override("panel", csb)
	var coin_h := HBoxContainer.new()
	coin_h.add_theme_constant_override("separation", 5)
	coin_pill.add_child(coin_h)
	if _tex_coin != null:
		var c_ic := TextureRect.new()
		c_ic.texture = _tex_coin
		c_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c_ic.custom_minimum_size = Vector2(26, 26)
		coin_h.add_child(c_ic)
	_coins_lbl = _make_lbl("0", 18, Color(0.32, 0.15, 0.02), false)
	coin_h.add_child(_coins_lbl)
	hdr.add_child(coin_pill)

	_ad_coins_btn = _make_3d_btn("+150", Color(0.14, 0.74, 0.34), Color(0.06, 0.44, 0.18), Color.WHITE, 16)
	_ad_coins_btn.custom_minimum_size = Vector2(68, 38)
	_ad_coins_btn.pressed.connect(func() -> void: free_coins_ad_clicked.emit())
	hdr.add_child(_ad_coins_btn)

	var close_btn := _make_3d_btn("×", Color(0.94, 0.32, 0.26), Color(0.56, 0.10, 0.08), Color.WHITE, 22)
	close_btn.custom_minimum_size = Vector2(38, 38)
	close_btn.pressed.connect(func() -> void:
		visible = false
		closed.emit()
	)
	hdr.add_child(close_btn)

	# Tab Selector Row (Mowers Showcase tab first or Stats tab)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	root_v.add_child(tab_row)

	_tab_mowers_btn = _make_3d_btn("割草机 & 技能", Color(1.0, 0.76, 0.16), Color(0.76, 0.42, 0.02), Color(0.26, 0.12, 0.02), 18)
	_tab_mowers_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_mowers_btn.custom_minimum_size = Vector2(0, 44)
	_tab_mowers_btn.pressed.connect(func() -> void:
		_active_tab = 1
		refresh()
	)
	tab_row.add_child(_tab_mowers_btn)

	_tab_stats_btn = _make_3d_btn("基础升级 (Lv.30)", Color(0.92, 0.87, 0.74), Color(0.68, 0.56, 0.36), Color(0.46, 0.34, 0.18), 18)
	_tab_stats_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_stats_btn.custom_minimum_size = Vector2(0, 44)
	_tab_stats_btn.pressed.connect(func() -> void:
		_active_tab = 0
		refresh()
	)
	tab_row.add_child(_tab_stats_btn)

	# Scrollable Content Container
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_v.add_child(scroll)

	_content_box = VBoxContainer.new()
	_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_content_box)

func _build_stats_tab() -> void:
	for k_raw in ProgressManager.STAT_KEYS:
		var k: String = String(k_raw)
		var meta: Dictionary = ProgressManager.STAT_META[k]
		var lv := _progress.get_stat_level(k)
		var cost := _progress.get_stat_cost(k)
		var maxed := lv >= ProgressManager.MAX_STAT_LEVEL
		var afford := not maxed and _progress.coins >= cost

		var card := _make_card_panel(Color(0.99, 0.94, 0.82), Color(0.84, 0.70, 0.44))
		var outer_v := VBoxContainer.new()
		outer_v.add_theme_constant_override("separation", 6)
		card.add_child(outer_v)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		outer_v.add_child(row)

		# Real glossy illustrated RPG emblem icon!
		var ic := TextureRect.new()
		ic.texture = _tex_stat_icons.get(k, null)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(60, 60)
		row.add_child(ic)

		# Info column
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)

		var top_line := HBoxContainer.new()
		top_line.add_theme_constant_override("separation", 8)
		info.add_child(top_line)
		top_line.add_child(_make_lbl(String(meta["name"]), 20, Color(0.26, 0.13, 0.02), false))
		top_line.add_child(_make_lbl("Lv.%d/%d" % [lv, ProgressManager.MAX_STAT_LEVEL], 16, Color(0.16, 0.56, 0.14), false))

		info.add_child(_make_lbl(_progress.get_stat_summary(k), 16, Color(0.38, 0.22, 0.06), false))
		info.add_child(_make_lbl(_progress.get_next_milestone_hint(k), 14, Color(0.74, 0.36, 0.04), false))

		# 3D glossy upgrade button
		var btn_txt := "已满级" if maxed else ("升级\n%d金" % cost)
		var bg := Color(0.22, 0.74, 0.32) if maxed else (Color(1.0, 0.72, 0.10) if afford else Color(0.84, 0.78, 0.68))
		var lip := Color(0.10, 0.44, 0.16) if maxed else (Color(0.76, 0.38, 0.02) if afford else Color(0.62, 0.54, 0.44))
		var fc := Color.WHITE if maxed else (Color(0.26, 0.12, 0.02) if afford else Color(0.48, 0.40, 0.32))
		var btn := _make_3d_btn(btn_txt, bg, lip, fc, 16)
		btn.custom_minimum_size = Vector2(96, 58)
		btn.disabled = maxed or not afford
		var stat_k: String = k
		btn.pressed.connect(func() -> void: stat_upgrade_clicked.emit(stat_k))
		row.add_child(btn)

		# 30-level visual milestone progress bar (with Lv.10 / Lv.20 / Lv.30 gems!)
		var pbar := StatMilestoneBar.new()
		pbar.level = lv
		pbar.max_level = ProgressManager.MAX_STAT_LEVEL
		pbar.fill_col = meta["accent"]
		pbar.custom_minimum_size = Vector2(0, 16)
		outer_v.add_child(pbar)

		_content_box.add_child(card)

	# Helpful Milestone Legend Card at bottom of Stats tab
	var tip_card := _make_card_panel(Color(0.95, 0.99, 0.86), Color(0.46, 0.72, 0.28))
	var tip_lbl := _make_lbl("小贴士：每项基础属性最高可升至 Lv.30，达 Lv.10 / Lv.20 / Lv.30 均会自动解锁强力质变特性，所有割草机通用生效！", 14, Color(0.20, 0.44, 0.12), true)
	tip_card.add_child(tip_lbl)
	_content_box.add_child(tip_card)

func _build_mowers_showcase_tab() -> void:
	if not ProgressManager.MOWER_DEFS.has(_selected_mower):
		_selected_mower = _progress.equipped_mower
	var m_id := _selected_mower
	var def: Dictionary = ProgressManager.MOWER_DEFS[m_id]
	var unlocked := _progress.is_mower_unlocked(m_id)
	var equipped: bool = (_progress.equipped_mower == m_id)
	var price := _progress.get_mower_price(m_id)
	var sk_lv := _progress.get_skill_level(m_id)
	var sk_cost := _progress.get_skill_cost(m_id)
	var sk_maxed := sk_lv >= ProgressManager.MAX_SKILL_LEVEL

	# 1. HERO SHOWCASE TURNTABLE STAGE (Big illustrated mower + animated skill aura!)
	var stage := MowerShowcaseStage.new()
	stage.cute_font = cute_font
	stage.mower_id = m_id
	stage.mower_name = String(def["name"])
	stage.bonus_desc = String(def["bonus_desc"])
	stage.status_tag = "使用中" if equipped else ("已拥有" if unlocked else "未解锁")
	stage.is_unlocked = unlocked
	stage.mower_tex = _tex_mowers.get(m_id, null)
	stage.custom_minimum_size = Vector2(0, 248)
	_content_box.add_child(stage)

	# 2. HORIZONTAL 5-MOWER SELECTOR STRIP
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 6)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_box.add_child(strip)

	for raw_id in ProgressManager.MOWER_ORDER:
		var cid: String = String(raw_id)
		var c_un := _progress.is_mower_unlocked(cid)
		var c_eq: bool = (_progress.equipped_mower == cid)
		var c_sel: bool = (cid == m_id)
		var slot := MowerThumbButton.new()
		slot.mower_tex = _tex_mowers.get(cid, null)
		slot.is_selected = c_sel
		slot.is_unlocked = c_un
		slot.is_equipped = c_eq
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size = Vector2(0, 68)
		slot.pressed.connect(func() -> void:
			_selected_mower = cid
			refresh()
		)
		strip.add_child(slot)

	# 3. DEDICATED SKILL & UPGRADE PANEL
	var sk_card := _make_card_panel(Color(0.99, 0.94, 0.82), Color(0.84, 0.70, 0.44))
	var sk_v := VBoxContainer.new()
	sk_v.add_theme_constant_override("separation", 8)
	sk_card.add_child(sk_v)

	var sk_top := HBoxContainer.new()
	sk_top.add_theme_constant_override("separation", 10)
	sk_v.add_child(sk_top)

	var sk_ic := TextureRect.new()
	sk_ic.texture = _tex_skill_icons.get(m_id, null)
	sk_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sk_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sk_ic.custom_minimum_size = Vector2(66, 66)
	sk_top.add_child(sk_ic)

	var sk_info := VBoxContainer.new()
	sk_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sk_info.add_theme_constant_override("separation", 3)
	sk_top.add_child(sk_info)

	var sk_hdr := HBoxContainer.new()
	sk_hdr.add_theme_constant_override("separation", 8)
	sk_info.add_child(sk_hdr)
	sk_hdr.add_child(_make_lbl("专属技能：" + String(def["skill_name"]), 19, Color(0.76, 0.32, 0.02), false))
	sk_hdr.add_child(_make_lbl("Lv.%d/%d" % [sk_lv, ProgressManager.MAX_SKILL_LEVEL], 16, Color(0.16, 0.56, 0.14), false))

	sk_info.add_child(_make_lbl(_progress.get_skill_desc(m_id), 15, Color(0.32, 0.18, 0.05), true))

	# 10-segment glowing golden energy bar for skill level!
	var sk_bar := SkillEnergyBar.new()
	sk_bar.level = sk_lv
	sk_bar.max_level = ProgressManager.MAX_SKILL_LEVEL
	sk_bar.custom_minimum_size = Vector2(0, 14)
	sk_v.add_child(sk_bar)

	# Bottom Primary Action Buttons
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 10)
	sk_v.add_child(act_row)

	if unlocked:
		var eq_txt := "使用中" if equipped else "立即装备"
		var eq_bg := Color(0.24, 0.72, 0.28) if equipped else Color(0.20, 0.64, 0.96)
		var eq_lip := Color(0.10, 0.44, 0.14) if equipped else Color(0.08, 0.36, 0.68)
		var eq_btn := _make_3d_btn(eq_txt, eq_bg, eq_lip, Color.WHITE, 18)
		eq_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eq_btn.custom_minimum_size = Vector2(0, 48)
		eq_btn.disabled = equipped
		eq_btn.pressed.connect(func() -> void: mower_equip_clicked.emit(m_id))
		act_row.add_child(eq_btn)

		var sk_afford := not sk_maxed and _progress.coins >= sk_cost
		var sk_txt := "技能已满级" if sk_maxed else ("升级技能 %d金" % sk_cost)
		var sk_bg := Color(0.24, 0.74, 0.34) if sk_maxed else (Color(1.0, 0.72, 0.10) if sk_afford else Color(0.84, 0.78, 0.68))
		var sk_lip := Color(0.10, 0.44, 0.16) if sk_maxed else (Color(0.76, 0.38, 0.02) if sk_afford else Color(0.62, 0.54, 0.44))
		var sk_fc := Color.WHITE if sk_maxed else (Color(0.26, 0.12, 0.02) if sk_afford else Color(0.48, 0.40, 0.32))
		var sk_btn := _make_3d_btn(sk_txt, sk_bg, sk_lip, sk_fc, 17)
		sk_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sk_btn.custom_minimum_size = Vector2(0, 48)
		sk_btn.disabled = sk_maxed or not sk_afford
		sk_btn.pressed.connect(func() -> void: mower_skill_upgrade_clicked.emit(m_id))
		act_row.add_child(sk_btn)
	else:
		var buy_afford := _progress.coins >= price
		var buy_bg := Color(1.0, 0.72, 0.10) if buy_afford else Color(0.84, 0.78, 0.68)
		var buy_lip := Color(0.76, 0.38, 0.02) if buy_afford else Color(0.62, 0.54, 0.44)
		var buy_fc := Color(0.26, 0.12, 0.02) if buy_afford else Color(0.48, 0.40, 0.32)
		var buy_btn := _make_3d_btn("解锁 %d金" % price, buy_bg, buy_lip, buy_fc, 18)
		buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy_btn.custom_minimum_size = Vector2(0, 48)
		buy_btn.disabled = not buy_afford
		buy_btn.pressed.connect(func() -> void: mower_buy_clicked.emit(m_id))
		act_row.add_child(buy_btn)

		var trial_btn := _make_3d_btn("看视频试驾1局", Color(0.14, 0.74, 0.34), Color(0.06, 0.44, 0.18), Color.WHITE, 17)
		trial_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trial_btn.custom_minimum_size = Vector2(0, 48)
		trial_btn.pressed.connect(func() -> void: mower_trial_ad_clicked.emit(m_id))
		act_row.add_child(trial_btn)

	_content_box.add_child(sk_card)

	# 4. MOWER PERFORMANCE COMPARISON BARS CARD
	var perf_card := _make_card_panel(Color(0.99, 0.96, 0.88), Color(0.84, 0.72, 0.48))
	var perf_v := VBoxContainer.new()
	perf_v.add_theme_constant_override("separation", 6)
	perf_card.add_child(perf_v)

	perf_v.add_child(_make_lbl("车辆性能参数", 16, Color(0.36, 0.20, 0.04), false))
	var cut_m := float(def.get("cut_mult", 1.0))
	var spd_m := float(def.get("speed_mult", 1.0))
	var coin_m := float(def.get("coin_mult", 1.0))
	var rows: Array[Dictionary] = [
		{"name": "割草刀盘", "val": cut_m, "max": 1.35, "col": Color(0.28, 0.78, 0.24)},
		{"name": "行进速度", "val": spd_m, "max": 1.35, "col": Color(0.18, 0.68, 0.96)},
		{"name": "金币收益", "val": coin_m, "max": 1.40, "col": Color(1.0, 0.68, 0.10)},
	]
	for r_dict in rows:
		var r_h := HBoxContainer.new()
		r_h.add_theme_constant_override("separation", 8)
		perf_v.add_child(r_h)
		var r_lbl := _make_lbl(String(r_dict["name"]), 14, Color(0.36, 0.22, 0.06), false)
		r_lbl.custom_minimum_size = Vector2(72, 0)
		r_h.add_child(r_lbl)
		var bar := PerfMeterBar.new()
		bar.ratio = clampf(float(r_dict["val"]) / float(r_dict["max"]), 0.15, 1.0)
		bar.fill_col = r_dict["col"]
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 14)
		r_h.add_child(bar)
		var pct_val := int(round(float(r_dict["val"]) * 100.0))
		var v_lbl := _make_lbl("%d%%" % pct_val, 14, Color(0.26, 0.14, 0.03), false)
		v_lbl.custom_minimum_size = Vector2(46, 0)
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r_h.add_child(v_lbl)
	_content_box.add_child(perf_card)

func _make_card_panel(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p

func _make_lbl(txt: String, sz: int, col: Color, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = txt
	if cute_font != null:
		l.add_theme_font_override("font", cute_font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _make_3d_btn(txt: String, bg: Color, lip: Color, font_col: Color, sz: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cute_font != null:
		b.add_theme_font_override("font", cute_font)
	b.add_theme_font_size_override("font_size", sz)
	b.add_theme_color_override("font_color", font_col)
	b.add_theme_color_override("font_hover_color", font_col)
	b.add_theme_color_override("font_pressed_color", font_col)
	b.add_theme_color_override("font_disabled_color", font_col)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = lip
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 5
	sb.set_corner_radius_all(18)
	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = bg.darkened(0.08)
	sb_p.border_width_bottom = 2
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_stylebox_override("disabled", sb)
	return b

func _style_tab_button(b: Button, active: bool) -> void:
	if b == null:
		return
	var bg := Color(1.0, 0.76, 0.16) if active else Color(0.92, 0.87, 0.74)
	var lip := Color(0.68, 0.36, 0.02) if active else Color(0.68, 0.56, 0.36)
	var fc := Color(0.26, 0.12, 0.02) if active else Color(0.46, 0.34, 0.18)
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = lip
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 4 if active else 2
	sb.set_corner_radius_all(18)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)


# ==============================================================================
# HERO TURNTABLE SHOWCASE STAGE (Big Animated Mower + Live Skill Halo Preview!)
# ==============================================================================
class MowerShowcaseStage extends Control:
	var cute_font: Font = null
	var mower_id: String = "classic"
	var mower_name: String = ""
	var bonus_desc: String = ""
	var status_tag: String = ""
	var is_unlocked: bool = true
	var mower_tex: Texture2D = null

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 80.0 or h < 80.0:
			return
		var t := Time.get_ticks_msec() * 0.001
		var cx := w * 0.5
		var cy := h * 0.47

		# Rich sunlit emerald turf backdrop with rounded gold-bordered stage
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.24, 0.62, 0.22)
		sb.border_color = Color(0.86, 0.64, 0.18)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(22)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))

		# Subtle sunlit radial spotlight & rotating turntable rays
		draw_circle(Vector2(cx, cy), 96.0, Color(0.46, 0.84, 0.34, 0.55))
		draw_circle(Vector2(cx, cy), 74.0, Color(0.76, 0.96, 0.52, 0.45))
		draw_arc(Vector2(cx, cy), 84.0, t * 0.8, t * 0.8 + 4.4, 24, Color(1.0, 0.94, 0.52, 0.65), 3.0, false)
		draw_arc(Vector2(cx, cy), 70.0, -t * 1.1, -t * 1.1 + 3.6, 20, Color(1.0, 1.0, 0.88, 0.45), 2.0, false)

		# Live Skill Preview Aura matching the inspected mower!
		if mower_id == "volt":
			var hex := PackedVector2Array()
			for i in range(7):
				var a := t * 1.2 + float(i) * (TAU / 6.0)
				hex.append(Vector2(cx + cos(a) * 78.0, cy + sin(a) * 78.0))
			draw_circle(Vector2(cx, cy), 78.0, Color(0.22, 0.84, 1.0, 0.18))
			draw_polyline(hex, Color(0.55, 0.96, 1.0, 0.90), 3.4, false)
		elif mower_id == "cyclone" or mower_id == "rainbow":
			for i in range(4):
				var a := t * 4.0 + float(i) * (PI * 0.5)
				draw_arc(Vector2(cx, cy), 80.0, a, a + 0.95, 10, Color(1.0, 0.90, 0.24, 0.88), 4.6, false)
		elif mower_id == "crusher":
			var g := 0.5 + 0.3 * sin(t * 7.0)
			draw_arc(Vector2(cx, cy), 76.0, 0.0, TAU, 24, Color(1.0, 0.52, 0.14, g), 3.8, false)

		# Big illustrated mower breathing gently on the pedestal!
		if mower_tex != null:
			var bob := sin(t * 3.0) * 3.5
			var sz := 148.0 + sin(t * 2.4) * 3.0
			draw_circle(Vector2(cx + 4.0, cy + 18.0), 54.0, Color(0.06, 0.18, 0.04, 0.30))
			var tint := Color.WHITE if is_unlocked else Color(0.88, 0.90, 0.94, 0.92)
			draw_texture_rect(mower_tex, Rect2(cx - sz * 0.5, cy - sz * 0.5 + bob, sz, sz), false, tint)

		var font := cute_font if cute_font != null else ThemeDB.fallback_font
		# Top-left status pill
		var st_col := Color(0.18, 0.72, 0.26) if status_tag == "使用中" else (Color(0.20, 0.60, 0.92) if is_unlocked else Color(0.34, 0.28, 0.22))
		var st_sb := StyleBoxFlat.new()
		st_sb.bg_color = st_col
		st_sb.set_corner_radius_all(12)
		draw_style_box(st_sb, Rect2(12.0, 10.0, 74.0, 26.0))
		draw_string(font, Vector2(12.0, 28.5), status_tag, HORIZONTAL_ALIGNMENT_CENTER, 74.0, 14, Color.WHITE)

		# Top-right passive bonus pill
		var bn_sb := StyleBoxFlat.new()
		bn_sb.bg_color = Color(1.0, 0.92, 0.42, 0.95)
		bn_sb.set_corner_radius_all(12)
		var bn_w := clampf(float(bonus_desc.length()) * 13.0 + 24.0, 96.0, w * 0.54)
		draw_style_box(bn_sb, Rect2(w - bn_w - 12.0, 10.0, bn_w, 26.0))
		draw_string(font, Vector2(w - bn_w - 12.0, 28.5), bonus_desc, HORIZONTAL_ALIGNMENT_CENTER, bn_w, 14, Color(0.32, 0.15, 0.02))

		# Bottom Name Banner
		var nm_sb := StyleBoxFlat.new()
		nm_sb.bg_color = Color(0.16, 0.34, 0.10, 0.88)
		nm_sb.border_color = Color(1.0, 0.86, 0.32)
		nm_sb.set_border_width_all(2)
		nm_sb.set_corner_radius_all(14)
		var nm_w := 172.0
		draw_style_box(nm_sb, Rect2(cx - nm_w * 0.5, h - 38.0, nm_w, 30.0))
		draw_string(font, Vector2(cx - nm_w * 0.5, h - 16.0), mower_name, HORIZONTAL_ALIGNMENT_CENTER, nm_w, 19, Color(1.0, 0.98, 0.86))


class MowerThumbButton extends Button:
	var mower_tex: Texture2D = null
	var is_selected: bool = false
	var is_unlocked: bool = false
	var is_equipped: bool = false

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		add_theme_stylebox_override("normal", empty)
		add_theme_stylebox_override("hover", empty)
		add_theme_stylebox_override("pressed", empty)
		add_theme_stylebox_override("focus", empty)

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.92, 0.52) if is_selected else (Color(0.92, 0.96, 0.84) if is_unlocked else Color(0.86, 0.82, 0.74))
		sb.border_color = Color(0.96, 0.54, 0.04) if is_selected else (Color(0.28, 0.66, 0.22) if is_equipped else Color(0.68, 0.58, 0.42))
		sb.set_border_width_all(4 if is_selected else 2)
		sb.set_corner_radius_all(14)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if mower_tex != null:
			var sz := minf(size.x, size.y) * 0.80
			var tint := Color.WHITE if is_unlocked else Color(0.65, 0.68, 0.72, 0.80)
			draw_texture_rect(mower_tex, Rect2((size.x - sz) * 0.5, (size.y - sz) * 0.5, sz, sz), false, tint)
		if is_equipped:
			draw_circle(Vector2(size.x - 10.0, 10.0), 6.0, Color(0.18, 0.78, 0.28))
			draw_arc(Vector2(size.x - 10.0, 10.0), 6.0, 0.0, TAU, 12, Color.WHITE, 1.6, false)


class StatMilestoneBar extends Control:
	var level: int = 0
	var max_level: int = 30
	var fill_col: Color = Color(0.24, 0.76, 0.30)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 40.0:
			return
		var bar_h := 8.0
		var by := (h - bar_h) * 0.5
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.84, 0.78, 0.64)
		bg.set_corner_radius_all(4)
		draw_style_box(bg, Rect2(0.0, by, w, bar_h))

		var ratio := clampf(float(level) / float(maxi(max_level, 1)), 0.0, 1.0)
		if ratio > 0.005:
			var fg := StyleBoxFlat.new()
			fg.bg_color = fill_col
			fg.set_corner_radius_all(4)
			draw_style_box(fg, Rect2(0.0, by, maxf(8.0, w * ratio), bar_h))

		# Milestone gems at Lv.10, Lv.20, Lv.30
		for m_lv_raw in [10, 20, 30]:
			var m_lv: int = int(m_lv_raw)
			var mx := w * (float(m_lv) / float(max_level)) - (5.0 if m_lv == 30 else 0.0)
			var reached: bool = level >= m_lv
			draw_circle(Vector2(mx, h * 0.5), 5.5, Color(0.38, 0.20, 0.04))
			draw_circle(Vector2(mx, h * 0.5), 3.8, Color(1.0, 0.88, 0.22) if reached else Color(0.92, 0.88, 0.78))


class SkillEnergyBar extends Control:
	var level: int = 1
	var max_level: int = 10

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 40.0:
			return
		var gap := 4.0
		var seg_w := (w - gap * float(max_level - 1)) / float(max_level)
		for i in range(max_level):
			var sx := float(i) * (seg_w + gap)
			var filled := i < level
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1.0, 0.74, 0.12) if filled else Color(0.84, 0.78, 0.64)
			sb.border_color = Color(0.56, 0.28, 0.02) if filled else Color(0.68, 0.60, 0.48)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(4)
			draw_style_box(sb, Rect2(sx, 1.0, seg_w, h - 2.0))


class PerfMeterBar extends Control:
	var ratio: float = 0.75
	var fill_col: Color = Color(0.28, 0.78, 0.24)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 20.0:
			return
		var bar_h := 10.0
		var by := (h - bar_h) * 0.5
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.86, 0.80, 0.66)
		bg.set_corner_radius_all(5)
		draw_style_box(bg, Rect2(0.0, by, w, bar_h))

		var fg := StyleBoxFlat.new()
		fg.bg_color = fill_col
		fg.set_corner_radius_all(5)
		draw_style_box(fg, Rect2(0.0, by, maxf(10.0, w * clampf(ratio, 0.0, 1.0)), bar_h))
