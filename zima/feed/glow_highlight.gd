class_name GlowHighlight
extends Node3D

## 可拾取物高亮组件：挂在道具节点下 → 暖色小灯 + 自发光呼吸脉冲。
## 房间光照很暗，钥匙/撬锁器/盒子这类剧情道具需要"一眼能看见"。
## 材质两种情况都处理：
##   - StandardMaterial3D：复制后开 emission，替换 override
##   - PSX ShaderMaterial（convert_material 产物）：直接设
##     emission_color / emission_energy 着色器参数
## 不改变碰撞/交互，纯视觉。

@export var glow_color := Color(1.0, 0.85, 0.45)
@export var light_range := 3.5
@export var pulse_speed := 2.6
## 调试阶段：信标式强闪。beacon = true 时 0.5s 亮 / 0.3s 灭循环；
## 自发光能量直接拉到 4~10（PSX 着色器上限 16），灯能量 2.5 起。
@export var beacon := true
@export var light_height := 0.35

var _mats_std: Array[StandardMaterial3D] = []
var _mats_shader: Array[ShaderMaterial] = []
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	_t = randf() * TAU  # 多个道具错开相位，不同步闪
	_light = OmniLight3D.new()
	_light.light_color = glow_color
	_light.omni_range = light_range
	_light.omni_attenuation = 0.9
	_light.shadow_enabled = false
	_light.position = Vector3(0, light_height, 0)
	add_child(_light)
	_collect_materials.call_deferred()


func _collect_materials() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for mi in parent.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for s in m3.mesh.get_surface_count():
			var mat := m3.get_active_material(s)
			if mat is StandardMaterial3D:
				var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.emission_enabled = true
				dup.emission = glow_color
				dup.emission_energy_multiplier = 8.0
				m3.set_surface_override_material(s, dup)
				_mats_std.append(dup)
			elif mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
				# PSX 材质带 emission_color/emission_energy uniform；
				# 对不存在的 uniform 赋值是无害 no-op，不必检查
				var sdup := (mat as ShaderMaterial).duplicate() as ShaderMaterial
				sdup.set_shader_parameter("emission_color", glow_color)
				sdup.set_shader_parameter("emission_energy", 8.0)
				m3.set_surface_override_material(s, sdup)
				_mats_shader.append(sdup)


func _process(delta: float) -> void:
	_t += delta
	var e: float
	if beacon:
		# 信标式强闪：亮 0.5s（满能量）→ 灭 0.3s，周期 0.8s，黑暗里极醒目
		var phase := fmod(_t * pulse_speed, 1.6)
		e = 8.0 if phase < 1.0 else 0.15
	else:
		# 平滑呼吸：能量 1.5~7 往复
		var pulse := 0.5 + 0.5 * sin(_t * pulse_speed)
		e = 1.5 + 5.5 * pulse
	for m in _mats_std:
		m.emission_energy_multiplier = e
	for m in _mats_shader:
		m.set_shader_parameter("emission_energy", e)
	if _light != null:
		if beacon:
			var phase2 := fmod(_t * pulse_speed, 1.6)
			_light.light_energy = 3.0 if phase2 < 1.0 else 0.05
		else:
			var pulse := 0.5 + 0.5 * sin(_t * pulse_speed)
			_light.light_energy = 1.2 + 2.2 * pulse
