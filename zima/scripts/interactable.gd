extends Area3D

## 交互提示区域。挂在 Area3D 上，玩家靠近就显示提示。

signal interacted

@export var prompt_text := "按 {interact} 开门"
@export var interact_action := "interact"

var _player_inside := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_clear_prompt()

func _on_body_entered(body: Node3D) -> void:
	if body is not CharacterBody3D:
		return
	_player_inside = true
	_set_prompt(prompt_text)

func _on_body_exited(body: Node3D) -> void:
	if body is not CharacterBody3D:
		return
	_player_inside = false
	_clear_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event.is_action_pressed(interact_action):
		interacted.emit()
		get_viewport().set_input_as_handled()

func _set_prompt(t: String) -> void:
	var label := get_tree().get_first_node_in_group("prompt_label")
	if label:
		label.text = t

func _clear_prompt() -> void:
	_set_prompt("")
