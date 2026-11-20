extends CharacterBody3D

## 只负责移动（WASD/跳跃/重力）。鼠标视角由相机上的 camera_interact.gd 持有。

@export_group("Movement")
@export var speed := 5.0
@export var jump_velocity := 6.0
@export var ground_acceleration := 4.0
@export var air_acceleration := 0.5
@export var gravity := 15.0

func _physics_process(delta: float) -> void:
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
