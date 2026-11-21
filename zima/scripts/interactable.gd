extends Area3D

signal interacted

@export var display_name := ""
@export var action_text := "查看"
@export var interact_action := "interact"

var _player_inside := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_clear_prompt()

func _physics_process(_delta: float) -> void:
	if _player_inside and not _input_locked() and Input.is_action_just_pressed(interact_action):
		interacted.emit()


## 时机判定小游戏 / 黑屏过渡期间锁住 E 交互
func _input_locked() -> bool:
	var lm := get_tree().root.get_node_or_null("/root/LoopManager")
	return lm != null and lm.get("input_locked") == true


## LoopManager 换轮后刷新脚下提示文字
func refresh_prompt() -> void:
	if _player_inside:
		_set_prompt(_build_prompt())

func _on_body_entered(body: Node3D) -> void:
	if body is not CharacterBody3D:
		return
	_player_inside = true
	_set_prompt(_build_prompt())

func _on_body_exited(body: Node3D) -> void:
	if body is not CharacterBody3D:
		return
	_player_inside = false
	_clear_prompt()

func _build_prompt() -> String:
	var text := "按 F " + action_text
	if display_name != "":
		text += " · " + display_name
	return text

func _set_prompt(t: String) -> void:
	var label := get_tree().get_first_node_in_group("prompt_label")
	if label == null:
		push_error("prompt_label group not found")
		return
	label.text = t
	if label.has_method("get_all_actions_in_text"):
		label.og_text = t
		label.actions = label.get_all_actions_in_text()

func _clear_prompt() -> void:
	_set_prompt("")
