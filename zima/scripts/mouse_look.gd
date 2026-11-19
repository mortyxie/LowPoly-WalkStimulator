extends Node

## 全局收鼠标位移。因为它不在 SubViewport 里, 能收到主窗口的事件。

var motion := Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		motion += event.relative

func take_motion() -> Vector2:
	var m := motion
	motion = Vector2.ZERO
	return m

func set_captured(on: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE)
