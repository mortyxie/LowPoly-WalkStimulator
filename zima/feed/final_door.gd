class_name FinalDoor
extends Node3D

## 最左边的大门（z≈-3 墙最左侧那扇）：
##   - 轮回 1：锁得死死的（提示）
##   - 轮回 2：拿假钥匙开 → 声响暴露强制剧情 → 解锁轮回 3
##   - 轮回 3：手持撬锁器 → 撬锁小游戏 → 成功 → 结局演出
## 交互走脚本内 Area3D + interactable.gd（按 F），提示文字按轮回动态刷新。
## 节点由 LoopManager 在代码里生成。

const GLOW_SCRIPT := preload("res://feed/glow_highlight.gd")

@export var action_by_loop := {
	1: "试试大门",
	2: "用假钥匙开门",
	3: "撬锁",
}

var _area: Area3D


func _ready() -> void:
	add_to_group("feed_door")

	# 门板占位（深色木门 + 暗金属锁孔块；正式模型等美术）
	var mi := MeshInstance3D.new()
	mi.name = "DoorMesh"
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 2.25, 0.09)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.11, 0.08)
	box.material = mat
	mi.mesh = box
	mi.position = Vector3(0, 1.2, 0)
	add_child(mi)

	var lock := MeshInstance3D.new()
	var lock_mesh := BoxMesh.new()
	lock_mesh.size = Vector3(0.1, 0.16, 0.04)
	var lock_mat := StandardMaterial3D.new()
	lock_mat.albedo_color = Color(0.55, 0.5, 0.42)
	lock_mat.metallic = 0.7
	lock_mesh.material = lock_mat
	lock.mesh = lock_mesh
	lock.position = Vector3(-0.45, 1.0, 0.05)
	add_child(lock)

	PSX.convert(mi)
	PSX.apply_ps1(mi)
	PSX.convert(lock)
	PSX.apply_ps1(lock)

	# 房间太暗：幽青色信标强闪，隔半个客厅就能找到这扇门
	var glow: Node3D = GLOW_SCRIPT.new()
	glow.glow_color = Color(0.5, 1.0, 0.85)
	glow.light_range = 4.5
	glow.light_height = 1.2
	add_child(glow)

	# 交互区（复用项目统一的 interactable.gd，按 F 触发）
	_area = Area3D.new()
	_area.name = "InteractionArea"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2.3, 1.4)
	col.shape = shape
	col.position = Vector3(0, 1.2, 0)
	_area.add_child(col)
	_area.set_script(load("res://scripts/interactable.gd"))
	add_child(_area)
	_area.interacted.connect(_on_interacted)


func _on_interacted() -> void:
	var lm := get_tree().root.get_node_or_null("/root/LoopManager")
	if lm == null or not lm.has_method(&"on_final_door_interact"):
		MessageBanner.show_message("门锁得死死的。", Color(0.85, 0.85, 0.85), 1.6)
		return
	lm.call(&"on_final_door_interact")


## LoopManager 换轮后刷新脚下提示
func refresh_action_text() -> void:
	if _area == null:
		return
	var lm := get_tree().root.get_node_or_null("/root/LoopManager")
	var loop: int = lm.current_loop if lm != null else 1
	_area.action_text = str(action_by_loop.get(loop, "试试大门"))
	_area.refresh_prompt()
