extends Node3D
## 같은 물건 여러 개를 MultiMesh로 한 번에 그린다(적치장, 판매대 재고·돈 더미).
## 자리는 처음에 모두 정해 두고, 보일 개수만 바꾼다. 물건 모델의 메시마다 MultiMesh 하나를 둔다.

const ItemModel := preload("res://frost_camp/scenes/item_model.gd")

var _multis: Array[MultiMesh] = []


## turn은 물건 하나에 먼저 거는 변환(눕히기 등), place(i)는 i번째 물건의 자리다.
func setup(item: String, size: Vector3, turn: Transform3D, max_count: int, place: Callable) -> void:
	var model := ItemModel.make(item, size)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var inner := turn * ItemModel._local_to(model, mesh)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh.mesh
		multi.instance_count = max_count
		for i in max_count:
			multi.set_instance_transform(i, Transform3D(Basis(), place.call(i)) * inner)
		multi.visible_instance_count = 0
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = mesh.material_override
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_multis.append(multi)
	model.free()


func show_count(count: int) -> void:
	for multi in _multis:
		multi.visible_instance_count = count
