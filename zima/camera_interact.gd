extends Camera3D

@export var ray_distance: float = 3.0
@export var prompt_label: Label
var hit_target: Node3D = null

func _process(delta: float) -> void:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = global_position
	var ray_end = global_position + global_transform.basis.z * -ray_distance
	
	var query = PhysicsRayQueryParameters3D.new()
	query.from = ray_origin
	query.to = ray_end
	query.exclude = [get_parent()]
	
	var result = space_state.intersect_ray(query)

	if result:
		var target = result["collider"]
		if target.has_method("interact"):
			hit_target = target
			if prompt_label:
				prompt_label.text = "[E] 查看"
		else:
			hit_target = null
			if prompt_label:
				prompt_label.text = ""
	else:
		hit_target = null
		if prompt_label:
			prompt_label.text = ""

func _input(event: InputEvent):
	if event.is_action_pressed("interact") and hit_target != null:
		hit_target.interact()
		hit_target.interact()
