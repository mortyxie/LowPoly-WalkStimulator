extends Node

## LoopManager（自动加载单例）：三轮轮回的总管理。
##   轮回 1（启蒙）：刀 + 斧子固定刷新；上交任意一件凶器 + 全程按时投喂
##     → 该凶器永久消失，解锁轮回 2。
##   轮回 2（陷阱）：只剩未上交的武器，右键解锁「藏匿」；核心解谜 = 破盒
##     （黑底轨道 400px、暗红滑块 24×12、绿区 60px、周期 4.2s、命中 3 次）
##     → 得假钥匙 → 拿假钥匙开最左边大门 = 声响暴露（强制剧情）→ 解锁轮回 3。
##   轮回 3（终局）：刀斧全清空；撬锁器（细长圆柱黑材质）
##     + COGITO 沉浸式撬锁小游戏 → 开最左边大门 → 结局演出。
## 失败重置规则：只重置当前轮回（食物重新随机、本轮目标还原），
## 已上交的凶器不复活；所有失败分支统一走【我看到你了】红字警示。

signal loop_started(loop: int)

const FOOD_SCENE := preload("res://feed/food_item.tscn")
const KNIFE_SCENE := preload("res://feed/weapon_knife.tscn")
const AXE_SCENE := preload("res://feed/weapon_axe.tscn")
const TIMING_GAME_SCRIPT := preload("res://feed/timing_minigame.gd")
const LOOP_UI_SCRIPT := preload("res://feed/loop_ui.gd")
const MYSTERY_BOX_SCRIPT := preload("res://feed/mystery_box.gd")
const FINAL_DOOR_SCRIPT := preload("res://feed/final_door.gd")
const QUEST_ITEM_SCRIPT := preload("res://feed/quest_item.gd")
## 轮回 3 大门撬锁：直接复用 COGITO 的第一人称沉浸式撬锁小游戏
## （鼠标找甜点 + D 键转锁芯 + 撬锁会断 + 动画音效，addons/cogito MIT）
const LOCKPICK_SCENE := preload("res://addons/cogito/PackedScenes/CogitoLockpickMinigame.tscn")

## 玩家出生点（已实测落地稳定）
const SPAWN_POINT := Vector3(-1.95, 0.53, -6.14)
## 刀 / 斧子的固定刷新点（原 zima_demo.tscn 位置）
const KNIFE_POS := Vector3(-6.934, 1.131, -14.142)
const AXE_POS := Vector3(0.796, 1.203, -15.732)
## 神秘盒子（table4 桌面）
const BOX_POS := Vector3(-6.73, 0.52, -6.7)
## 最左边大门（z≈-3 墙最左段）
const FINAL_DOOR_POS := Vector3(-8.5, 0.0, -3.0)
## 撬锁器刷新点（大门附近地板）
const LOCKPICK_POS := Vector3(-9.6, 0.06, -4.2)

## 全局 8 个固定食物点位（轮内随机取 3-4 个）
const FOOD_SPOTS: Array[Vector3] = [
	Vector3(2.4397, 1.24, 1.1086),   # 餐桌（原 FoodItem1）
	Vector3(3.45, 1.21, -1.5),       # 长桌（原 FoodItem2）
	Vector3(-0.97, 1.2, -2.5),       # 矮桌（原 FoodItem3）
	Vector3(-6.73, 0.55, -6.7),      # 西侧小方桌
	Vector3(-7.02, 0.85, -10.5),     # 北侧长凳桌
	Vector3(1.0, 0.06, -10.0),       # 北屋地板
	Vector3(-9.5, 0.06, -4.5),       # 西门附近地板
	Vector3(-4.3, 0.06, -14.5),      # 北屋墙角
]

## 食物种类池（种类随机 = 换 food_item 的模型路径；glb 缺失时自动回退占位方块）
const FOOD_KINDS := [
	{"name": "披萨", "path": "res://feed/food_models/food_pizza.glb"},
	{"name": "吐司", "path": "res://feed/food_models/food_toast.glb"},
	{"name": "巧克力", "path": "res://feed/food_models/food_chocolate.glb"},
	{"name": "薯片", "path": "res://feed/food_models/food_chips.glb"},
	{"name": "可乐", "path": "res://feed/food_models/food_can_cola.glb"},
	{"name": "芬达", "path": "res://feed/food_models/food_can_fanta.glb"},
	{"name": "豆子罐头", "path": "res://feed/food_models/food_can_beans.glb"},
]

## 时机判定参数（策划案精确值）
const BOX_GAME := {
	"title": "破坏盒子",
	"track_width": 400.0,
	"slider_size": Vector2(24, 12),
	"green_width": 60.0,
	"period": 4.2,
	"hits_required": 3,
}
## 撬锁难度（COGITO CogitoLockpickGame 参数）：甜点宽度越大越容易
@export var lockpick_sweet_spot_range := 12.0
## 撬锁耐久上限（越大越不容易断；断了自己换，不消耗道具）
@export var lockpick_health_max := 8.0

const CREDITS_LINES := [
	"#ZIMA",
	"",
	"—— 一个关于按时喂饱房东的故事 ——",
	"",
	"游戏设计 / 关卡 / 程序",
	"ZIMA 团队",
	"",
	"怪物模型",
	"bitkiln · PSX Sea Horror Monsters",
	"",
	"食物模型",
	"Nicowlas · PSX Kitchen Props Pack",
	"Fanix Studio · PSX Survival Items",
	"",
	"钥匙与工具",
	"COGITO (Phazorknight) · MIT",
	"",
	"插件",
	"Dialogue Manager / Godot Retro",
	"Footstepper / Quick Audio",
	"",
	"特别鸣谢",
	"每一个准时投喂的乖孩子",
]

# —— 每轮状态 ——
var current_loop := 0
## 过场 / 小游戏期间锁住玩家输入（camera_interact、interactable 轮询此值）
var input_locked := false
## 已上交（永久消失）的凶器：["knife", "axe"]
var weapons_handed := []
## 被玩家藏匿的凶器（轮回 2 起右键藏匿；本轮不再刷出）
var hidden_weapons := []
## 是否持有假钥匙（轮回 2 剧情道具）
var has_fake_key := false

## 喂食压力：喂食阶段多久没吃到就重置当前轮（秒）
@export var feed_timeout := 45.0
## 轮回 1：交完凶器后还需要按时喂几顿才解锁下一轮
@export var loop1_feeds_required := 2
## 轮回 1：房东要收几件凶器（任意一件即可）
@export var loop1_required_weapons := 1

var _world: Node3D
var _landlord: Node3D
var _player: Node3D
var _game: TimingMinigame
var _ui: CanvasLayer
var _box: Node3D
var _door: Node3D
var _spawned: Array[Node] = []

var _feeding_active := false
var _feed_left := 0.0
var _loop1_weapon_done := false
var _loop1_feeds := 0
var _transitioning := false
var _ending := false

# COGITO 撬锁小游戏（轮回 3）
var _lockpick_game: Node3D
var _lockpick_result := false
var _lockpick_done := false


func _ready() -> void:
	randomize()
	_game = TIMING_GAME_SCRIPT.new()
	add_child(_game)
	_ui = LOOP_UI_SCRIPT.new()
	add_child(_ui)
	_late_setup.call_deferred()


func _late_setup() -> void:
	_world = _find_world()
	_landlord = get_tree().get_first_node_in_group(&"feed_landlord")
	_player = get_tree().get_first_node_in_group(&"player")

	# 场景里摆死的食物 / 武器改为由本管理器按轮刷新（避免双份）
	if _world != null:
		for n in _world.get_children():
			if n.name.begins_with("FoodItem") or n.name.begins_with("Weapon"):
				n.queue_free()

	_build_props()

	# 快速体验模式（验收/演示用，不用从轮回 1 打起）：
	#   --loop2  直接进轮回 2，玩家传送到神秘盒子旁，喂食压力放宽到 5 分钟
	#   --loop3  直接进轮回 3，玩家传送到大门口（撬锁器就在旁边发光）
	var user_args := OS.get_cmdline_user_args()
	if "--loop3" in user_args:
		feed_timeout = 300.0
		start_loop(3)
		_place_player(Vector3(-8.5, 0.6, -3.6))
	elif "--loop2" in user_args:
		feed_timeout = 300.0
		start_loop(2)
		_place_player(BOX_POS + Vector3(0.9, 0.1, 1.1))
	else:
		start_loop(1)

	# 自动化测试钩子：godot --path zima -- --autotest
	if "--autotest" in OS.get_cmdline_user_args():
		var test: Node = load("res://tests/autotest.gd").new()
		add_child(test)


func _build_props() -> void:
	if _world == null:
		return
	_box = StaticBody3D.new()
	_box.set_script(MYSTERY_BOX_SCRIPT)
	_world.add_child(_box)
	_box.position = BOX_POS

	_door = Node3D.new()
	_door.set_script(FINAL_DOOR_SCRIPT)
	_world.add_child(_door)
	_door.position = FINAL_DOOR_POS
	_door.rotation.y = deg_to_rad(90.0)  # 门板贴在 z≈-3 墙面上


# ============================================================
# 轮回启动 / 重置
# ============================================================

func start_loop(n: int) -> void:
	current_loop = n
	_clear_spawned()
	has_fake_key = false
	_loop1_weapon_done = false
	_loop1_feeds = 0
	_feed_left = feed_timeout
	_feeding_active = false
	_game.force_close()

	# 房东按当轮配置重置
	if _landlord != null and _landlord.has_method(&"reset_for_loop"):
		match n:
			1:
				_landlord.call(&"reset_for_loop", 0, loop1_required_weapons, true)   # 收刀阶段
			2, 3:
				_landlord.call(&"reset_for_loop", 1, 0, false)                        # 喂食阶段，不再收武器

	# 轮次专属物件
	match n:
		1:
			_spawn_weapon(&"knife")
			_spawn_weapon(&"axe")
		2:
			# 只剩没上交、也没被藏起来的那把
			for id in [&"knife", &"axe"]:
				if not weapons_handed.has(id) and not hidden_weapons.has(id):
					_spawn_weapon(id)
		3:
			_spawn_quest(&"lockpick", LOCKPICK_POS)

	if _box != null:
		_box.visible = (n == 2)
		if n == 2 and _box.has_method(&"reset"):
			_box.call(&"reset")

	_spawn_food()
	_refresh_door_prompt()

	match n:
		1:
			MessageBanner.show_message("【轮回 1 · 启蒙】把一件凶器交给房东，然后按时喂饱他。", Color(0.85, 0.85, 0.9), 4.0)
		2:
			MessageBanner.show_message("【轮回 2 · 陷阱】屋里藏着个神秘盒子……弄一把能骗过锁孔的钥匙。", Color(0.85, 0.85, 0.9), 4.0)
		3:
			MessageBanner.show_message("【轮回 3 · 终局】刀斧都没了……找个撬锁工具，打开最左边的大门。", Color(0.85, 0.85, 0.9), 4.0)

	loop_started.emit(n)


## 失败：红字警示（可选）→ 黑屏 → 重置当前轮
func fail_loop(reason := "", with_warning := true) -> void:
	if _transitioning or _ending or current_loop == 0:
		return
	_transitioning = true
	input_locked = true
	_pause_player(true)
	_game.force_close()

	if with_warning:
		await _ui.flash_warning()
	if not reason.is_empty():
		MessageBanner.show_message(reason, Color(1.0, 0.28, 0.22), 2.5)

	await _ui.fade_to_black(0.7)
	await get_tree().create_timer(0.4).timeout
	start_loop(current_loop)
	_pause_player(false)
	input_locked = false
	_transitioning = false
	await _ui.fade_from_black(0.7)


## 完成当前轮 → 解锁下一轮（轮回 1 → 2 专用；2 → 3 走假钥匙暴露剧情）
func complete_loop() -> void:
	if _transitioning or _ending:
		return
	_transitioning = true
	input_locked = true
	_pause_player(true)

	MessageBanner.show_message("……看起来他满意了。", Color(0.55, 0.9, 1.0), 2.5)
	await get_tree().create_timer(1.5).timeout
	await _ui.fade_to_black(1.0)
	start_loop(current_loop + 1)
	_pause_player(false)
	input_locked = false
	_transitioning = false
	await _ui.fade_from_black(1.0)


# ============================================================
# 事件回调（由 landlord / box / door / camera 转发）
# ============================================================

## 房东收到凶器：记录永久消失；轮回 1 检查目标完成
func on_weapon_handed(item: Node3D) -> void:
	var id := _weapon_id(item)
	if id != &"" and not weapons_handed.has(id):
		weapons_handed.append(id)
	if current_loop == 1:
		_loop1_weapon_done = true
		_check_loop1_done()


## 房东吃到食物：喂食计时清零；轮回 1 计顿数
func on_food_delivered() -> void:
	_feed_left = feed_timeout
	if current_loop == 1:
		_loop1_feeds += 1
		_check_loop1_done()


func _check_loop1_done() -> void:
	if current_loop == 1 and _loop1_weapon_done and _loop1_feeds >= loop1_feeds_required:
		complete_loop()


## 玩家右键藏匿（轮回 2 起解锁）：手里的东西被藏起来，本轮不再出现
func hide_carried_item(_cam: Node, item: Node3D) -> void:
	if item == null:
		return
	var id := _weapon_id(item)
	if id != &"" and not hidden_weapons.has(id):
		hidden_weapons.append(id)
	var display: String = item.item_name if "item_name" in item else "东西"
	MessageBanner.show_message("你把%s藏了起来——现在没人能看见它。" % display, Color(0.7, 0.85, 0.7), 2.2)
	item.queue_free()


## 神秘盒子被按 F
func on_box_interact(box: Node3D) -> void:
	if _transitioning or _ending:
		return
	if current_loop != 2:
		MessageBanner.show_message("……现在碰它没有任何反应。", Color(0.85, 0.85, 0.85), 1.8)
		return
	var ok: bool = await run_minigame(BOX_GAME)
	if ok:
		box.call(&"break_open")
		has_fake_key = true
		_spawn_quest(&"key", box.global_position + Vector3(0.45, 0.1, 0.35))
	else:
		fail_loop("滑块脱手了。")


## 最左边大门被按 F
func on_final_door_interact() -> void:
	if _transitioning or _ending:
		return
	match current_loop:
		1:
			MessageBanner.show_message("大门锁得死死的。", Color(0.85, 0.85, 0.85), 1.8)
		2:
			if has_fake_key:
				_fake_key_exposure()
			else:
				MessageBanner.show_message("锁孔的形状不对——这不是大门的钥匙。", Color(0.85, 0.85, 0.85), 2.0)
		3:
			_try_lockpick()


func _try_lockpick() -> void:
	if not _carrying_group(&"feed_lockpick"):
		MessageBanner.show_message("门把手上全是锈——需要一根细长的撬锁工具。", Color(0.85, 0.85, 0.85), 2.2)
		return
	var ok: bool = await run_lockpick_game()
	if ok:
		_play_ending()
	else:
		# Esc 主动退出：不算失败，可以再按 F 重试
		MessageBanner.show_message("你收回了撬锁器……大门还在等你。", Color(0.85, 0.85, 0.85), 2.0)


## COGITO 沉浸式撬锁：挂到相机下 → 鼠标位移桥接（SubViewport 收不到 _input）
## → 等 unlocked / cancelled。撬断由 lockpick_broke 自动续撬（不消耗道具）。
func run_lockpick_game() -> bool:
	input_locked = true
	_pause_player(true)
	var cam := _get_cam()
	if cam == null or not is_instance_valid(cam):
		input_locked = false
		_pause_player(false)
		return false

	_lockpick_game = LOCKPICK_SCENE.instantiate()
	_lockpick_game.default_sweet_spot_range = lockpick_sweet_spot_range
	_lockpick_game.lockpick_health_max = lockpick_health_max
	cam.add_child(_lockpick_game)
	_lockpick_result = false
	_lockpick_done = false

	_lockpick_game.connect(&"unlocked", _on_lockpick_finished.bind(true))
	_lockpick_game.connect(&"cancelled", _on_lockpick_finished.bind(false))
	_lockpick_game.connect(&"lockpick_broke", _on_lockpick_broke)

	# 自动化测试钩子：headless 下无法手玩，直接走解锁动画
	if "--autotest" in OS.get_cmdline_user_args():
		_lockpick_game.call_deferred(&"unlock_lock")

	while not _lockpick_done:
		await get_tree().process_frame

	if _lockpick_game != null and is_instance_valid(_lockpick_game):
		_lockpick_game.queue_free()
	_lockpick_game = null
	input_locked = false
	_pause_player(false)
	return _lockpick_result


func _on_lockpick_finished(ok: bool) -> void:
	_lockpick_result = ok
	_lockpick_done = true


func _on_lockpick_broke() -> void:
	# 剧情道具经济从简：撬断自动换一根
	if _lockpick_game != null and is_instance_valid(_lockpick_game):
		_lockpick_game.call(&"grab_new_lockpick")


## 时机小游戏统一入口：锁输入 → 等结果 → 还原。失败由调用方 fail_loop。
func run_minigame(cfg: Dictionary) -> bool:
	input_locked = true
	_pause_player(true)
	var success: bool = await _game.start_and_wait(cfg)
	input_locked = false
	_pause_player(false)
	return success


func door_prompt_text() -> String:
	match current_loop:
		2:
			return "用假钥匙开门" if has_fake_key else "试试大门"
		3:
			return "撬锁"
		_:
			return "试试大门"


# ============================================================
# 剧情演出
# ============================================================

## 轮回 2：假钥匙插进大门 → 声响暴露（强制剧情）→ 解锁轮回 3
func _fake_key_exposure() -> void:
	if _transitioning or _ending:
		return
	_transitioning = true
	input_locked = true
	_pause_player(true)
	has_fake_key = false
	_free_carried()

	MessageBanner.show_message("「咔哒。」——锁开了？", Color(0.55, 0.9, 1.0), 2.0)
	await get_tree().create_timer(1.4).timeout
	MessageBanner.show_message("门后传来一声巨响——整栋房子都醒了。", Color(1.0, 0.28, 0.22), 2.5)
	if _landlord != null and _landlord.has_method(&"react_angry"):
		_landlord.call(&"react_angry")
	await get_tree().create_timer(1.6).timeout

	await _ui.flash_warning()
	await _ui.fade_to_black(0.8)
	start_loop(3)
	_pause_player(false)
	input_locked = false
	_transitioning = false
	await _ui.fade_from_black(0.8)


## 轮回 3 终局：黑屏 → 「欢迎回家」→ Staff 片尾
func _play_ending() -> void:
	if _ending:
		return
	_ending = true
	_transitioning = true
	input_locked = true
	_pause_player(true)
	_game.force_close()

	await _ui.fade_to_black(2.0)
	await get_tree().create_timer(0.5).timeout
	await _ui.show_welcome(4.0)          # 纯白细体淡入，停留 3-5 秒（取 4s）
	await get_tree().create_timer(0.6).timeout
	await _ui.play_credits(CREDITS_LINES, 22.0)
	# 停在黑屏：片尾结束，交给玩家（ESC 退出 / 截图）
	input_locked = false


# ============================================================
# 喂食压力（持续投喂）
# ============================================================

func _process(delta: float) -> void:
	# COGITO 撬锁小游戏在 SubViewport 里收不到 _input，由这里（根层 autoload，
	# 早于场景树处理）消费 MouseLook 的鼠标位移并直接喂给它的 _input。
	# 顺带这会让相机的 take_motion() 拿到 0——撬锁期间视角正好锁定。
	if _lockpick_game != null and is_instance_valid(_lockpick_game):
		var motion: Vector2 = MouseLook.take_motion()
		if motion != Vector2.ZERO:
			var ev := InputEventMouseMotion.new()
			ev.relative = motion
			_lockpick_game._input(ev)

	if current_loop == 0 or _transitioning or _ending:
		return
	if _landlord == null or not is_instance_valid(_landlord):
		return
	# 房东在喂食阶段才计时（收刀阶段食物会被拒收，不计压力）
	if int(_landlord.get("phase")) == 1:
		_feed_left -= delta
		if _feed_left <= 0.0:
			fail_loop("喂食超时——他等得不耐烦了。")
	else:
		_feed_left = feed_timeout


# ============================================================
# 生成 / 清理
# ============================================================

func _spawn_weapon(id: StringName) -> void:
	if _world == null:
		return
	var scene: PackedScene = KNIFE_SCENE if id == &"knife" else AXE_SCENE
	var item := scene.instantiate()
	_world.add_child(item)
	item.global_position = KNIFE_POS if id == &"knife" else AXE_POS
	_spawned.append(item)


## 每轮食物：8 个固定点位随机刷 3-4 份不重复，种类随机
func _spawn_food() -> void:
	if _world == null:
		return
	var count := randi_range(3, 4)
	var spots := FOOD_SPOTS.duplicate()
	spots.shuffle()
	for i in count:
		var kind: Dictionary = FOOD_KINDS.pick_random()
		var item := FOOD_SCENE.instantiate()
		item.item_name = kind["name"]
		item.model_override_path = kind["path"]
		_world.add_child(item)
		item.global_position = spots[i]
		_spawned.append(item)


## 剧情道具（假钥匙 / 撬锁器）
func _spawn_quest(kind: StringName, pos: Vector3) -> void:
	if _world == null:
		return
	var body := RigidBody3D.new()
	body.set_script(QUEST_ITEM_SCRIPT)
	body.collision_layer = 3
	body.collision_mask = 3
	# kind 必须在入树前设好（_ready 按它生成模型）
	body.kind = String(kind)
	_world.add_child(body)
	body.global_position = pos
	_spawned.append(body)


func _clear_spawned() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	# 手里拿的东西也一并清掉（它可能已被 queue_free）
	var cam := _get_cam()
	if cam != null:
		var it = cam.get("carried_item")
		if it != null:
			cam.set("carried_item", null)
			if is_instance_valid(it):
				it.queue_free()


func _refresh_door_prompt() -> void:
	if _door != null and is_instance_valid(_door) and _door.has_method(&"refresh_action_text"):
		_door.call(&"refresh_action_text")


func _reset_player() -> void:
	if _player != null and is_instance_valid(_player):
		_player.global_position = SPAWN_POINT
		_player.set("velocity", Vector3.ZERO)


## 快速体验模式用：直接把玩家放到指定位置
func _place_player(pos: Vector3) -> void:
	if _player != null and is_instance_valid(_player):
		_player.global_position = pos
		_player.set("velocity", Vector3.ZERO)


func _pause_player(on: bool) -> void:
	if _player != null and is_instance_valid(_player):
		_player.set_physics_process(not on)


func _free_carried() -> void:
	var cam := _get_cam()
	if cam == null:
		return
	var it = cam.get("carried_item")
	if it != null:
		cam.set("carried_item", null)
		if is_instance_valid(it):
			it.queue_free()


func _carrying_group(group: StringName) -> bool:
	var cam := _get_cam()
	if cam == null:
		return false
	var it = cam.get("carried_item")
	return it != null and is_instance_valid(it) and it.is_in_group(group)


## 3D 世界在 SubViewport 里：LoopManager 在根层，必须经玩家节点找相机
func _get_cam() -> Camera3D:
	if _player != null and is_instance_valid(_player):
		return _player.get_viewport().get_camera_3d()
	return null


func _weapon_id(item: Node3D) -> StringName:
	if item == null or not is_instance_valid(item):
		return &""
	match String(item.get("item_name")):
		"刀":
			return &"knife"
		"斧头":
			return &"axe"
		_:
			return &""


func _find_world() -> Node3D:
	var vps := get_tree().root.find_children("*", "SubViewport", true, false)
	for vp in vps:
		for child in vp.get_children():
			if child is Node3D:
				return child
	return null
