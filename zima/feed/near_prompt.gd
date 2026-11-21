extends CanvasLayer

## NearPrompt（自动加载单例）
## 玩家靠近可交互物时的持续提示 UI（屏幕底部居中）。
## 与 MessageBanner（浮现后淡出）不同：只要还在范围内就一直显示。
## 用法（多区域可同时注册，按 id 区分，文本去重）：
##   NearPrompt.show_prompt("food_1", "[鼠标左键] 拾取食物")
##   NearPrompt.hide_prompt("food_1")

const FONT_SIZE := 30

var _entries: Dictionary = {}  # id -> text
var _label: Label


func _ready() -> void:
	layer = 80

	var cjk_font := SystemFont.new()
	cjk_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "SimSun", "sans-serif"])

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_label = Label.new()
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 48.0
	_label.offset_right = -48.0
	_label.offset_top = -170.0
	_label.offset_bottom = -96.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 多条提示拼接后可能超过一行，自动换行兜底
	_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_label.add_theme_font_override("font", cjk_font)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 10)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_label)


func show_prompt(id: String, text: String) -> void:
	_entries[id] = text
	_refresh()


func hide_prompt(id: String) -> void:
	_entries.erase(id)
	_refresh()


func _refresh() -> void:
	var seen := {}
	var parts: Array[String] = []
	for text in _entries.values():
		if not seen.has(text):
			seen[text] = true
			parts.append(text)
	_label.text = "    ".join(parts)
