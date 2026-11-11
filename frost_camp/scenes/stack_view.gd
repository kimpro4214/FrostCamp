extends Node3D
## 등 뒤 스택 그리기. 플레이어와 일꾼이 같이 쓴다.

const ITEM_COLORS := {"log": Color(0.55, 0.33, 0.18), "meat": Color(0.85, 0.3, 0.32)}
const ITEM_SIZE := Vector3(0.5, 0.2, 0.3)

var _stack: BackStack
var _shown: Array[String] = []
var _materials := {}


func setup(stack: BackStack) -> void:
	_stack = stack


func _process(_delta: float) -> void:
	if _stack == null or _stack.items == _shown:
		return
	_shown = _stack.items.duplicate()
	for child in get_children():
		child.queue_free()
	for i in _shown.size():
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = ITEM_SIZE
		box.mesh = mesh
		box.material_override = _material_for(_shown[i])
		box.position.y = i * (ITEM_SIZE.y + 0.02)
		add_child(box)


func _material_for(item: String) -> StandardMaterial3D:
	if not _materials.has(item):
		var material := StandardMaterial3D.new()
		material.albedo_color = ITEM_COLORS.get(item, Color.MAGENTA)
		_materials[item] = material
	return _materials[item]
