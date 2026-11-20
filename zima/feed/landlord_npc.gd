class_name FeedLandlordNPC
extends StaticBody3D

## 房东 = 渔夫本体。三段流程：
##   1) 先把玩家手里的刀、斧头哄骗着收走（一开始语气很好）
##   2) 收齐后进入喂食阶段，玩家交付食物
##   3) 拖延 / 偷吃越多，语气越凶，最后露本性
## 本脚本【不轮询输入】：左键交付由 camera_interact.gd 统一仲裁后调用 try_deliver()。

const PHASE_ASK := 0
const PHASE_FEED := 1

@export var display_name := "房东"

@export_group("流程")
## 当前阶段，检查器里可以直接切（0 收刀 / 1 喂食）
@export_enum("收刀阶段:0", "喂食阶段:1") var phase := 0
## 需要上交的刀具/斧头数量，场景里放几把就填几
@export var required_weapons := 2
## 喂食阶段多久没吃到东西就催一次（秒），<= 0 关掉
@export var nag_interval := 45.0
## 压力值到这个数就彻底露本性（偷吃 +1、每次催促 +1）
@export var menacing_threshold := 3

@export_group("台词 · 收刀阶段")
@export var ask_weapon_lines: Array[String] = [
	"这是为了你和其他人的安全。",
	"哦，好孩子。",
	"没错就是这样。",
]
@export var weapon_thanks_lines: Array[String] = [
	"对，就这样。",
	"乖孩子。",
	"这才听话。",
]
@export var reject_food_line := "先把不安全的东西都交上来，再品味美食。"
@export var phase_up_line := "好了，刀都在我这儿了…… 现在，我饿了。"
@export var steal_in_ask_line := "……你刚才，是不是偷吃了？先把刀交出来。"

@export_group("台词 · 喂食阶段")
@export var food_gentle_lines: Array[String] = [
	"……谢谢。放这儿吧。",
	"嗯，今天还算准时。",
]
@export var food_impatient_lines: Array[String] = [
	"你看我像有耐心的样子吗？",
	"我数三下。",
	"别让我站起来。",
]
@export var food_menacing_lines: Array[String] = [
	"我要的东西呢！！！",
	"快点！",
	"废物！这都做不好",
]

@export_group("外观与动画")
## 房东本体模型（渔夫 drowned_oilskin.glb 实例）
@export var model: Node3D
## 模型动画播放器
@export var animation_player: AnimationPlayer
## 待机循环动画
@export var idle_animation: StringName = &"Idle"
## 吃东西时播一次（包里没有进食动作，暂用 Attack 当啃咬）
@export var eat_animation: StringName = &"Attack"
## 生气/被偷吃时播一次
@export var angry_animation: StringName = &"Retch"

var weapons_given := 0
var food_given := 0
var pressure := 0

var _nag_left := 0.0
var _ask_cooldown := 0.0
var _player_near := false

@onready var _prompt_id := "landlord_%d" % get_instance_id()
@onready var _zone: Area3D = $PickupZone


func _ready() -> void:
	add_to_group("feed_landlord")
	_zone.body_entered.connect(_on_zone_entered)
	_zone.body_exited.connect(_on_zone_exited)
	_play_loop(idle_animation)


func _process(delta: float) -> void:
	if _ask_cooldown > 0.0:
		_ask_cooldown -= delta
	_tick_nag(delta)

	if _player_near and _get_carried() != null:
		NearPrompt.show_prompt(_prompt_id, "[鼠标左键] 交给%s" % display_name)
	else:
		NearPrompt.hide_prompt(_prompt_id)


func _tick_nag(delta: float) -> void:
	if phase != PHASE_FEED or nag_interval <= 0.0:
		return
	_nag_left += delta
	if _nag_left < nag_interval:
		return
	_nag_left = 0.0
	pressure += 1
	shout(_pick(_tone_lines()))


func _on_zone_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return
	_player_near = true
	if phase == PHASE_ASK and _ask_cooldown <= 0.0:
		_ask_cooldown = 10.0
		shout(_pick(ask_weapon_lines))


func _on_zone_exited(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return
	_player_near = false
	NearPrompt.hide_prompt(_prompt_id)


## 供相机仲裁查询：玩家是否在感应区内
func is_player_near() -> bool:
	return _player_near


## 由相机仲裁调用：交付手持物。成功返回 true。
func try_deliver() -> bool:
	if not _player_near:
		return false
	var item := _get_carried()
	if item == null:
		return false

	if item.is_in_group("feed_weapon"):
		_receive_weapon(item)
		return true

	if item.is_in_group("feed_food"):
		if phase == PHASE_ASK:
			shout(reject_food_line)
			return false
		_receive_food(item)
		return true

	return false


func _receive_weapon(item: Node3D) -> void:
	_take_carried()
	weapons_given += 1
	MessageBanner.show_message(
		"你把%s交给了%s。" % [_item_name(item), display_name],
		Color(0.55, 0.9, 1.0))
	shout(_pick(weapon_thanks_lines))
	item.queue_free()

	if phase == PHASE_ASK and weapons_given >= required_weapons:
		phase = PHASE_FEED
		weapons_given = 0
		_nag_left = 0.0
		MessageBanner.show_message(
			"%s：%s" % [display_name, phase_up_line],
			Color(1.0, 0.28, 0.22), 3.0)


func _receive_food(food: Node3D) -> void:
	_take_carried()
	food_given += 1
	_nag_left = 0.0
	MessageBanner.show_message(
		"你把食物交给了%s。" % display_name,
		Color(0.55, 0.9, 1.0))
	MonsterWatch.on_food_delivered()
	_play_once(eat_animation)
	shout(_pick(_tone_lines()))
	food.queue_free()


## 玩家偷吃被听见：涨压力、转头、干呕一下、骂一句
func react_angry() -> void:
	pressure += 1
	_face_player()
	_play_once(angry_animation)
	if phase == PHASE_ASK:
		shout(steal_in_ask_line)
	else:
		shout(_pick(_tone_lines()))


## 对准房东按 E：说一句当前该说的话
func interact() -> void:
	if phase == PHASE_ASK:
		shout(_pick(ask_weapon_lines))
	else:
		shout(_pick(_tone_lines()))


func shout(text: String = "") -> void:
	if text.is_empty():
		text = _pick(_tone_lines())
	MessageBanner.show_message(
		"%s：%s" % [display_name, text],
		Color(1.0, 0.28, 0.22), 3.0)


func shout_random_line() -> String:
	return _pick(_tone_lines())


# ---- 内部工具 ----

## 0 = 还好声好气，1 = 不耐烦，2 = 露本性
func _tone() -> int:
	if pressure >= menacing_threshold:
		return 2
	if pressure > 0 or food_given >= 2:
		return 1
	return 0


func _tone_lines() -> Array[String]:
	match _tone():
		2:
			return food_menacing_lines
		1:
			return food_impatient_lines
		_:
			return food_gentle_lines


func _pick(lines: Array[String]) -> String:
	return lines.pick_random() if not lines.is_empty() else "……"


func _item_name(item: Node) -> String:
	return item.item_name if "item_name" in item else "东西"


func _face_player() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var flat: Vector3 = player.global_position - global_position
	flat.y = 0.0
	if flat.length() < 0.01:
		return
	rotation = Vector3(0, atan2(flat.x, flat.z), 0)

func _get_carried() -> Node3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var item = cam.get("carried_item")
	return item if item != null else null


func _take_carried() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.set("carried_item", null)
	NearPrompt.hide_prompt(_prompt_id)


## 循环播放一个动画（待机用）
func _play_loop(anim: StringName) -> bool:
	if animation_player == null or not animation_player.has_animation(anim):
		return false
	var a := animation_player.get_animation(anim)
	if a != null:
		a.loop_mode = Animation.LOOP_LINEAR
	animation_player.play(anim)
	return true


## 播一次，结束后回到待机
func _play_once(anim: StringName) -> void:
	if animation_player == null or not animation_player.has_animation(anim):
		return
	animation_player.play(anim)
	await animation_player.animation_finished
	_play_loop(idle_animation)

