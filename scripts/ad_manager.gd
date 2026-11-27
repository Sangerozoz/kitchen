extends Node
class_name AdManager

## TapTap H5 小游戏激励视频广告位 ID（竖屏游戏对应 portrait_space_id，已通过 TapTap 小游戏 MCP check_ads_status 获取）
## 注意：H5 形态仅支持激励视频（tap.createRewardedVideoAd），不支持插屏 / Banner / 格子广告。
const REWARDED_AD_UNIT_ID := "1054324"

signal ad_started(placement: String)
signal ad_finished(placement: String, rewarded: bool, status: String, error_msg: String)

var _busy := false
var _pending_placement := ""

func _ready() -> void:
	if OS.has_feature("web"):
		var js := "window.__TapAdBridge ? window.__TapAdBridge.init(%s) : 'missing_bridge'" % JSON.stringify(REWARDED_AD_UNIT_ID)
		JavaScriptBridge.eval(js)

func is_busy() -> bool:
	return _busy

func get_env_status() -> String:
	if not OS.has_feature("web"):
		return "non_web"
	var js := "window.__TapAdBridge ? window.__TapAdBridge.getEnvStatus(%s) : 'missing_bridge'" % JSON.stringify(REWARDED_AD_UNIT_ID)
	var res = JavaScriptBridge.eval(js)
	return String(res) if res != null else "missing_bridge"

func has_configured_unit_id() -> bool:
	var id := REWARDED_AD_UNIT_ID.strip_edges()
	return id != "" and not id.begins_with("REPLACE_") and id != "your-ad-unit-id"

func show_rewarded_video(placement: String) -> void:
	if _busy:
		return

	if not OS.has_feature("web"):
		ad_finished.emit(placement, false, "unsupported", "non_web")
		return

	_busy = true
	_pending_placement = placement
	ad_started.emit(placement)

	var js := "window.__TapAdBridge ? window.__TapAdBridge.showRewarded(%s, %s) : 'missing_bridge'" % [
		JSON.stringify(placement),
		JSON.stringify(REWARDED_AD_UNIT_ID),
	]
	var ret = JavaScriptBridge.eval(js)
	var ret_str := String(ret) if ret != null else "missing_bridge"

	if ret_str == "missing_bridge":
		_busy = false
		_pending_placement = ""
		ad_finished.emit(placement, false, "error", "missing_bridge")
	elif ret_str != "started" and ret_str != "busy":
		# Immediate synchronous fallback result was queued in JS; flush on next tick
		call_deferred("_poll_bridge_result")

func _process(_delta: float) -> void:
	if not _busy or not OS.has_feature("web"):
		return
	_poll_bridge_result()

func _poll_bridge_result() -> void:
	if not OS.has_feature("web"):
		return
	var raw = JavaScriptBridge.eval("window.__TapAdBridge ? window.__TapAdBridge.pollResult() : ''")
	if not (raw is String) or (raw as String) == "":
		return
	var parsed = JSON.parse_string(raw as String)
	var placement := _pending_placement
	var rewarded := false
	var status := "error"
	var msg := ""
	if parsed is Dictionary:
		var d: Dictionary = parsed
		placement = String(d.get("placement", _pending_placement))
		rewarded = bool(d.get("rewarded", false))
		status = String(d.get("status", "error"))
		msg = String(d.get("message", ""))
	_busy = false
	_pending_placement = ""
	ad_finished.emit(placement, rewarded, status, msg)
