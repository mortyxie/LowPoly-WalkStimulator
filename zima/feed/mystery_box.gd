class_name MysteryBox
extends StaticBody3D

## 神秘盒子（轮回 2 核心解谜道具）：按 F 破盒 → 时机判定小游戏（参数见策划案）
## → 成功掉出假钥匙。盒子本体由 LoopManager 在代码里生成、按轮显示/隐藏。
## 交互走 camera_interact.gd 的准星仲裁（hit_target.has_method("interact")），
## 本脚本不轮询输入。

@export var item_name := "神秘盒子"

const GLOW_SCRIPT := preload("res://feed/glow_highlight.gd")

var _broken := false


func _ready() -> void:
	add_to_group("feed_box")

	# 深色木盒（占位可破坏道具：盒子正式模型等美术，先给个辨识度高的占位）
	var mi := MeshInstance3D.new()
	mi.name = "BoxMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.3, 0.32)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.22, 0.14)
	box.material = mat
	mi.mesh = box
	mi.position = Vector3(0, 0.15, 0)
	add_child(mi)

	# 盖缝线（一条浅色细盒，让它看起来"能开"）
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.44, 0.02, 0.34)
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.5, 0.38, 0.24)
	lid_mesh.material = lid_mat
	lid.mesh = lid_mesh
	lid.position = Vector3(0, 0.26, 0)
	add_child(lid)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.46, 0.32, 0.36)
	col.shape = shape
	col.position = Vector3(0, 0.15, 0)
	add_child(col)

	PSX.convert(mi)
	PSX.apply_ps1(mi)
	PSX.convert(lid)
	PSX.apply_ps1(lid)

	# 房间太暗：加琥珀色呼吸高亮，轮回 2 开场能一眼找到盒子
	var glow: Node3D = GLOW_SCRIPT.new()
	glow.glow_color = Color(1.0, 0.72, 0.3)
	glow.light_range = 2.2
	add_child(glow)


## 准星对准按 F（camera_interact 仲裁）→ 交给 LoopManager 走小游戏流程
func interact() -> void:
	var lm := get_tree().root.get_node_or_null("/root/LoopManager")
	if lm == null or not lm.has_method(&"on_box_interact"):
		MessageBanner.show_message("盒盖纹丝不动。", Color(0.85, 0.85, 0.85), 1.6)
		return
	lm.call(&"on_box_interact", self)


## 破盒成功：盒身换成敞开状态（占位表现），等待美术替换正式"可破坏道具"
func break_open() -> void:
	if _broken:
		return
	_broken = true
	var mi := get_node_or_null("BoxMesh") as MeshInstance3D
	if mi != null:
		mi.rotation.x = deg_to_rad(-70.0)  # 盖子掀开的感觉（占位）
	MessageBanner.show_message("盒盖崩开了——里面躺着一把假钥匙。", Color(1.0, 0.82, 0.35), 3.0)


## LoopManager 重置轮回 2 时调用：恢复成未破状态
func reset() -> void:
	_broken = false
	var mi := get_node_or_null("BoxMesh") as MeshInstance3D
	if mi != null:
		mi.rotation.x = 0.0
