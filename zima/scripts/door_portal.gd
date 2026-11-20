extends Node3D

## 双向门: SideA 传到 marker_b, SideB 传回 marker_a, 带淡黑过渡。

@export var player_node: Node3D
@export var marker_a: Marker3D
@export var marker_b: Marker3D
@export var fade_time := 1.0
@export var door_sound: AudioStream

var _fade: ColorRect
var _busy := false

func _ready() -> void:
	var side_a := get_node_or_null("SideA")
	var side_b := get_node_or_null("SideB")
	if side_a:
		side_a.interacted.connect(_on_side_a)
	if side_b:
		side_b.interacted.connect(_on_side_b)
	_make_fade()

func _on_side_a() -> void:
	_travel(marker_b)

func _on_side_b() -> void:
	_travel(marker_a)

func _travel(target: Marker3D) -> void:
	if _busy or target == null or player_node == null:
		return
	_busy = true
	_play_sound()
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, fade_time)
	tween.tween_callback(_after_fade.bind(target))

func _after_fade(target: Marker3D) -> void:
	player_node.global_position = target.global_position
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, fade_time)
	_busy = false

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

func _play_sound() -> void:
	if door_sound == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = door_sound
	add_child(p)
	p.play()
