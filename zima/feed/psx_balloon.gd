extends CanvasLayer
## 极简对话气球：纯白字、一根白线框、完全透明底。不再用 ps1_rpg_menu 的渐变窗口。
## Dialogue Manager 只要一个 start() 方法，其余都是自己的事。

const PIXEL_FONT: FontFile = preload("res://assets/fonts/fusion-pixel-12px-zh_hans.ttf")

## 美术按 1x 画（240 像素高的画面），整个 UI 放大这个整数倍，像素才不糊。
const ART_SCALE := 3.0
## 字号必须是 12 的整数倍（像素字是 12px 点阵）。
const FONT_SIZE := 12
## 文本框离屏幕左、右、下各多少美术像素。
const BOX_MARGIN := 8
## 框内四边的留白。
const PADDING := 6
## 边框粗细（美术像素）。
const BORDER := 1
## 每秒打出几个字。
const TYPE_SPEED := 32.0
## 正文和选项之间的缝。
const CHOICE_GAP := 3

var dialogue_resource: DialogueResource
var dialogue_line: DialogueLine
var temporary_game_states: Array = []
var is_waiting_for_input := false
var will_block_other_input := true
var next_action: StringName = &"ui_accept"
var skip_action: StringName = &"ui_cancel"

var _root: MarginContainer
var _holder: VBoxContainer
var _panel: PanelContainer
var _content: VBoxContainer
var _name_label: Label
var _text_label: Label
var _arrow: Label
var _choices_box: VBoxContainer

var _line: DialogueLine
var _choices: Array = []
var _buttons: Array[Button] = []
var _focus := 0

var _typing := false
var _typed := 0.0
var _blink := 0.0


func _ready() -> void:
	layer = 20
	_build_ui()
	visible = false


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.name = "Art"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_theme_constant_override(&"margin_left", BOX_MARGIN)
	root.add_theme_constant_override(&"margin_top", BOX_MARGIN)
	root.add_theme_constant_override(&"margin_right", BOX_MARGIN)
	root.add_theme_constant_override(&"margin_bottom", BOX_MARGIN)
	add_child(root)
	_root = root

	_holder = VBoxContainer.new()
	_holder.name = "Holder"
	_holder.alignment = BoxContainer.ALIGNMENT_END
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_holder)

	# 透明底 + 一根白线：除了边框什么都不画
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(1, 1, 1, 1)
	style.set_border_width_all(BORDER)
	style.set_content_margin_all(PADDING)
	style.anti_aliasing = false

	_panel = PanelContainer.new()
	_panel.name = "Frame"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override(&"panel", style)
	_holder.add_child(_panel)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override(&"separation", 2)
	_panel.add_child(_content)

	_name_label = Label.new()
	_name_label.name = "Speaker"
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_label(_name_label)
	_content.add_child(_name_label)

	_text_label = Label.new()
	_text_label.name = "Text"
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_setup_label(_text_label)
	_content.add_child(_text_label)

	_arrow = Label.new()
	_arrow.name = "NextMark"
	_arrow.text = "▼"
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_label(_arrow)
	_content.add_child(_arrow)

	_choices_box = VBoxContainer.new()
	_choices_box.name = "Choices"
	_choices_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices_box.add_theme_constant_override(&"separation", CHOICE_GAP)
	_content.add_child(_choices_box)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _setup_label(label: Label) -> void:
	label.add_theme_font_override(&"font", PIXEL_FONT)
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))


func _layout() -> void:
	if not is_instance_valid(_root):
		return
	_root.scale = Vector2(ART_SCALE, ART_SCALE)
	_root.size = get_viewport().get_visible_rect().size / ART_SCALE


## 开始一段对话，Dialogue Manager 会调这个。
func start(resource: DialogueResource = null, cue := "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	if resource != null:
		dialogue_resource = resource
	if dialogue_resource == null:
		push_warning("PsxBalloon: 没有 dialogue_resource")
		queue_free()
		return
	_layout()
	show()
	dialogue_line = await dialogue_resource.get_next_dialogue_line(cue, temporary_game_states)
	_show_line(dialogue_line)


func _show_line(line: DialogueLine) -> void:
	_line = line
	if line == null:
		_close()
		return
	_clear_choices()
	var speaker := "" if line.character.is_empty() else tr(line.character, "dialogue")
	_name_label.text = speaker
	_name_label.visible = not speaker.is_empty()
	_text_label.text = tr(line.text, "dialogue")
	_text_label.visible_characters = 0
	_typed = 0.0
	_typing = true
	_arrow.visible = false
	_panel.visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	if _typing:
		_typed += TYPE_SPEED * delta
		_text_label.visible_characters = int(_typed)
		if _typed >= float(_text_label.get_total_character_count()):
			_finish_typing()
		return
	if _arrow.visible:
		_blink += delta
		if _blink >= 0.45:
			_blink = 0.0
			_arrow.modulate.a = 0.0 if _arrow.modulate.a > 0.5 else 1.0


func _finish_typing() -> void:
	_typing = false
	_text_label.visible_characters = -1
	if _line == null:
		return
	_collect_choices()
	if _choices.is_empty():
		_arrow.visible = true
		_blink = 0.0
		_arrow.modulate.a = 1.0
		is_waiting_for_input = true
	else:
		_arrow.visible = false
		_show_choices()


func _collect_choices() -> void:
	_choices.clear()
	for response in _line.responses:
		if response.is_allowed:
			_choices.append(response)


func _show_choices() -> void:
	_clear_choices()
	_focus = 0
	for i in _choices.size():
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_override(&"font", PIXEL_FONT)
		button.add_theme_font_size_override(&"font_size", FONT_SIZE)
		for key in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
			button.add_theme_color_override(key, Color.WHITE)
		var empty := StyleBoxEmpty.new()
		for key in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			button.add_theme_stylebox_override(key, empty)
		button.pressed.connect(_on_choice_pressed.bind(i))
		button.mouse_entered.connect(_set_focus.bind(i))
		_choices_box.add_child(button)
		_buttons.append(button)
	_refresh_choice_text()
	is_waiting_for_input = true
	# 选项多行时让框跟着长高
	_panel.queue_sort()


func _refresh_choice_text() -> void:
	for i in _buttons.size():
		var mark := "> " if i == _focus else "  "
		_buttons[i].text = mark + tr(_choices[i].text, "dialogue")


func _clear_choices() -> void:
	for button in _buttons:
		if is_instance_valid(button):
			button.queue_free()
	_buttons.clear()


func _set_focus(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	_focus = index
	_refresh_choice_text()


func _move_focus(step: int) -> void:
	if _buttons.is_empty():
		return
	_set_focus(wrapi(_focus + step, 0, _buttons.size()))


func _on_choice_pressed(index: int) -> void:
	if index < 0 or index >= _choices.size():
		return
	is_waiting_for_input = false
	_clear_choices()
	_go(_choices[index].next_id)


func _accept() -> void:
	if _typing:
		_finish_typing()
		return
	if not is_waiting_for_input:
		return
	if not _buttons.is_empty():
		_on_choice_pressed(_focus)
		return
	is_waiting_for_input = false
	_go(_line.next_id)


func _go(next_id: String) -> void:
	if next_id.is_empty():
		_close()
		return
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)
	_show_line(dialogue_line)


func _close() -> void:
	_line = null
	dialogue_line = null
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(next_action):
		_accept()
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_right"):
		_move_focus(1)
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_left"):
		_move_focus(-1)
	if will_block_other_input:
		get_viewport().set_input_as_handled()
