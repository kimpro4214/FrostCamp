extends RefCounted
## 물건(원목, 연어 등) 하나의 겉모습. 모델이 있는 물건은 Kenney 모델을, 없는 물건은 색깔 상자를 쓴다.
## 크기 상자(size, 가운데가 원점)를 꽉 채우게 늘린다. 길쭉한 물건은 길이를 x로 눕힌다.

const MODELS := {
	"log": preload("res://frost_camp/assets/models/nature/log.glb"),
	"salmon": preload("res://frost_camp/assets/models/survival/fish.glb"),
	"gold_salmon": preload("res://frost_camp/assets/models/survival/fish.glb"),
	"crystal": preload("res://frost_camp/assets/models/nature/stone_smallA.glb"),
}
## 모델을 눕히는 회전(라디안). 원목은 길이가 z, 물고기는 옆으로 서 있다.
const TURNS := {"log": Vector3(0.0, PI / 2.0, 0.0), "salmon": Vector3(PI / 2.0, 0.0, 0.0), "gold_salmon": Vector3(PI / 2.0, 0.0, 0.0)}
## 모델 색에 곱할 색
const TINTS := {"gold_salmon": Color(1.0, 0.8, 0.2), "crystal": Color(0.6, 0.9, 1.0)}
## 텍스처를 빼고 색만으로 칠할 물건(황금 연어는 반짝이게)
const SOLID := ["gold_salmon"]
## 스스로 빛나는 세기(모닥불 불빛 아래에서도 색이 보이게)
const GLOW := {"crystal": 0.5}
## 모델이 없는 물건의 상자 색
const BOX_COLORS := {"meat": Color(0.85, 0.3, 0.32), "gem": Color(0.85, 0.35, 1.0), "coin": Color(1.0, 0.8, 0.15)}

static var _tinted := {}
static var _box_materials := {}


static func make(item: String, size: Vector3) -> Node3D:
	if not MODELS.has(item):
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		box.mesh = mesh
		box.material_override = _box_material(item)
		return box
	# 크기 맞춤(fit)과 눕히기(model.rotation)를 다른 노드에 둔다. 한 노드에 두면 늘이기가 돌기 전 축에 걸린다.
	var fit := Node3D.new()
	var model: Node3D = MODELS[item].instantiate()
	model.rotation = TURNS.get(item, Vector3.ZERO)
	fit.add_child(model)
	var bounds := _bounds(model)
	fit.scale = size / bounds.size
	fit.position = -bounds.get_center() * fit.scale
	var holder := Node3D.new()
	holder.add_child(fit)
	if TINTS.has(item):
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = _tint(item, mesh.get_active_material(0))
	return holder


## 눕힌 모델의 경계 상자(모델 부모 좌표 기준)
static func _bounds(model: Node3D) -> AABB:
	var turn := model.transform
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = turn * _local_to(model, mesh) * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _local_to(model: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D()
	while node != model:
		t = node.transform * t
		node = node.get_parent()
	return t


static func _tint(item: String, source: Material) -> Material:
	if not _tinted.has(item):
		var material: StandardMaterial3D = source.duplicate()
		material.albedo_color = TINTS[item]
		if item in SOLID:
			material.albedo_texture = null
			material.metallic = 0.6
			material.roughness = 0.3
		if GLOW.has(item):
			material.emission_enabled = true
			material.emission = TINTS[item]
			material.emission_energy_multiplier = GLOW[item]
		_tinted[item] = material
	return _tinted[item]


static func _box_material(item: String) -> StandardMaterial3D:
	if not _box_materials.has(item):
		var material := StandardMaterial3D.new()
		material.albedo_color = BOX_COLORS.get(item, Color.MAGENTA)
		_box_materials[item] = material
	return _box_materials[item]
