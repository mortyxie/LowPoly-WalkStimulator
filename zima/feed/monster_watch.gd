extends Node

## 偷吃 / 交付事件 → 屋里那只「怪」的反应。
## 只负责把事件转给 group "feed_monster" 里的怪物节点（bitkiln 的 MonsterBrain）。
## 用 active 开关控制：平时冻着站着不动，偷吃就醒过来追人，交付完再冻回去。

const MONSTER_GROUP := &"feed_monster"
const PLAYER_GROUP := &"player"

## 偷吃时怪物喊的话
@export var angry_line := "快点送来……别让我亲自去找你。"
## 交给房东后补的台词（留空则不说）
@export var calm_line := ""
## 两次触发之间的最短间隔（秒）
@export var cooldown := 4.0

var _cooldown_left := 0.0


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta


## 玩家自己把食物吃掉时调用
func on_player_ate(item_name: String = "食物") -> void:
	if _cooldown_left > 0.0:
		return
	_cooldown_left = cooldown

	MessageBanner.show_message("「%s」" % angry_line, Color(1.0, 0.28, 0.22), 2.5)

	var monster := get_tree().get_first_node_in_group(MONSTER_GROUP)
	if monster == null:
		return
	monster.set("active", true)
	if monster.has_method("hunt"):
		var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
		if player != null:
			monster.call("hunt", player, true)


## 把食物交给房东时调用：安抚回去，继续装死
func on_food_delivered() -> void:
	_cooldown_left = 0.0
	var monster := get_tree().get_first_node_in_group(MONSTER_GROUP)
	if monster == null:
		return
	monster.set("active", false)
	if monster.has_method("play_animation"):
		monster.call("play_animation", &"Idle", true)
	if not calm_line.is_empty():
		MessageBanner.show_message("「%s」" % calm_line, Color(0.85, 0.85, 0.85), 2.0)
