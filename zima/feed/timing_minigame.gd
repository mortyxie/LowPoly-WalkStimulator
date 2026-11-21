class_name TimingMinigame
extends CanvasLayer

## 时机判定小游戏（轮回 2 破盒 / 轮回 3 撬锁共用一套 UI，全部参数化）。
## 策划案精确参数：
##   - 黑底轨道 400px、暗红滑块 24×12px、绿区 60px、匀速往复周期 4.2s、命中 3 次（破盒）
##   - 撬锁：绿区 90px、周期 3.8s、命中 2 次（其余同款）
## 输入：空格命中（SubViewport 里 _input 收不到事件，这里在根层轮询 Input）。
## 用法（LoopManager 统一调用）：
##   var ok: bool = await game.start_and_wait({...})
##   失败/成功的后续处理（【我看到你了】+ 重置 / 通关）由 LoopManager 负责。

signal finished(success: bool)

## 像素扁平风默认配色
const TRACK_COLOR := Color(0.02, 0.02, 0.02, 1.0)          # 黑底轨道
const GREEN_COLOR := Color(0.22, 0.72, 0.25, 1.0)          # 绿区
const DEFAULT_SLIDER_COLOR := Color(0.55, 0.10, 0.12, 1.0) # 暗红滑块
const PANEL_COLOR := Color(0.03, 0.03, 0.05, 0.92)
const HINT_COLOR := Color(0.8, 0.8, 0.8, 1.0)

var active := false

# —— 供自动化测试读取的运行状态 ——
var slider_x := 0.0
var green_x := 0.0

var _cfg := {}
var _elapsed := 0.0
var _hits := 0
var _waiting := false

var _root: Control
var _title: Label
var _hint: Label
var _track: ColorRect
var _green: ColorRect
var _slider: ColorRect
var _pixel_font: Font


func _ready() -> void:
	layer = 110
	_pixel_font = load("res://assets/fonts/fusion-pixel-12px-zh_hans.ttf")

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# 半透明压暗背景
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	# 中央面板（黑底扁平像素风）
	var panel := Panel.new()
	panel.self_modulate = PANEL_COLOR
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_right = 280.0
	panel.offset_top = -130.0
	panel.offset_bottom = 130.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	_title = _make_label(panel, 26)
	_title.anchor_left = 0.0
	_title.anchor_right = 1.0
	_title.offset_top = 18.0
	_title.offset_bottom = 56.0

	# 黑底轨道 400px，横向居中
	_track = ColorRect.new()
	_track.color = TRACK_COLOR
	_track.anchor_left = 0.5
	_track.anchor_right = 0.5
	_track.anchor_top = 0.4
	_track.anchor_bottom = 0.4
	_track.offset_left = -200.0
	_track.offset_right = 200.0
	_track.offset_top = -14.0
	_track.offset_bottom = 14.0
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_track)

	_green = ColorRect.new()
	_green.color = GREEN_COLOR
	_green.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_green)

	_slider = ColorRect.new()
	_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_slider)

	_hint = _make_label(panel, 18)
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -66.0
	_hint.offset_bottom = -22.0
	_hint.modulate = HINT_COLOR

	visible = false


func _make_label(parent: Control, font_size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _pixel_font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.92, 0.9, 0.86))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 参数化启动，等待玩家玩完返回结果。config 可用键：
##   title / track_width / slider_size(Vector2) / green_width / period /
##   hits_required / slider_color
func start_and_wait(config: Dictionary) -> bool:
	_cfg = {
		"title": config.get("title", "时机判定"),
		"track_width": config.get("track_width", 400.0),
		"slider_size": config.get("slider_size", Vector2(24, 12)),
		"green_width": config.get("green_width", 60.0),
		"period": maxf(config.get("period", 4.2), 0.1),
		"hits_required": config.get("hits_required", 3),
		"slider_color": config.get("slider_color", DEFAULT_SLIDER_COLOR),
	}
	var track_w: float = _cfg["track_width"]
	var slider_size: Vector2 = _cfg["slider_size"]
	var green_w: float = _cfg["green_width"]

	_track.offset_left = -track_w * 0.5
	_track.offset_right = track_w * 0.5
	_slider.color = _cfg["slider_color"]
	_slider.size = slider_size
	_green.size = Vector2(green_w, _track.size.y)
	_title.text = _cfg["title"]
	_hits = 0
	_elapsed = 0.0
	_place_green()
	_update_hint()

	visible = true
	active = true
	_waiting = true
	var success: bool = await finished
	_waiting = false
	return success


## 强制关闭（不发出结果，供轮回重置/结局演出收尾用）
func force_close() -> void:
	active = false
	visible = false


func _place_green() -> void:
	var track_w: float = _cfg["track_width"]
	var green_w: float = _cfg["green_width"]
	# 绿区随机摆放（留边距，避免贴轨道两端）
	green_x = randf_range(0.12 * (track_w - green_w), 0.88 * (track_w - green_w))
	_green.position = Vector2(green_x, 0.0)


func _update_hint() -> void:
	_hint.text = "[空格] 滑块进绿区时按下　·　%d / %d" % [_hits, _cfg["hits_required"]]


func _process(delta: float) -> void:
	if not active:
		return
	# 匀速往复：完整来回一次 = period 秒
	_elapsed += delta
	var track_w: float = _cfg["track_width"]
	var slider_size: Vector2 = _cfg["slider_size"]
	var span: float = track_w - slider_size.x
	slider_x = pingpong(_elapsed * span * 2.0 / _cfg["period"], span)
	_slider.position = Vector2(slider_x, (_track.size.y - slider_size.y) * 0.5)

	if Input.is_action_just_pressed("minigame_hit"):
		var sw: float = slider_size.x
		var green_w: float = _cfg["green_width"]
		var overlap := slider_x <= green_x + green_w and slider_x + sw >= green_x
		if overlap:
			_hits += 1
			if _hits >= int(_cfg["hits_required"]):
				_finish(true)
			else:
				_place_green()
				_update_hint()
		else:
			_finish(false)


func _finish(success: bool) -> void:
	active = false
	visible = false
	# 只在有等待者时广播，避免重置流程里收到幽灵结果
	if _waiting:
		finished.emit(success)
