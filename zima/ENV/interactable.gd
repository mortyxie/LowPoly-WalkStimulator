extends Node3D

@export var display_name := "纸条"

# 准星射线 E 交互；反馈统一走屏幕横幅（中上方浮现后淡出），不再 print
func interact() -> void:
	MessageBanner.show_message("你查看了一下：%s" % display_name, Color(0.9, 0.9, 0.9), 1.5)
	# QuickAudio 示例调用（加音效直接用）
	# Audio.play_sound(preload("res://Audio/sfx/interact/paper.ogg"))
