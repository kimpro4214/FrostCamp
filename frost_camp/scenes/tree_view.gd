extends Node3D
## 나무 한 그루의 겉모습. 쓰러지면 그루터기만 남는다.

var sim: FrostSim
var index: int

@onready var _crown: Node3D = $Crown


func setup(frost_sim: FrostSim, tree_index: int) -> void:
	sim = frost_sim
	index = tree_index
	var tree := sim.trees[index]
	position = Vector3(tree.pos.x, 0.0, tree.pos.y)
	sim.tree_hit.connect(_on_tree_hit)


func _process(_delta: float) -> void:
	_crown.visible = sim.trees[index].is_standing()


func _on_tree_hit(hit_index: int) -> void:
	if hit_index != index:
		return
	var tween := create_tween()
	tween.tween_property(_crown, "rotation:z", 0.12, 0.05)
	tween.tween_property(_crown, "rotation:z", 0.0, 0.15)
