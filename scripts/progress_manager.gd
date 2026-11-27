extends RefCounted
class_name ProgressManager

const PROGRESS_PATH := "user://lawn_progress.cfg"
const LEGACY_SAVE_PATH := "user://lawn_high_score.cfg"

const MAX_STAT_LEVEL := 30
const MAX_SKILL_LEVEL := 10
const AD_FREE_COINS := 150

const STAT_KEYS := ["blade", "engine", "chassis", "greed"]

const STAT_META := {
	"blade": {
		"name": "刀盘宽度",
		"short": "割草半径",
		"accent": Color(0.22, 0.74, 0.30),
		"m10": "Lv.10 广域吸边",
		"m20": "Lv.20 割草分+20%",
		"m30": "Lv.30 巨幅收割",
	},
	"engine": {
		"name": "引擎动力",
		"short": "移动速度",
		"accent": Color(0.98, 0.56, 0.10),
		"m10": "Lv.10 灵巧过弯",
		"m20": "Lv.20 过关送2s冲刺",
		"m30": "Lv.30 极速巡航",
	},
	"chassis": {
		"name": "稳重底盘",
		"short": "抗干扰",
		"accent": Color(0.24, 0.60, 0.94),
		"m10": "Lv.10 免疫泥潭打滑",
		"m20": "Lv.20 免疫小狗眩晕",
		"m30": "Lv.30 免疫撞石减速",
	},
	"greed": {
		"name": "招财收割",
		"short": "金币加成",
		"accent": Color(0.96, 0.74, 0.10),
		"m10": "Lv.10 金币+50%",
		"m20": "Lv.20 金币+100%",
		"m30": "Lv.30 金币+150%",
	},
}

const MOWER_ORDER := ["classic", "volt", "crusher", "cyclone", "rainbow"]

const MOWER_DEFS := {
	"classic": {
		"name": "经典小红",
		"price": 0,
		"tier": 1,
		"color": Color(0.92, 0.22, 0.18),
		"trim": Color(1.0, 0.84, 0.24),
		"bonus_desc": "均衡入门款",
		"skill_name": "开局彩虹加速",
		"skill_type": "start_boost",
		"cut_mult": 1.0,
		"speed_mult": 1.0,
		"coin_mult": 1.0,
	},
	"volt": {
		"name": "闪电疾风",
		"price": 400,
		"tier": 2,
		"color": Color(0.98, 0.78, 0.10),
		"trim": Color(0.16, 0.18, 0.22),
		"bonus_desc": "移速 +10%",
		"skill_name": "能量防护罩",
		"skill_type": "shield",
		"cut_mult": 1.0,
		"speed_mult": 1.10,
		"coin_mult": 1.0,
	},
	"crusher": {
		"name": "重装碎石机",
		"price": 1100,
		"tier": 3,
		"color": Color(0.94, 0.42, 0.10),
		"trim": Color(0.32, 0.36, 0.40),
		"bonus_desc": "刀盘 +12%",
		"skill_name": "粉碎冲撞",
		"skill_type": "smash",
		"cut_mult": 1.12,
		"speed_mult": 1.0,
		"coin_mult": 1.0,
	},
	"cyclone": {
		"name": "旋风收割者",
		"price": 2400,
		"tier": 4,
		"color": Color(0.14, 0.76, 0.44),
		"trim": Color(1.0, 0.88, 0.24),
		"bonus_desc": "金币 +25%",
		"skill_name": "旋风刀气",
		"skill_type": "whirlwind",
		"cut_mult": 1.0,
		"speed_mult": 1.0,
		"coin_mult": 1.25,
	},
	"rainbow": {
		"name": "彩虹星际号",
		"price": 5000,
		"tier": 5,
		"color": Color(0.58, 0.34, 0.98),
		"trim": Color(0.28, 0.92, 1.0),
		"bonus_desc": "全属性+15% 金币+40%",
		"skill_name": "终极全能",
		"skill_type": "omni",
		"cut_mult": 1.15,
		"speed_mult": 1.15,
		"coin_mult": 1.40,
	},
}

var coins: int = 0
var best_score: int = 0
var equipped_mower: String = "classic"
var trial_mower: String = ""

var stat_levels: Dictionary = {
	"blade": 0,
	"engine": 0,
	"chassis": 0,
	"greed": 0,
}

var unlocked_mowers: Dictionary = {
	"classic": true,
	"volt": false,
	"crusher": false,
	"cyclone": false,
	"rainbow": false,
}

var skill_levels: Dictionary = {
	"classic": 1,
	"volt": 1,
	"crusher": 1,
	"cyclone": 1,
	"rainbow": 1,
}

func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) == OK:
		coins = maxi(0, int(cfg.get_value("wallet", "coins", 0)))
		best_score = maxi(0, int(cfg.get_value("records", "best_score", 0)))
		equipped_mower = String(cfg.get_value("garage", "equipped_mower", "classic"))
		if not MOWER_DEFS.has(equipped_mower):
			equipped_mower = "classic"
		for k_raw in STAT_KEYS:
			var k: String = String(k_raw)
			stat_levels[k] = clampi(int(cfg.get_value("stats", k, 0)), 0, MAX_STAT_LEVEL)
		for m_raw in MOWER_ORDER:
			var m: String = String(m_raw)
			var def_u: bool = (m == "classic")
			unlocked_mowers[m] = bool(cfg.get_value("mowers_unlocked", m, def_u))
			skill_levels[m] = clampi(int(cfg.get_value("mowers_skill", m, 1)), 1, MAX_SKILL_LEVEL)
		unlocked_mowers["classic"] = true
		if not bool(unlocked_mowers.get(equipped_mower, false)):
			equipped_mower = "classic"
	else:
		# Migrate best_score from legacy save if present
		var legacy := ConfigFile.new()
		if legacy.load(LEGACY_SAVE_PATH) == OK:
			best_score = maxi(0, int(legacy.get_value("records", "best_score", 0)))
		save_data()

func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("wallet", "coins", coins)
	cfg.set_value("records", "best_score", best_score)
	cfg.set_value("garage", "equipped_mower", equipped_mower)
	for k in STAT_KEYS:
		cfg.set_value("stats", k, int(stat_levels[k]))
	for m in MOWER_ORDER:
		cfg.set_value("mowers_unlocked", m, bool(unlocked_mowers[m]))
		cfg.set_value("mowers_skill", m, int(skill_levels[m]))
	cfg.save(PROGRESS_PATH)

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	save_data()

func get_stat_level(key: String) -> int:
	return int(stat_levels.get(key, 0))

func get_stat_cost(key: String) -> int:
	var lv := get_stat_level(key)
	if lv >= MAX_STAT_LEVEL:
		return 0
	return 35 + lv * 22 + int(round(float(lv * lv) * 3.5))

func can_upgrade_stat(key: String) -> bool:
	var lv := get_stat_level(key)
	return lv < MAX_STAT_LEVEL and coins >= get_stat_cost(key)

func upgrade_stat(key: String) -> bool:
	if not can_upgrade_stat(key):
		return false
	coins -= get_stat_cost(key)
	stat_levels[key] = get_stat_level(key) + 1
	save_data()
	return true

func is_mower_unlocked(mower_id: String) -> bool:
	return bool(unlocked_mowers.get(mower_id, false))

func get_mower_price(mower_id: String) -> int:
	if not MOWER_DEFS.has(mower_id):
		return 0
	return int(MOWER_DEFS[mower_id]["price"])

func get_skill_level(mower_id: String) -> int:
	return clampi(int(skill_levels.get(mower_id, 1)), 1, MAX_SKILL_LEVEL)

func get_skill_cost(mower_id: String) -> int:
	var lv := get_skill_level(mower_id)
	if lv >= MAX_SKILL_LEVEL:
		return 0
	var tier := int(MOWER_DEFS.get(mower_id, {}).get("tier", 1))
	var step := lv - 1
	return (55 + tier * 20) + step * (45 + tier * 12) + step * step * 16

func buy_mower(mower_id: String) -> bool:
	if not MOWER_DEFS.has(mower_id) or is_mower_unlocked(mower_id):
		return false
	var price := get_mower_price(mower_id)
	if coins < price:
		return false
	coins -= price
	unlocked_mowers[mower_id] = true
	equipped_mower = mower_id
	save_data()
	return true

func equip_mower(mower_id: String) -> bool:
	if not is_mower_unlocked(mower_id):
		return false
	equipped_mower = mower_id
	save_data()
	return true

func upgrade_mower_skill(mower_id: String) -> bool:
	if not is_mower_unlocked(mower_id):
		return false
	var lv := get_skill_level(mower_id)
	if lv >= MAX_SKILL_LEVEL:
		return false
	var cost := get_skill_cost(mower_id)
	if coins < cost:
		return false
	coins -= cost
	skill_levels[mower_id] = lv + 1
	save_data()
	return true

func has_any_affordable_upgrade() -> bool:
	for k in STAT_KEYS:
		if can_upgrade_stat(k):
			return true
	for m in MOWER_ORDER:
		if not is_mower_unlocked(m):
			if coins >= get_mower_price(m):
				return true
		elif get_skill_level(m) < MAX_SKILL_LEVEL and coins >= get_skill_cost(m):
			return true
	return false

func get_active_mower_id() -> String:
	if trial_mower != "" and MOWER_DEFS.has(trial_mower):
		return trial_mower
	return equipped_mower

func get_stat_summary(key: String) -> String:
	var lv := get_stat_level(key)
	match key:
		"blade":
			return "半径 %.0fpx" % (34.0 + float(lv) * 1.2)
		"engine":
			return "速度 %d" % int(round(250.0 + float(lv) * 5.0))
		"chassis":
			return "抗干扰 -%d%%" % int(round(float(lv) * 2.5))
		"greed":
			return "金币 +%d%%" % (lv * 5)
	return ""

func get_next_milestone_hint(key: String) -> String:
	var lv := get_stat_level(key)
	var meta: Dictionary = STAT_META[key]
	if lv < 10:
		return String(meta["m10"])
	elif lv < 20:
		return String(meta["m20"])
	elif lv < 30:
		return String(meta["m30"])
	return "已满级!"

func get_skill_desc(mower_id: String, lv_override: int = -1) -> String:
	var lv := lv_override if lv_override > 0 else get_skill_level(mower_id)
	var u := float(lv - 1) / float(MAX_SKILL_LEVEL - 1) # 0.0 -> 1.0
	match mower_id:
		"classic":
			var dur := lerpf(3.0, 10.0, u)
			return "开局自带 %.1fs 彩虹加速" % dur
		"volt":
			var dur := lerpf(4.0, 9.5, u)
			var cd := lerpf(11.0, 6.5, u)
			return "护盾 %.1fs（免疫干扰 / 冷却%.0fs）" % [dur, cd]
		"crusher":
			var max_r := 21.0 + float(lv) * 1.15
			var size_tag := "小石" if lv <= 3 else ("中石" if lv <= 6 else "全尺寸巨石")
			return "撞碎%s爆金币 + 撞飞动物 (≤%.0f)" % [size_tag, max_r]
		"cyclone":
			var dur := lerpf(3.5, 9.0, u)
			return "周期旋风刀气 %.1fs 大范围清草" % dur
		"rainbow":
			var dur := lerpf(5.0, 10.0, u)
			return "开局%.1fs冲刺 + 旋风刀气 + 粉碎一切" % dur
	return ""

func compute_effective_stats(override_mower_id: String = "") -> Dictionary:
	var m_id := override_mower_id if override_mower_id != "" else get_active_mower_id()
	if not MOWER_DEFS.has(m_id):
		m_id = "classic"

	var blade_lv := get_stat_level("blade")
	var engine_lv := get_stat_level("engine")
	var chassis_lv := get_stat_level("chassis")
	var greed_lv := get_stat_level("greed")

	# For trial mowers, give a crisp preview at Skill Lv.4 so the player feels how awesome the mower is!
	var is_trial := (trial_mower != "" and m_id == trial_mower and not is_mower_unlocked(m_id))
	var sk_lv := 4 if is_trial else get_skill_level(m_id)
	var sk_u := float(sk_lv - 1) / float(MAX_SKILL_LEVEL - 1)

	var cut_r := 34.0 + float(blade_lv) * 1.2
	var max_spd := 250.0 + float(engine_lv) * 5.0
	var coin_mult := 1.0 + float(greed_lv) * 0.05

	# Chassis passive bonuses per mower model
	match m_id:
		"volt":
			max_spd *= 1.10
		"crusher":
			cut_r *= 1.12
		"cyclone":
			coin_mult += 0.25
		"rainbow":
			cut_r *= 1.15
			max_spd *= 1.15
			coin_mult += 0.40

	var boost_spd := max_spd * 1.50
	var boost_cut_r := cut_r * 1.44
	var debuff_mult := clampf(1.0 - float(chassis_lv) * 0.025, 0.25, 1.0)

	# Mower-bound exclusive skills
	var start_boost_dur := 0.0
	var has_shield := false
	var shield_dur := 0.0
	var shield_cd := 12.0
	var has_smash := false
	var smash_max_rock_rad := 0.0
	var smash_animals := false
	var has_whirlwind := false
	var whirlwind_dur := 0.0
	var whirlwind_cd := 11.0

	match m_id:
		"classic":
			start_boost_dur = lerpf(3.0, 10.0, sk_u)
		"volt":
			has_shield = true
			shield_dur = lerpf(4.0, 9.5, sk_u)
			shield_cd = lerpf(11.0, 6.5, sk_u)
		"crusher":
			has_smash = true
			smash_max_rock_rad = 21.0 + float(sk_lv) * 1.15 # Lv1=22.1 (small), Lv5=26.7 (med), Lv8+=30+ (all rocks!)
			smash_animals = sk_lv >= 2
		"cyclone":
			has_whirlwind = true
			whirlwind_dur = lerpf(3.5, 9.0, sk_u)
			whirlwind_cd = lerpf(10.5, 6.5, sk_u)
		"rainbow":
			start_boost_dur = lerpf(5.0, 10.0, sk_u)
			has_whirlwind = true
			whirlwind_dur = lerpf(4.5, 10.0, sk_u)
			whirlwind_cd = lerpf(9.5, 6.0, sk_u)
			has_smash = true
			smash_max_rock_rad = 99.0
			smash_animals = true

	return {
		"mower_id": m_id,
		"is_trial": is_trial,
		"skill_level": sk_lv,
		"cut_radius": cut_r,
		"boost_cut_radius": boost_cut_r,
		"max_speed": max_spd,
		"boost_speed": boost_spd,
		"turn_mult": 1.30 if engine_lv >= 10 else 1.0,
		"clear_boost_dur": 2.0 if engine_lv >= 20 else 1.2,
		"blade_score_mult": 1.20 if blade_lv >= 20 else 1.0,
		"edge_snap_radius": 24.0 if blade_lv >= 10 else 14.0,
		"debuff_mult": debuff_mult,
		"immune_mud": chassis_lv >= 10,
		"immune_dizzy": chassis_lv >= 20,
		"immune_rock": chassis_lv >= 30,
		"coin_mult": coin_mult,
		"start_boost_dur": start_boost_dur,
		"has_shield": has_shield,
		"shield_dur": shield_dur,
		"shield_cd": shield_cd,
		"has_smash": has_smash,
		"smash_max_rock_rad": smash_max_rock_rad,
		"smash_animals": smash_animals,
		"has_whirlwind": has_whirlwind,
		"whirlwind_dur": whirlwind_dur,
		"whirlwind_cd": whirlwind_cd,
	}
