extends Node3D

# 示例：纸条。交互反馈统一走屏幕横幅（屏幕中上方浮现后淡出），
# 不再 print 到 console。
func interact():
	MessageBanner.show_message("你查看了一下：上面什么都没写。", Color(0.9, 0.9, 0.9), 1.5)
	# QuickAudio示例调用（你后面加音效直接用）
	# QuickAudio.play_one_shot("res://audio/paper.wav")
