extends CanvasLayer
## PSX 风格对话气球：用 ps1_rpg_menu 的渐变窗口、名字标签和逐字打字，选项用它的菜单列表。
## 由 Dialogue Manager 的 runtime/balloon_path 设置调用。

const Kit := preload("res://addons/ps1_rpg_menu/menu/kit.gd")
const DialogueBoxScript := preload("res://addons/ps1_rpg_menu/menu/dialogue_box.gd")
const MenuListScript := preload("res://addons/ps1_rpg_menu/menu/menu_list.gd")
const PIXEL_FONT: FontFile = preload("res://assets/fonts/fusion-pixel-12px-zh_hans.ttf")

## 美术按 1x 画（240 像素高的画面），整个 UI 放大这个整数倍，像素才不糊。
const ART_SCALE := 3.0
## 字号必须是 12 的整数倍（缝合像素是 12px 点阵）。
const FONT_SIZE := 12
## 文本框离屏幕左、右、下各多少美术像素。
const BOX_MARGIN := 8
## 文本区显示几行，超出就换行。
const BOX_LINES := 2
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

var _root: Control
var _holder: Control
var _box: Node
var _content: Control
var _menu_holder: Control
var _menu: Node
var _spacer: Control
var _theme: Theme
var _line: DialogueLine
var _choices: Array = []


func _ready() -> void:
	layer = 20

	_theme = Kit.kit_theme("night").duplicate(true)
	_theme.default_font = PIXEL_FONT
	_theme.default_font_size = FONT_SIZE
	_theme.set_font(&"font", &"Label", PIXEL_FONT)
	_theme.set_font_size(&"font_size", &"Label", FONT_SIZE)

	var root := MarginContainer.new()
	root.name = "Art"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.theme = _theme
	root.add_theme_constant_override(&"margin_left", BOX_MARGIN)
	root.add_theme_constant_override(&"margin_top", BOX_MARGIN)
	root.add_theme_constant_override(&"margin_right", BOX_MARGIN)
	root.add_theme_constant_override(&"margin_bottom", BOX_MARGIN)
	add_child(root)
	_root = root

	_holder = VBoxContainer.new()
	_holder.name = "Holder"
	(_holder as BoxContainer).alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(_holder)

	_box = DialogueBoxScript.new()
	_box.name = "DialogueBox"
	_box.set("speed", TYPE_SPEED)
	_box.set("lines", BOX_LINES)
	_box.set("takes_input", false)
	_holder.add_child(_box)
	_box.connect("finished", _on_typing_finished)
	_box.connect("advanced", _on_advance)

	# 窗口（PanelContainer）会把子节点叠在同一块地方，所以正文和选项先塞进一个竖排容器
	_content = VBoxContainer.new()
	_content.name = "Content"
	_box.add_child(_content)
	var text_label: Control = _box.get("text_label")
	text_label.reparent(_content)

	_spacer = Control.new()
	_spacer.name = "Gap"
	_spacer.custom_minimum_size = Vector2(0, CHOICE_GAP)
	_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_spacer)

	_menu = MenuListScript.new()
	_menu.name = "Choices"
	_menu.set("columns", 1)
	_menu.set("sounds", true)
	_menu.set("active", false)
	_menu.visible = false

	# 左边留一条槽，让那块浮动的光标箭头不压到窗口边框和第一个字
	var menu_holder := MarginContainer.new()
	menu_holder.name = "ChoiceGutter"
	menu_holder.add_theme_constant_override(&"margin_left", 10)
	menu_holder.add_theme_constant_override(&"margin_right", 6)
	_content.add_child(menu_holder)
	_menu_holder = menu_holder
	menu_holder.add_child(_menu)
	_menu.connect("chosen", _on_chosen)
	_menu.connect("cancelled", _on_choice_cancelled)

	_box.visible = false
	hide()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	if not is_instance_valid(_root):
		return
	var view: Vector2 = get_viewport().get_visible_rect().size / ART_SCALE
	_root.scale = Vector2(ART_SCALE, ART_SCALE)
	_root.size = view


## 开始一段对话，Dialogue Manager 会调这个。
func start(resource: DialogueResource = null, cue := "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	if resource != null:
		dialogue_resource = resource
	_layout()
	show()
	dialogue_line = await dialogue_resource.get_next_dialogue_line(cue, temporary_game_states)
	_show_line(dialogue_line)


## 显示一行：名字进名字标签，正文逐字打出。
func _show_line(line: DialogueLine) -> void:
	_line = line
	if line == null:
		_close()
		return
	_choices.clear()
	_menu.visible = false
	_menu.call("set", "active", false)
	_box.call("set", "takes_input", true)
	_box.visible = true
	var speaker := "" if line.character.is_empty() else tr(line.character, "dialogue")
	_box.call("say", tr(line.text, "dialogue"), speaker)
	_set_next_mark(_box.call("get_theme_icon", &"next", &"Menu"))


func _on_typing_finished() -> void:
	if _line == null:
		return
	for response in _line.responses:
		if response.is_allowed:
			_choices.append(response)
	if _choices.is_empty():
		is_waiting_for_input = true
		return
	var items: Array = []
	for response in _choices:
		items.append({"text": tr(response.text, "dialogue")})
	_menu.call("set_items", items)
	_menu.visible = true
	_menu.call("set", "active", true)
	_set_next_mark(null)
	_box.call("update_minimum_size")
	_holder.call("queue_sort")
	_box.call("set", "takes_input", false)


## 右下角那个跳动的“下一句”箭头；给 null 就收起来（有选项时用不上）。
func _set_next_mark(texture: Texture2D) -> void:
	var mark := _box.get("next_mark") as TextureRect
	if mark != null:
		mark.texture = texture
		mark.visible = texture != null


func _on_advance() -> void:
	if _line == null:
		return
	is_waiting_for_input = false
	_go(_line.next_id)


func _on_chosen(index: int) -> void:
	if index < 0 or index >= _choices.size():
		return
	is_waiting_for_input = false
	_menu.visible = false
	_menu.call("set", "active", false)
	_box.call("set", "takes_input", false)
	_go(_choices[index].next_id)


func _on_choice_cancelled() -> void:
	pass


func _go(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)
	_show_line(dialogue_line)


func _close() -> void:
	_line = null
	dialogue_line = null
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if will_block_other_input and visible:
		get_viewport().set_input_as_handled()
