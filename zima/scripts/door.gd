extends Node3D

## 门。子节点要有一个叫 InteractionArea 的 Area3D, 挂着 interactable.gd。

@export var open_angle := 90.0
@export var open_time := 0.4

var _open := false
var _closed_y := 0.0

func _ready() -> void:
	_closed_y = rotation.y
	var area := get_node_or_null("InteractionArea")
	if area and area.has_signal("interacted"):
		area.interacted.connect(toggle)

func toggle() -> void:
	_open = not _open
	var target_y := _closed_y + (deg_to_rad(open_angle) if _open else 0.0)
	var tween := create_tween()
	tween.tween_property(self, "rotation", Vector3(rotation.x, target_y, rotation.z), open_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
