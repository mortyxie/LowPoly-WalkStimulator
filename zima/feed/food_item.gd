class_name FeedFoodItem
extends RigidBody3D

## 食物道具：占位的黄色方块已换成 PSX 低模食物（默认披萨一角，可换成吐司 / 豆子罐头）。
## 职责边界（重要）：
##   - 本脚本【不做任何输入轮询】。左键拾取由 camera_interact.gd 统一仲裁后
##     调用 pick_up()，避免与房东交付在同一次点击里同时触发。
##   - 只有本组（feed_food）节点能被拾取，房东等场景物不受影响。
##   - 模型由脚本在 _ready 里实例化并自动居中、按包围盒调整碰撞盒，
##     所以换模型只改 model_scene / model_scale，不用手调碰撞。
## 交互流程：
##   靠近（PickupZone 感应到玩家）→ 底部提示「[鼠标左键] 拾取食物」
##   左键（由相机仲裁）→ 挂到相机变成第一人称手持
##   手持中靠近房东 → 左键交给房东；右键 → 自己吃掉

## 拿起后显示在准星提示里的名字
@export var item_name := "食物"
## 吃掉后屏幕上浮现的文字
@export var consume_text := "你偷偷把食物吃掉了……"

@export_group("模型")
## 换个食物就在这里拖一个 glb 场景进来，留空用默认的披萨一角
@export var model_scene: PackedScene
## 运行时按路径指定模型（LoopManager 随机刷食物种类用），优先级高于 model_scene。
## 文件缺失时照样回退黄方块，不会拖垮工程。
@export var model_override_path := ""
## 原模型只有 0.15~0.33 m，放大一点才看得清拿在手上的样子
@export var model_scale := 1.4

## 相机下的手持偏移（右/下/前），按 0.3 m 左右的食物调校
const HAND_OFFSET := Vector3(0.38, -0.38, -0.8)
## 默认模型用运行时 load 而不是 preload：这些 glb 被 gitignore 了，
## 队友 clone 下来没有文件时不能把整个脚本拖成解析错误。
const DEFAULT_MODEL_PATH := "res://feed/food_models/food_pizza.glb"
## 碰撞盒最小边，免得薄片模型变成一张没厚度的纸
const MIN_COLLISION := 0.06

var _carried := false
var _player_near := false

@onready var _prompt_id := "food_%d" % get_instance_id()
@onready var _zone: Area3D = $PickupZone
@onready var _model: Node3D = $Model
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("feed_food")
	_build_model()
	_zone.body_entered.connect(_on_zone_entered)
	_zone.body_exited.connect(_on_zone_exited)


## 实例化模型、居中、按包围盒配碰撞盒，再套上和其他场景物一样的 PSX 材质
func _build_model() -> void:
	var packed: PackedScene = model_scene
	# 运行时指定的路径优先（食物点位池随机换种类用）
	if not model_override_path.is_empty() and ResourceLoader.exists(model_override_path):
		packed = load(model_override_path) as PackedScene
	if packed == null and ResourceLoader.exists(DEFAULT_MODEL_PATH):
		# 先 exists 再 load：文件不存在时 load 会自己打一条 Resource file not found 的 ERROR
		packed = load(DEFAULT_MODEL_PATH) as PackedScene
	if packed == null:
		push_warning("FeedFoodItem: 找不到食物模型 %s（这批 glb 被 gitignore，按 feed/food_models/README.md 补齐）" % DEFAULT_MODEL_PATH)
		_build_fallback()
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		push_warning("FeedFoodItem: 模型不是 3D 场景，跳过")
		return
	model.name = "ModelMesh"
	model.scale = Vector3.ONE * model_scale
	_model.add_child(model)
	_center_model(model)
	# 世界树是在 main.gd 里一次性转 PSX 材质的，运行时机加的模型要自己转一遍
	PSX.convert(model)
	PSX.apply_ps1(model)


## 一个模型都没有时（clone 下来没补 glb）用的黄方块占位，保证食物还能看见、能捡
func _build_fallback() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "FallbackMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.1, 0.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.7, 0.2)
	box.material = mat
	mi.mesh = box
	_model.add_child(mi)
	_center_model(mi)
	PSX.convert(mi)
	PSX.apply_ps1(mi)


## 把模型的重心挪到节点原点，并把碰撞盒改成模型的实际大小
func _center_model(model: Node3D) -> void:
	var box := _model_aabb(model)
	if box.size == Vector3.ZERO:
		return
	var center := box.get_center()
	model.position -= center
	box.position -= center
	var shape := _collision.shape
	if shape is BoxShape3D:
		# 场景里的 shape 是共享资源，先复制一份再改，否则三个食物会互相覆盖尺寸
		var own: BoxShape3D = (shape as BoxShape3D).duplicate()
		own.size = Vector3(
			maxf(box.size.x, MIN_COLLISION),
			maxf(box.size.y, MIN_COLLISION),
			maxf(box.size.z, MIN_COLLISION))
		_collision.shape = own
	_collision.position = Vector3.ZERO


## 模型在 _model 节点坐标系里的总包围盒（按八个角精确换算，避免旋转后算小）
func _model_aabb(model: Node3D) -> AABB:
	var acc := AABB()
	var first := true
	var base := _model.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xf := base * mi.global_transform
		var local := mi.mesh.get_aabb()
		for i in 8:
			var corner := local.position + Vector3(
				local.size.x * float(i & 1),
				local.size.y * float((i >> 1) & 1),
				local.size.z * float((i >> 2) & 1))
			var point := xf * corner
			if first:
				acc = AABB(point, Vector3.ZERO)
				first = false
			else:
				acc = acc.expand(point)
	return acc


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
	# 只负责靠近提示（能否拾取、何时拾取由相机仲裁）
	if _player_near and not _player_is_carrying():
		NearPrompt.show_prompt(_prompt_id, "[鼠标左键] 拾取%s" % item_name)
	else:
		NearPrompt.hide_prompt(_prompt_id)


## 供相机仲裁查询：玩家是否在本食物感应区内
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
	_zone.set_deferred("monitoring", false)
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_attach.call_deferred(by)


## 由相机调用：吃掉
func consume() -> void:
	MessageBanner.show_message(consume_text, Color(1.0, 0.82, 0.35))
	var watch := get_tree().root.get_node_or_null("/root/MonsterWatch")
	if watch != null and watch.has_method(&"on_player_ate"):
		watch.call(&"on_player_ate", item_name)
	queue_free()


func _player_is_carrying() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.get("carried_item") != null


func _attach(by: Node3D) -> void:
	reparent(by)
	transform = Transform3D.IDENTITY
	position = HAND_OFFSET
	rotation = Vector3.ZERO
