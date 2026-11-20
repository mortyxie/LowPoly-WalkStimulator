class_name FeedFoodItem
extends RigidBody3D

## 食物道具（占位长方体，后续由美术替换正式模型）。
## 职责边界（重要）：
##   - 本脚本【不做任何输入轮询】。左键拾取由 camera_interact.gd 统一仲裁后
##     调用 pick_up()，避免与房东交付在同一次点击里同时触发。
##   - 只有本组（feed_food）节点能被拾取，房东等场景物不受影响。
## 交互流程：
##   靠近（PickupZone 感应到玩家）→ 底部提示「[鼠标左键] 拾取食物」
##   左键（由相机仲裁）→ 挂到相机变成第一人称手持
##   手持中靠近房东 → 左键交给房东；右键 → 自己吃掉

## 拿起后显示在准星提示里的名字
@export var item_name := "食物"
## 吃掉后屏幕上浮现的文字
@export var consume_text := "你偷偷把食物吃掉了……"

## 相机下的手持偏移（右/下/前），按占位方块 0.45m 调校
const HAND_OFFSET := Vector3(0.38, -0.38, -0.8)

var _carried := false
var _player_near := false
@onready var _prompt_id := "food_%d" % get_instance_id()
@onready var _zone: Area3D = $PickupZone


func _ready() -> void:
	add_to_group("feed_food")
	_zone.body_entered.connect(_on_zone_entered)
	_zone.body_exited.connect(_on_zone_exited)


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
	queue_free()


func _player_is_carrying() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.get("carried_item") != null


func _attach(by: Node3D) -> void:
	reparent(by)
	transform = Transform3D.IDENTITY
	position = HAND_OFFSET
	rotation = Vector3.ZERO
