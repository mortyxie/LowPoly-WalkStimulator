extends CanvasLayer

## MessageBanner（自动加载单例）
## 屏幕中上方大字浮现，停留一段时间后淡出。用于：
##   - 玩家摄入食物的反馈（金色）
##   - 房东喊话/威胁（红色）
## 用法：
##   MessageBanner.show_message("快点送来！")                        # 白色默认
##   MessageBanner.show_message("房东：快点送来！", Color.RED, 3.0)  # 自定义颜色和时长
## 多条消息会排队依次显示。

const FONT_SIZE := 50
## 长句自动降到的字号（防止一行画出屏幕）
const FONT_SIZE_LONG := 34
## 超过这个字数视为长句
const LONG_TEXT_LIMIT := 18
const FADE_IN_TIME := 0.25
const FADE_OUT_TIME := 0.6

var _label: Label
var _tween: Tween
var _queue: Array[Dictionary] = []
var _busy := false


func _ready() -> void:
	layer = 90

	# 用系统字体保证中文正常显示（Godot 内置字体不含 CJK）
	var cjk_font := SystemFont.new()
	cjk_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "SimSun", "sans-serif"])

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_label = Label.new()
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	# 左右留 48px 边距，长句也不顶到屏幕边
	_label.offset_left = 48.0
	_label.offset_right = -48.0
	_label.offset_top = 64.0
	_label.offset_bottom = 200.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 中文按任意字符处换行（WORD 语义对 CJK 不换行），保险兜底
	_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_label.add_theme_font_override("font", cjk_font)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_label)


func show_message(text: String, color: Color = Color.WHITE, duration: float = 2.5) -> void:
	_queue.append({"text": text, "color": color, "duration": duration})
	if not _busy:
		_process_next()


func _process_next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var msg: Dictionary = _queue.pop_front()
	_label.text = msg["text"]
	# 长句降字号：单行放不下时先缩字，配合自动换行保证不超出屏幕
	var fs: int = FONT_SIZE if msg["text"].length() <= LONG_TEXT_LIMIT else FONT_SIZE_LONG
	_label.add_theme_font_size_override("font_size", fs)
	_label.add_theme_color_override("font_color", msg["color"])
	# modulate 与 self_modulate 相乘才是最终透明度，两处都要归位
	_label.modulate.a = 1.0
	_label.self_modulate.a = 0.0

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "self_modulate:a", 1.0, FADE_IN_TIME)
	_tween.tween_interval(msg["duration"])
	_tween.tween_property(_label, "self_modulate:a", 0.0, FADE_OUT_TIME)
	_tween.tween_callback(_process_next)
