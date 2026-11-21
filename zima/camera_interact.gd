extends Camera3D

## 第一人称相机：鼠标视角 + 交互中枢（本项目唯一持有视角逻辑的地方）
##
## 重要：3D 世界在 SubViewport 里（PSX 渲染），SubViewport 内节点的
## _input() 收不到输入事件！因此本脚本全部用「轮询」：
##   - 鼠标位移：根层 MouseLook autoload 收集，这里 take_motion() 消费
##   - 按键：Input.is_action_just_pressed() 轮询
##
## 输入仲裁（重要）：左键的「拾取」和「交给房东」在这里统一裁决，
## 一次点击【最多执行一个动作】，优先级：交付 > 拾取。
## 食物/房东脚本不做任何输入轮询，只暴露 is_player_near() 和动作接口。
## 只有 feed_food 组的节点能被拾取，房东等场景物永远不会被拿起来。
##
## 操作：
##   鼠标移动 → 视角（yaw 转玩家身体，pitch 转相机自身）
##   点击窗口 → 捕获鼠标；ESC → 释放
##   [F]    → 与准星目标交互
##   [左键] → 靠近食物：拾取；手持食物靠近房东：交付（互斥）
##   [右键] → 吃掉手持中的食物

@export var ray_distance: float = 3.0
@export var prompt_label: Label
@export var mouse_sensitivity := 3.0
@export var pitch_limit := 89.0

var hit_target: Node3D = null
var carried_item: Node3D = null
var _pitch := 0.0
var _player: CharacterBody3D


func _ready() -> void:
	# 相机可能直接挂在 Player 下，也可能隔一层 pivot——向上遍历找玩家身体
	var n: Node = self
	while n:
		n = n.get_parent()
		if n is CharacterBody3D:
			_player = n
			break
	if _player == null:
		push_error("camera_interact: 未找到 CharacterBody3D 玩家，鼠标视角的 yaw 将失效")
	# 启动即捕获鼠标（ESC 释放，点击窗口再捕获）
	_set_captured(true)


func _process(_delta: float) -> void:
	# 手里拿的东西可能被 LoopManager 重置时释放，先自愈引用
	if carried_item != null and not is_instance_valid(carried_item):
		carried_item = null
	_handle_look()
	_handle_capture()
	_update_raycast_and_prompt()
	_handle_interactions()


func _handle_look() -> void:
	if _is_input_locked():
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := MouseLook.take_motion()
	if motion == Vector2.ZERO:
		return
	if _player:
		_player.rotate_y(-motion.x * mouse_sensitivity / 1000.0)
	_pitch = clampf(
		_pitch - motion.y * mouse_sensitivity / 1000.0,
		deg_to_rad(-pitch_limit),
		deg_to_rad(pitch_limit)
	)
	rotation.x = _pitch


func _handle_capture() -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_set_captured(Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED)
	elif Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED \
			and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_set_captured(true)


func _update_raycast_and_prompt() -> void:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = global_position
	var ray_end = global_position + global_transform.basis.z * -ray_distance

	var query = PhysicsRayQueryParameters3D.new()
	query.from = ray_origin
	query.to = ray_end
	query.exclude = [_player.get_rid()] if _player else []
	if carried_item is CollisionObject3D:
		query.exclude.append(carried_item.get_rid())

	var result = space_state.intersect_ray(query)
	hit_target = result["collider"] if result else null

	if prompt_label:
		prompt_label.text = _build_prompt()


func _build_prompt() -> String:
	if carried_item:
		if carried_item.is_in_group("feed_weapon"):
			return "[鼠标左键] 交给房东"
		if carried_item.is_in_group("feed_key") or carried_item.is_in_group("feed_lockpick"):
			return "[右键] 藏起来"
		var display_name: String = carried_item.item_name if "item_name" in carried_item else "物品"
		return "[右键] 吃掉 %s" % display_name
	if hit_target and (hit_target.is_in_group("feed_food") or hit_target.is_in_group("feed_weapon") \
			or hit_target.is_in_group("feed_key") or hit_target.is_in_group("feed_lockpick")):
		return "[鼠标左键] 拾取"
	if hit_target and hit_target.is_in_group("feed_box"):
		return "[F] 破坏盒子"
	if hit_target and hit_target.is_in_group("feed_door"):
		var lm := get_tree().root.get_node_or_null("/root/LoopManager")
		if lm != null and lm.has_method(&"door_prompt_text"):
			return "[F] %s" % lm.call(&"door_prompt_text")
	if hit_target and hit_target.has_method("interact"):
		return "[F] 查看"
	return ""


func _handle_interactions() -> void:
	if _is_input_locked():
		return
	if Input.is_action_just_pressed("interact") and hit_target != null \
			and hit_target.has_method("interact") and hit_target != carried_item:
		hit_target.interact()

	# ---- 左键仲裁：一次点击最多一个动作，交付优先于拾取 ----
	if Input.is_action_just_pressed("pickup"):
		var acted := false
		# 1) 手持食物且靠近房东 → 交付（找最近的近处房东）
		if carried_item != null:
			for landlord in _nearest_near("feed_landlord", 1):
				if landlord.has_method("try_deliver") and landlord.try_deliver():
					acted = true
					break
		# 2) 空手且靠近可拾取物 → 拾取（找最近的近处目标）
		if not acted and carried_item == null:
			var item := _nearest_near_any([&"feed_food", &"feed_weapon", &"feed_key", &"feed_lockpick"], 1)
			if not item.is_empty() and item[0].has_method("pick_up"):
				try_pick_up(item[0])
	# ---- 右键：轮回 1 = 吃掉食物；轮回 2 起 = 藏匿（策划案：右键仅轮回 2 解锁） ----
	if Input.is_action_just_pressed("consume"):
		if carried_item != null:
			if _hide_unlocked() and not carried_item.is_in_group("feed_food"):
				_try_hide_carried()
			elif _hide_unlocked():
				# 轮回 2 起，食物也不许再偷吃，只能藏
				_try_hide_carried()
			elif carried_item.is_in_group("feed_food"):
				_consume_carried()
			else:
				MessageBanner.show_message("这东西不能吃。", Color(0.85, 0.85, 0.85), 1.5)
		else:
			MessageBanner.show_message(
				"手上没有东西——先走近物品，按鼠标左键拿起。",
				Color(0.85, 0.85, 0.85), 1.6)


## 轮回 2 起解锁「藏匿」，同时锁掉偷吃（持续投喂压力）
func _hide_unlocked() -> bool:
	var lm := get_tree().root.get_node_or_null("/root/LoopManager")
	return lm != null and lm.current_loop >= 2


func _try_hide_carried() -> void:
	var lm := get_tree().root.get_node_or_null("/root/LoopManager")
	if lm == null or not lm.has_method(&"hide_carried_item"):
		return
	lm.call(&"hide_carried_item", self, carried_item)
	carried_item = null


## 时机判定小游戏 / 黑屏过渡期间锁住一切输入
func _is_input_locked() -> bool:
	var lm := get_tree().root.get_node_or_null("/root/LoopManager")
	return lm != null and lm.get("input_locked") == true


## 在 group 组里找出「玩家在感应区内」的节点，按距离从近到远排序取前 count 个
func _nearest_near(group: String, count: int) -> Array:
	return _nearest_near_any([group], count)


## 同上，但一次扫多个组（食物 + 刀具）
func _nearest_near_any(groups: Array, count: int) -> Array:
	var candidates: Array = []
	for group in groups:
		for n in get_tree().get_nodes_in_group(group):
			if n.has_method("is_player_near") and n.is_player_near():
				if not candidates.has(n):
					candidates.append(n)
	candidates.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	return candidates.slice(0, count)


func _set_captured(on: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE)


# ---- 供食物/房东调用的接口 ----

## 靠近感应区（PickupZone）在玩家左键时调用
func try_pick_up(item: Node3D) -> void:
	if carried_item != null:
		return
	carried_item = item
	if item.has_method("pick_up"):
		item.pick_up(self)


func _consume_carried() -> void:
	var item := carried_item
	carried_item = null
	if item.has_method("consume"):
		item.consume()
