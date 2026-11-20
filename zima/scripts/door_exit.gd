extends Node3D

## 假门触发器: 按 interact 之后淡黑、播音效、传送或切场景。

@export var next_scene := ""
@export var player_node: Node3D
@export var target_node: Node3D
@export var door_sound: AudioStream
@export var fade_time := 1.0

var _fade: ColorRect
var _busy := false

func _ready() -> void:
	var area := get_node_or_null("InteractionArea")
	if area == null:
		push_error("door_exit: missing InteractionArea child")
		return
	area.interacted.connect(_on_interacted)
	_make_fade()

func _make_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	_fade = rect

func _on_interacted() -> void:
	if _busy:
		return
	_busy = true
	_play_sound()
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, fade_time)
	tween.tween_callback(_after_fade)

func _after_fade() -> void:
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
		return
	if target_node and player_node:
		player_node.global_position = target_node.global_position
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, fade_time)
	_busy = false

func _play_sound() -> void:
	if door_sound == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = door_sound
	add_child(p)
	p.play()
