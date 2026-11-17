extends RefCounted
## 모델 위쪽 면에 눈을 덮는다. 가져온 .glb 모델의 재질만 눈 셰이더 재질로 바꾼다.
## 코드로 만든 단색 재질(결정, 체력바 등)은 건드리지 않는다.
## 같은 원래 재질은 같은 눈 재질로 바꿔, 여러 그루가 재질을 함께 쓰게 둔다.

const SnowShader := preload("res://frost_camp/scenes/snow_cap.gdshader")

static var _cache := {}


## root 아래 모든 모델에 눈을 덮는다. snow_from: 세계 법선 y가 이 값을 넘는 면에 눈이 쌓인다(작을수록 비탈에도 쌓인다).
static func apply(root: Node, snow_from := 0.55) -> void:
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D:
			_apply_mesh(node, snow_from)
		elif node is MultiMeshInstance3D:
			_apply_multi(node, snow_from)


static func _apply_mesh(instance: MeshInstance3D, snow_from: float) -> void:
	if instance.mesh == null or instance.material_override != null:
		return
	for i in instance.mesh.get_surface_count():
		var snowy := _convert(instance.get_active_material(i), snow_from)
		if snowy:
			instance.set_surface_override_material(i, snowy)


## MultiMesh는 면마다 재질을 따로 줄 수 없어, 면이 하나일 때만 바꾼다.
static func _apply_multi(instance: MultiMeshInstance3D, snow_from: float) -> void:
	var mesh := instance.multimesh.mesh if instance.multimesh else null
	if mesh == null or mesh.get_surface_count() != 1 or instance.material_override != null:
		return
	var snowy := _convert(mesh.surface_get_material(0), snow_from)
	if snowy:
		instance.material_override = snowy


static func _convert(source: Material, snow_from: float) -> ShaderMaterial:
	if not source is StandardMaterial3D or not source.resource_path.contains(".glb"):
		return null
	var key := [source, snow_from]
	if not _cache.has(key):
		var snowy := ShaderMaterial.new()
		snowy.shader = SnowShader
		snowy.set_shader_parameter("albedo_texture", source.albedo_texture)
		snowy.set_shader_parameter("albedo_color", source.albedo_color)
		snowy.set_shader_parameter("metallic", source.metallic)
		snowy.set_shader_parameter("snow_from", snow_from)
		_cache[key] = snowy
	return _cache[key]
