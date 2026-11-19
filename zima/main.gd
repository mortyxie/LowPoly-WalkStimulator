extends Node

## 启动时把 SubViewport 里的 3D 世界转成 PSX 材质。不依赖固定路径。

@export var auto_convert := true
@export var affine := 1.0
@export var snap_pixels := 1.0

func _ready() -> void:
	if not auto_convert:
		return
	var world := _find_world()
	if world == null:
		push_error("PSX: no 3D world found under any SubViewport")
		print_tree_pretty()
		return
	var made := PSX.convert(world)
	print("PSX converted materials: ", made)
	PSX.apply_ps1(world, affine, snap_pixels)

func reconvert() -> void:
	var world := _find_world()
	if world:
		print("PSX reconverted: ", PSX.convert(world))

func _find_world() -> Node3D:
	var vps := get_tree().root.find_children("*", "SubViewport", true, false)
	for vp in vps:
		for child in vp.get_children():
			if child is Node3D:
				return child
	var nodes := get_tree().root.find_children("*", "Node3D", true, false)
	for n in nodes:
		if n.name.to_lower().contains("world"):
			return n
	return null
