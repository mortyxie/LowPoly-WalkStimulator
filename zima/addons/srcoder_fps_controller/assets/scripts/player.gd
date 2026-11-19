extends CharacterBody3D

@export_group("Movement")
@export var speed := 5.0
@export var jump_velocity := 6.0
@export var ground_acceleration := 4.0
@export var air_acceleration := 0.5
@export var gravity := 15.0

@export_group("Look")
@export var mouse_sensitivity := 3.0
@export var pitch_limit := 89.0

@export_group("Nodes")
@export var camera_pivot_path: NodePath = ^"CameraPivot2"

var camera_pivot: Node3D
var _pitch := 0.0

func _ready() -> void:
	camera_pivot = get_node_or_null(camera_pivot_path)
	if camera_pivot == null:
		push_error("player: camera pivot not found")
	MouseLook.set_captured(true)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		MouseLook.set_captured(not captured)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var target := Vector3(direction.x * speed, 0.0, direction.z * speed)
	var accel := ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)

	move_and_slide()

	var motion := MouseLook.take_motion()
	rotate_y(-motion.x * mouse_sensitivity / 1000.0)
	_pitch = clamp(
		_pitch - motion.y * mouse_sensitivity / 1000.0,
		deg_to_rad(-pitch_limit),
		deg_to_rad(pitch_limit)
	)
	if camera_pivot:
		camera_pivot.rotation.x = _pitch
