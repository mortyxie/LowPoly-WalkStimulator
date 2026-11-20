class_name FeedLandlordNPC
extends StaticBody3D

## 房东 NPC（占位长方体，后续由美术替换正式模型，占位高度已对齐相机视线）。
## 职责边界（重要）：
##   - 本脚本【不做任何输入轮询】。左键交付由 camera_interact.gd 统一仲裁后
##     调用 try_deliver()，与食物拾取互斥（一次点击只发生一个动作）。
##   - 房东不属于 feed_food 组，永远不会被"拾取"。
## 功能：
##   靠近 + 手持食物 → 底部提示「[鼠标左键] 交给房东」，左键交付
##   shout() → 台词以红色大字浮现在玩家屏幕中上方
## 后续「没按时喂食/偷拿物品」的触发逻辑只需调用 shout() / shout_random_line()。

@export var display_name := "房东"
## 威胁/催促台词池，超时触发时随机抽一条
@export var shout_lines: Array[String] = [
	"快点送来！",
	"别以为我没发现……把东西交出来！",
	"今晚之前，我要看到它！",
	"你最好想清楚后果！",
]
## 收到食物时说的台词（留空则不喊）
@export var thanks_line := "这才像话……别让我等下一次！"

var _player_near := false
@onready var _prompt_id := "landlord_%d" % get_instance_id()
@onready var _zone: Area3D = $PickupZone


func _ready() -> void:
	add_to_group("feed_landlord")
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
	# 只负责靠近提示（何时交付由相机仲裁）
	if _player_near and _get_carried_food() != null:
		NearPrompt.show_prompt(_prompt_id, "[鼠标左键] 交给%s" % display_name)
	else:
		NearPrompt.hide_prompt(_prompt_id)


## 供相机仲裁查询：玩家是否在本房东感应区内
func is_player_near() -> bool:
	return _player_near


## 由相机仲裁调用：把手持食物交给房东。成功返回 true。
func try_deliver() -> bool:
	if not _player_near:
		return false
	var food := _get_carried_food()
	if food == null:
		return false
	_receive_food(food)
	return true


func _get_carried_food() -> Node3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var item = cam.get("carried_item")
	return item if item != null else null


func _receive_food(food: Node3D) -> void:
	var cam := get_viewport().get_camera_3d()
	cam.set("carried_item", null)
	NearPrompt.hide_prompt(_prompt_id)
	MessageBanner.show_message("你把食物交给了%s。" % display_name, Color(0.55, 0.9, 1.0))
	MonsterWatch.on_food_delivered()
	if not thanks_line.is_empty():
		shout(thanks_line)
	food.queue_free()


func shout(text: String = "") -> void:
	if text.is_empty():
		text = shout_random_line()
	MessageBanner.show_message("%s：%s" % [display_name, text], Color(1.0, 0.28, 0.22), 3.0)


func shout_random_line() -> String:
	return shout_lines.pick_random() if not shout_lines.is_empty() else "……"


## 供相机 [E] 键测试：对准房东按 E 会随机喊一句
func interact() -> void:
	shout()
