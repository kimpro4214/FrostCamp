extends Node3D
## 나무 한 그루의 겉모습. 맞으면 흔들리고, 쓰러지면 넘어간 뒤 그루터기만 남고, 다시 자라면 솟아오른다.

const Juice := preload("res://frost_camp/scenes/juice.gd")

var sim: FrostSim
var index: int
var _standing := true

@onready var _crown: Node3D = $Crown


func setup(frost_sim: FrostSim, tree_index: int) -> void:
	sim = frost_sim
	index = tree_index
	var tree := sim.trees[index]
	position = Vector3(tree.pos.x, 0.0, tree.pos.y)
	sim.tree_hit.connect(_on_tree_hit)
	sim.tree_felled.connect(_on_tree_felled)


func _process(_delta: float) -> void:
	var standing := sim.trees[index].is_standing()
	if standing and not _standing:
		_crown.rotation = Vector3.ZERO
		_crown.visible = true
		Juice.pop(_crown, Vector3(0.3, 0.3, 0.3), 0.4)
	_standing = standing


func _on_tree_hit(hit_index: int) -> void:
	if hit_index != index:
		return
	var tween := create_tween()
	tween.tween_property(_crown, "rotation:z", 0.12, 0.05)
	tween.tween_property(_crown, "rotation:z", 0.0, 0.15)


func _on_tree_felled(felled_index: int) -> void:
	if felled_index != index:
		return
	var tween := create_tween()
	tween.tween_property(_crown, "rotation:x", -PI / 2.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _crown.visible = false)
