extends CanvasLayer

## LoopUI：轮回系统的全部屏幕演出（由 LoopManager 创建和驱动）。
##   - 全屏黑幕淡入淡出（轮回失败重置 / 换轮 / 结局）
##   - 红色粗像素字【我看到你了】闪烁 0.8 秒（所有失败分支统一警示）
##   - 结局：纯白细体「欢迎回家」淡入停留 3-5 秒 → Staff 片尾滚动
## 像素字体复用 assets/fonts/（全局 UI 主题同款）， welcome 用系统细体。

const PIXEL_FONT_PATH := "res://assets/fonts/fusion-pixel-12px-zh_hans.ttf"

var _black: ColorRect
var _warning: Label
var _welcome: Label
var _credits_box: VBoxContainer
var _pixel_font: Font


func _ready() -> void:
	layer = 120
	_pixel_font = load(PIXEL_FONT_PATH)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 全屏黑幕
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_black)

	# 红色粗像素字警示（默认隐藏）
	_warning = Label.new()
	_warning.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning.add_theme_font_override("font", _pixel_font)
	_warning.add_theme_font_size_override("font_size", 64)
	_warning.add_theme_color_override("font_color", Color(0.86, 0.08, 0.06))
	_warning.add_theme_color_override("font_outline_color", Color(0.1, 0, 0))
	_warning.add_theme_constant_override("outline_size", 10)
	_warning.text = "【我看到你了】"
	_warning.visible = false
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_warning)

	# 结局白字（细体系统字体，区别于像素风的"非人感"）
	_welcome = Label.new()
	_welcome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_welcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var thin := SystemFont.new()
	thin.font_names = PackedStringArray([
		"Segoe UI Light", "Microsoft YaHei UI Light", "Microsoft YaHei", "SimHei", "sans-serif"])
	_welcome.add_theme_font_override("font", thin)
	_welcome.add_theme_font_size_override("font_size", 58)
	_welcome.add_theme_color_override("font_color", Color(1, 1, 1))
	_welcome.text = "欢迎回家"
	_welcome.visible = false
	_welcome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_welcome)

	# 片尾滚动字幕容器
	_credits_box = VBoxContainer.new()
	_credits_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_box.offset_top = 0.0
	_credits_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_credits_box.add_theme_constant_override("separation", 14)
	_credits_box.visible = false
	_credits_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_credits_box)


## 红字闪烁 duration 秒（默认按策划案 0.8s，每 0.16s 明灭一次）
func flash_warning(duration := 0.8) -> void:
	_warning.visible = true
	var elapsed := 0.0
	var on := true
	while elapsed < duration:
		_warning.modulate.a = 1.0 if on else 0.15
		on = not on
		await get_tree().create_timer(0.16).timeout
		elapsed += 0.16
	_warning.visible = false
	_warning.modulate.a = 1.0


## 黑幕淡入（alpha → 1）。可 await。
func fade_to_black(time := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, time)
	await tw.finished


## 黑幕淡出（alpha → 0）。可 await。
func fade_from_black(time := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 0.0, time)
	await tw.finished


func is_black() -> bool:
	return _black.color.a > 0.95


## 结局第一幕：白底细体「欢迎回家」淡入 → 停留 hold 秒 → 淡出。可 await。
func show_welcome(hold := 4.0) -> void:
	_welcome.visible = true
	_welcome.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_welcome, "modulate:a", 1.0, 1.5)
	tw.tween_interval(hold)
	tw.tween_property(_welcome, "modulate:a", 0.0, 1.5)
	await tw.finished
	_welcome.visible = false


## 结局第二幕：黑底 Staff 片尾，字幕从下往上滚 duration 秒，随后淡出。可 await。
func play_credits(lines: Array, duration := 24.0) -> void:
	for child in _credits_box.get_children():
		child.queue_free()
	for line in lines:
		var l := Label.new()
		l.text = str(line)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if line is String and (line as String).begins_with("#"):
			l.add_theme_font_override("font", _pixel_font)
			l.add_theme_font_size_override("font_size", 40)
			l.add_theme_color_override("font_color", Color(0.9, 0.88, 0.85))
			l.text = (line as String).substr(1)
		else:
			l.add_theme_font_override("font", _pixel_font)
			l.add_theme_font_size_override("font_size", 24)
			l.add_theme_color_override("font_color", Color(0.62, 0.6, 0.58))
		_credits_box.add_child(l)

	# 先把整摞字幕放到屏幕下方，再匀速滚上去
	_credits_box.visible = true
	_credits_box.reset_size()
	await get_tree().process_frame
	var total_h := _credits_box.size.y
	_credits_box.position.y = get_viewport().get_visible_rect().size.y
	var tw := create_tween()
	tw.tween_property(_credits_box, "position:y", -total_h, duration)
	await tw.finished
	var fade := create_tween()
	fade.tween_property(_credits_box, "modulate:a", 0.0, 1.5)
	await fade.finished
	_credits_box.visible = false
	_credits_box.modulate.a = 1.0
