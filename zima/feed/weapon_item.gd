class_name FeedWeaponItem
extends RigidBody3D

## 可上交的刀具 / 斧头（占位薄片，地上摆好后自己换正式模型即可）。
## 跟食物同一套交互：靠近 → 左键拾取 → 手持走近房东 → 左键上交。
## 区别：它属于 feed_weapon 组，右键吃不了，也不进喂食计数。

## 拾取/上交时显示的名字
@export var item_name := "刀"

var _carried := false
var _player_near := false
@onready var _prompt_id := "weapon_%d" % get_instance_id()
@onready var _zone: Area3D = $PickupZone


func _ready() -> void:
	add_to_group("feed_weapon")
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
	_zone.set_deferred("monitoring", false)
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
	position = Vector3(0.35, -0.32, -0.75)
	rotation = Vector3(0, 0, deg_to_rad(-20))
