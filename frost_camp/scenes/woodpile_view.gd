extends Node3D
## 원목 적치장. 쌓인 원목 수만큼 통나무를 쌓아 그린다.

const MAX_SHOWN := 24

var sim: FrostSim
var _shown := -1

@onready var _logs: Node3D = $Logs
@onready var _template: Node3D = $Template


func setup(frost_sim: FrostSim) -> void:
	sim = frost_sim
	position = Vector3(sim.woodpile_pos.x, 0.0, sim.woodpile_pos.y)
	var radius := float(sim.balance.interact.pile_radius)
	$Zone.scale = Vector3(radius, 1.0, radius)


func _process(_delta: float) -> void:
	var count := mini(sim.woodpile, MAX_SHOWN)
	if count == _shown:
		return
	_shown = count
	for child in _logs.get_children():
		child.queue_free()
	for i in count:
		var log_box: Node3D = _template.duplicate()
		log_box.visible = true
		log_box.position = Vector3(-0.3 + (i % 3) * 0.3, 0.1 + (i / 3) * 0.22, 0.0)
		_logs.add_child(log_box)
