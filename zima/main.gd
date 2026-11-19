extends Node

@export var world_path: NodePath = ^"PSXScreen/SubViewport/World"
@export var auto_convert := true
@export var affine := 1.0
@export var snap_pixels := 1.0

func _ready() -> void:
	print_tree_pretty()
	if not auto_convert:
		return
	var world := get_node_or_null(world_path)
	if world == null:
		push_error("PSX: world node not found, check world_path: " + str(world_path))
		return
	var made := PSX.convert(world)
	print("PSX converted materials: ", made)
	PSX.apply_ps1(world, affine, snap_pixels)

func reconvert() -> void:
	var world := get_node_or_null(world_path)
	if world:
		print("PSX reconverted: ", PSX.convert(world))
