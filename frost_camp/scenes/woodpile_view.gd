extends Node3D
## 적치장(원목 또는 고기). 쌓인 개수만큼 상자를 쌓아 그린다. 고기 적치장은 서식지를 열기 전에는 숨는다.

const MAX_SHOWN := 24
## 품목별 상자 색(원목은 장면의 기본 색을 쓴다)
const ITEM_COLORS := {"meat": Color(0.78, 0.3, 0.28), "salmon": Color(0.98, 0.55, 0.5)}

var sim: FrostSim
var item := "log"
var _shown := -1

@onready var _logs: Node3D = $Logs
@onready var _template: MeshInstance3D = $Template


func setup(frost_sim: FrostSim, pile_item: String = "log") -> void:
	sim = frost_sim
	item = pile_item
	var pos := sim.pile_pos(item)
	position = Vector3(pos.x, 0.0, pos.y)
	var radius := float(sim.balance.interact.pile_radius)
	$Zone.scale = Vector3(radius, 1.0, radius)
	if ITEM_COLORS.has(item):
		var material := StandardMaterial3D.new()
		material.albedo_color = ITEM_COLORS[item]
		_template.material_override = material


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
