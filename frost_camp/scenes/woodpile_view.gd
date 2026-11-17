extends Node3D
## 적치장(원목 또는 고기). 쌓인 개수만큼 상자를 쌓아 그린다. 고기 적치장은 서식지를 열기 전에는 숨는다.

const MAX_SHOWN := 24
const ItemModel := preload("res://frost_camp/scenes/item_model.gd")
## 쌓는 물건 하나의 크기(길이는 z)
const ITEM_SIZE := Vector3(0.25, 0.2, 0.9)

var sim: FrostSim
var item := "log"
var _shown := -1
var _template: Node3D

@onready var _logs: Node3D = $Logs


func setup(frost_sim: FrostSim, pile_item: String = "log") -> void:
	sim = frost_sim
	item = pile_item
	var pos := sim.pile_pos(item)
	position = Vector3(pos.x, 0.0, pos.y)
	var radius := float(sim.balance.interact.pile_radius)
	$Zone.scale = Vector3(radius, 1.0, radius)
	_template = ItemModel.make(item, Vector3(ITEM_SIZE.z, ITEM_SIZE.y, ITEM_SIZE.x))  # 길이를 x로 만든 뒤 돌려 z로 둔다
	_template.rotation.y = PI / 2.0


func _process(_delta: float) -> void:
	var structure := sim.pile_structure(item)
	visible = structure.unlock == "" or sim.unlocked.has(structure.unlock)
	var count := mini(sim.pile_count(item), MAX_SHOWN)
	if count == _shown:
		return
	_shown = count
	for child in _logs.get_children():
		child.queue_free()
	for i in count:
		var box: Node3D = _template.duplicate()
		box.visible = true
		box.position = Vector3(-0.3 + (i % 3) * 0.3, 0.1 + (i / 3) * 0.22, 0.0)
		_logs.add_child(box)
