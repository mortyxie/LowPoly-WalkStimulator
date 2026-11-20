extends Node

## 偷吃 / 交付事件 → 房东（渔夫）的反应。
## 房东现在就是那只渔夫，喂食提示、台词、动作都挂在它身上；
## 这个自动加载只做一件事：把「玩家偷吃」转成房东生气。

const LANDLORD_GROUP := &"feed_landlord"

## 两次触发之间的最短间隔（秒），防止连吃刷屏
@export var cooldown := 4.0
## 找不到房东时兜底播的一句话
@export var fallback_line := "屋里传来一声闷响……"

var _cooldown_left := 0.0


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta


## 玩家自己把食物吃掉时调用
func on_player_ate(_item_name: String = "食物") -> void:
	if _cooldown_left > 0.0:
		return
	_cooldown_left = cooldown

	var landlord := get_tree().get_first_node_in_group(LANDLORD_GROUP)
	if landlord == null:
		MessageBanner.show_message(fallback_line, Color(1.0, 0.28, 0.22), 2.5)
		return
	if landlord.has_method("react_angry"):
		landlord.call("react_angry")


## 把食物交给房东时调用：房东自己会播进食动作，这里只清掉冷却
func on_food_delivered() -> void:
	_cooldown_left = 0.0
