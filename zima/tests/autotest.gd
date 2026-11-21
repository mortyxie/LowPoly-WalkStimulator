extends Node

## 端到端自动测试（不靠手感）：LoopManager 检测到 --autotest 用户参数时挂载本节点。
## 运行方式：
##   Godot_v4.7.2-stable_win64.exe --headless --path zima -- --autotest
## 覆盖：
##   1) 轮回 1 初始化（食物随机 3-4 份、刀斧固定刷新）
##   2) 轮回 1 目标闭环（上交凶器 + 喂食 → 解锁轮回 2）
##   3) 轮回 2：拾取武器 → 右键藏匿；破盒小游戏「失败分支」
##      （故意按空 → 【我看到你了】→ 黑屏重置轮回 2，食物重新随机）
##   4) 轮回 2：破盒成功 → 假钥匙（E2E 拾取）→ 按 F 开大门 → 暴露剧情 → 轮回 3
##   5) 轮回 3：拾取撬锁器 → 按 F 撬锁 → 小游戏成功 → 结局演出（欢迎回家）

var lm: Node
var _failed := false


func _ready() -> void:
	lm = get_node("/root/LoopManager")
	_run.call_deferred()


func _run() -> void:
	await _wait(0.8)

	# ========== 轮回 1 ==========
	_check(lm.current_loop == 1, "起始为轮回 1")
	var foods := get_tree().get_nodes_in_group("feed_food")
	_check(foods.size() >= 3 and foods.size() <= 4, "食物随机刷 3-4 份（实际 %d）" % foods.size())
	_check(get_tree().get_nodes_in_group("feed_weapon").size() == 2, "轮回 1 刀 + 斧固定刷新")
	_check(lm._box != null and not lm._box.visible, "神秘盒子轮回 1 不出现")
	_check(lm._door != null, "大门节点已生成")

	# 上交凶器（刀）→ 永久消失
	lm.on_weapon_handed(_find_weapon("刀"))
	_check(lm.weapons_handed.has("knife"), "凶器记账：刀永久消失")
	# 按时喂食两顿 → 解锁轮回 2
	lm.on_food_delivered()
	lm.on_food_delivered()
	await _wait_for(func() -> bool: return lm.current_loop == 2, 8.0)
	_check(lm.current_loop == 2, "轮回 1 目标完成 → 解锁轮回 2")

	# ========== 轮回 2 ==========
	await _wait(0.5)
	_check(get_tree().get_nodes_in_group("feed_weapon").size() == 1, "轮回 2 只剩未上交的武器")
	_check(lm._box.visible, "神秘盒子轮回 2 出现")
	foods = get_tree().get_nodes_in_group("feed_food")
	_check(foods.size() >= 3 and foods.size() <= 4, "换轮后食物重新随机（%d 份）" % foods.size())

	# E2E：拾取武器 → 右键藏匿
	var axe := _find_weapon("斧头")
	if axe == null:
		axe = _find_weapon("刀")
	_check(axe != null, "轮回 2 武器存在")
	await _pickup(axe)
	await _wait(0.3)
	await _click(MOUSE_BUTTON_RIGHT)  # 轮回 2 起右键 = 藏匿
	await _wait(0.3)
	_check(not lm.hidden_weapons.is_empty(), "右键藏匿生效（%s 被藏起）" % str(lm.hidden_weapons))
	_check(_carried() == null, "藏匿后手上为空")

	# 失败分支：破盒小游戏故意按空 → 【我看到你了】→ 黑屏重置轮回 2
	var food_ids_before := _food_ids()
	lm.on_box_interact(lm._box)
	await _wait_for(func() -> bool: return lm._game.active, 3.0)
	_check(lm._game.active, "破盒小游戏打开")
	_check(int(lm._game._cfg["green_width"]) == 60 and int(lm._game._cfg["hits_required"]) == 3 \
		and is_equal_approx(float(lm._game._cfg["period"]), 4.2), "破盒参数符合策划案")
	await _press_space_when(func() -> bool: return not _slider_in_green())
	await _wait_for(func() -> bool: return not lm._game.active, 3.0)
	await _wait_for(func() -> bool: return not lm.input_locked, 10.0)
	_check(lm.current_loop == 2, "失败后仍停留在轮回 2（重置当前轮）")
	var food_ids_after := _food_ids()
	_check(_food_ids_changed(food_ids_before, food_ids_after), "重置后食物重新随机刷新")
	_check(lm._box.visible and not lm._box._broken, "盒子恢复未破状态")

	# 成功分支：破盒 → 假钥匙
	lm.on_box_interact(lm._box)
	await _wait_for(func() -> bool: return lm._game.active, 3.0)
	for i in 3:
		await _press_space_when(_slider_in_green)
		await _wait_for(func() -> bool: return lm._game.active, 3.0)
	await _wait_for(func() -> bool: return not lm._game.active, 3.0)
	_check(lm._box._broken, "盒子被破坏")
	_check(lm.has_fake_key, "破盒成功 → 获得假钥匙")
	var key := _find_in_group("feed_key")
	_check(key != null, "假钥匙实体已生成")
	_check(lm.input_locked == false, "小游戏结束后解锁输入")

	# E2E：拾取假钥匙 → 按 F 开大门 → 暴露剧情 → 轮回 3
	if key != null:
		await _pickup(key)
	await _wait(0.3)
	_check(_carried() != null and _carried().is_in_group("feed_key"), "假钥匙已拾取（手持）")
	await _wait_for(func() -> bool: return not lm.input_locked, 5.0)
	_teleport_player(Vector3(-8.5, 0.6, -3.6))
	await _wait_physics_frames(5)
	await _press_key(KEY_F)
	await _wait_for(func() -> bool: return lm.current_loop == 3, 15.0)
	_check(lm.current_loop == 3, "假钥匙开门 → 声响暴露 → 解锁轮回 3")

	# ========== 轮回 3 ==========
	await _wait_for(func() -> bool: return not lm.input_locked, 8.0)
	await _wait(0.5)
	_check(get_tree().get_nodes_in_group("feed_weapon").size() == 0, "轮回 3 刀斧全清空")
	var pick := _find_in_group("feed_lockpick")
	_check(pick != null, "撬锁器已刷新")
	if pick != null:
		await _pickup(pick)
	_check(_carried() != null and _carried().is_in_group("feed_lockpick"), "撬锁器已拾取（手持）")
	await _wait_for(func() -> bool: return not lm.input_locked, 5.0)
	_teleport_player(Vector3(-8.5, 0.6, -3.6))
	await _wait_physics_frames(5)
	await _press_key(KEY_F)
	await _wait_for(func() -> bool: return lm._lockpick_game != null, 5.0)
	_check(lm._lockpick_game != null, "COGITO 撬锁小游戏已打开")
	_check(is_instance_valid(lm._lockpick_game.get_parent()), "撬锁小游戏已挂载到相机")
	# autotest 模式下 run_lockpick_game 会直接调 unlock_lock（headless 无法手玩）
	await _wait_for(func() -> bool: return lm._lockpick_done, 10.0)
	_check(lm._lockpick_result, "撬锁成功 → 解锁信号收到")
	await _wait_for(func() -> bool: return lm._lockpick_game == null, 3.0)
	_check(lm._lockpick_game == null, "撬锁小游戏已清理")
	# 结局演出：黑屏 → 欢迎回家
	await _wait_for(func() -> bool: return lm._ui._welcome.visible, 15.0)
	_check(lm._ui._welcome.visible, "结局演出：欢迎家出现")
	_check(lm._ending, "结局流程启动")

	# ========== 汇总 ==========
	await _wait(1.0)
	if _failed:
		print("AUTOTEST FAILED")
		get_tree().quit(1)
	else:
		print("AUTOTEST ALL PASS")
		get_tree().quit(0)


# ============================================================
# 工具
# ============================================================

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("TEST PASS: ", msg)
	else:
		_failed = true
		print("TEST FAIL: ", msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _wait_for(pred: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if pred.call():
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	print("TEST WARN: 等待超时 %.1fs" % timeout)
	return false


func _wait_physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _slider_in_green() -> bool:
	var g: TimingMinigame = lm._game
	if not g.active:
		return false
	var sw: float = g._cfg["slider_size"].x
	var gw: float = g._cfg["green_width"]
	return g.slider_x <= g.green_x + gw and g.slider_x + sw >= g.green_x


## 轮询等待条件成立时按一次空格（注入合成按键）
func _press_space_when(pred: Callable) -> void:
	var ok := await _wait_for(pred, 8.0)
	if ok:
		await _press_key(KEY_SPACE)


func _press_key(key: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _click(button: MouseButton) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = button
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


## E2E 拾取：传送玩家到道具旁 → 等感应区触发 → 注入左键
func _pickup(item: Node3D) -> void:
	if item == null:
		return
	_teleport_player(item.global_position + Vector3(0, 0.3, 0.6))
	await _wait_physics_frames(6)
	await _click(MOUSE_BUTTON_LEFT)
	await _wait(0.4)


func _teleport_player(pos: Vector3) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.global_position = pos


func _carried() -> Node3D:
	# 相机在 SubViewport 里，从玩家节点所在 viewport 找
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	var cam: Camera3D = player.get_viewport().get_camera_3d()
	if cam == null:
		return null
	return cam.get("carried_item")


func _find_weapon(display_name: String) -> Node3D:
	for w in get_tree().get_nodes_in_group("feed_weapon"):
		if is_instance_valid(w) and String(w.get("item_name")) == display_name:
			return w
	return null


func _find_in_group(group: String) -> Node3D:
	var nodes := get_tree().get_nodes_in_group(group)
	return nodes[0] if not nodes.is_empty() else null


func _food_ids() -> Array[int]:
	var ids: Array[int] = []
	for f in get_tree().get_nodes_in_group("feed_food"):
		if is_instance_valid(f):
			ids.append(f.get_instance_id())
	ids.sort()
	return ids


func _food_ids_changed(a: Array[int], b: Array[int]) -> bool:
	if a.size() != b.size():
		return true
	for i in a.size():
		if a[i] != b[i]:
			return true
	return false
