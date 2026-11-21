class_name QuestItem
extends RigidBody3D

## 剧情道具（假钥匙 / 撬锁器）：跟食物、武器同一套交互
## （靠近提示 → 左键拾取 → 手持），由 camera_interact.gd 统一仲裁。
## 视觉：
##   - 假钥匙：直接借用 COGITO（addons/cogito，MIT）pickup_key.tscn 的
##     金色程序化网格（美术正式钥匙未到位前的临时方案）；载入失败回退自绘。
##   - 撬锁器：策划案规格——细长圆柱 + 黑色材质。
## 本脚本【不做任何输入轮询】。

@export_enum("key", "lockpick") var kind := "key"
@export var item_name := "假钥匙"

const GLOW_SCRIPT := preload("res://feed/glow_highlight.gd")

## 相机下的手持偏移
const HAND_OFFSET := Vector3(0.35, -0.32, -0.75)
const ZONE_RADIUS := 1.6

# COGITO 钥匙的网格与材质参数（照抄 pickup_key.tscn）
const KEY_GOLD := Color(1.0, 0.709804, 0.329412)
const LOCKPICK_BLACK := Color(0.05, 0.05, 0.05)

var _carried := false
var _player_near := false
var _prompt_id: String


func _ready() -> void:
	freeze = true
	add_to_group("feed_key" if kind == "key" else "feed_lockpick")
	_prompt_id = "quest_%d" % get_instance_id()
	_build_body()
	_build_zone()
	_apply_psx()
	# 房间太暗：加自发光呼吸高亮，保证一眼能看见
	var glow: Node3D = GLOW_SCRIPT.new()
	glow.glow_color = Color(1.0, 0.82, 0.4) if kind == "key" else Color(0.55, 0.85, 1.0)
	add_child(glow)


func _build_body() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)

	var mat := StandardMaterial3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape := BoxShape3D.new()

	if kind == "key":
		item_name = "假钥匙"
		shape.size = Vector3(0.15, 0.05, 0.3)
		if not _build_key_from_cogito(model):
			_build_key_fallback(model, mat)
	else:
		item_name = "撬锁器"
		# 细长圆柱 + 黑色材质（策划案规格）
		mat.albedo_color = LOCKPICK_BLACK
		mat.metallic = 0.3
		mat.roughness = 0.55
		var rod := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.015
		cyl.bottom_radius = 0.015
		cyl.height = 0.3
		cyl.material = mat
		rod.mesh = cyl
		rod.rotation = Vector3(0, 0, deg_to_rad(90))  # 躺平
		model.add_child(rod)

		shape.size = Vector3(0.3, 0.04, 0.04)

	col.shape = shape
	col.name = "CollisionShape3D"
	add_child(col)


## 临时方案：借用 COGITO pickup_key.tscn 的视觉网格（金色金属钥匙）。
## 只搬 MeshInstance3D，丢弃它的脚本 / 拾取组件 / 碰撞（那些依赖 COGITO 玩家）。
func _build_key_from_cogito(model: Node3D) -> bool:
	var packed: PackedScene = load("res://addons/cogito/PackedScenes/Pickups/pickup_key.tscn")
	if packed == null:
		return false
	var inst := packed.instantiate()
	var moved := 0
	for child in inst.get_children().duplicate():
		if child is MeshInstance3D:
			child.skeleton = NodePath()  # 原场景里的 skeleton 指向兄弟节点，搬走后清掉
			child.get_parent().remove_child(child)
			model.add_child(child)
			moved += 1
	inst.free()
	return moved > 0


## 回退：按 pickup_key 参数自绘（与 COGITO 同款网格/材质），载入失败才走这里
func _build_key_fallback(model: Node3D, mat: StandardMaterial3D) -> void:
	mat.albedo_color = KEY_GOLD
	mat.metallic = 0.9
	mat.metallic_specular = 0.8
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.03, 0.25)
	box.material = mat
	shaft.mesh = box
	model.add_child(shaft)
	var teeth := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.05, 0.05, 0.025)
	prism.material = mat
	teeth.mesh = prism
	teeth.position = Vector3(0, 0.035, 0.135)
	model.add_child(teeth)
	var bow := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.1
	cyl.height = 0.04
	cyl.material = mat
	bow.mesh = cyl
	bow.rotation = Vector3(deg_to_rad(90), 0, 0)
	bow.position = Vector3(0, 0, -0.145)
	model.add_child(bow)


func _build_zone() -> void:
	var zone := Area3D.new()
	zone.name = "PickupZone"
	var zc := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = ZONE_RADIUS
	zc.shape = sphere
	zone.add_child(zc)
	add_child(zone)
	zone.body_entered.connect(_on_zone_entered)
	zone.body_exited.connect(_on_zone_exited)


## 世界树在 main.gd 里一次性转 PSX 材质，运行时生成的道具要自己转一遍
func _apply_psx() -> void:
	if not has_node("Model"):
		return
	PSX.convert(get_node("Model"))
	PSX.apply_ps1(get_node("Model"))


func _on_zone_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_near = true


func _on_zone_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_player_near = false
		NearPrompt.hide_prompt(_prompt_id)


func _process(_delta: float) -> void:
	if _carried:
		return
	if _player_near and not _player_is_carrying():
		NearPrompt.show_prompt(_prompt_id, "[鼠标左键] 拾取%s" % item_name)
	else:
		NearPrompt.hide_prompt(_prompt_id)


## 供相机仲裁查询
func is_player_near() -> bool:
	return _player_near and not _carried


## 由相机调用：挂到相机下变成手持
func pick_up(by: Node3D) -> void:
	if _carried:
		return
	_carried = true
	_player_near = false
	NearPrompt.hide_prompt(_prompt_id)
	MessageBanner.show_message("你拿起了%s" % item_name, Color(1.0, 0.82, 0.35), 1.2)
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_attach.call_deferred(by)


func _player_is_carrying() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.get("carried_item") != null


func _attach(by: Node3D) -> void:
	reparent(by)
	transform = Transform3D.IDENTITY
	position = HAND_OFFSET
	rotation = Vector3.ZERO
