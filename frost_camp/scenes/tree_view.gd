extends Node3D
## 나무 한 그루의 겉모습. 맞으면 맞은 반대쪽으로 휘청이며 파편과 데미지 숫자가 튀고,
## 쓰러지면 때린 반대쪽으로 넘어간 뒤 그루터기만 남고, 다시 자라면 솟아오른다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const MODELS := [
	preload("res://frost_camp/assets/models/nature/tree_pineDefaultA.glb"),
	preload("res://frost_camp/assets/models/nature/tree_pineRoundA.glb"),
	preload("res://frost_camp/assets/models/nature/tree_pineDefaultB.glb"),
	preload("res://frost_camp/assets/models/nature/tree_pineRoundB.glb"),
	preload("res://frost_camp/assets/models/nature/tree_pineTallA.glb"),
	preload("res://frost_camp/assets/models/nature/tree_pineRoundC.glb"),
	preload("res://frost_camp/assets/models/nature/tree_pineTallB.glb"),
]
const MODEL_SCALE := 2.6
const CHIP_COLOR := Color(0.55, 0.36, 0.2)
const SNOW_COLOR := Color(0.92, 0.95, 1.0)
const HIT_TILT := 0.22

var sim: FrostSim
var index: int
var _standing := true
var _chips: CPUParticles3D
var _snow: CPUParticles3D

@onready var _crown: Node3D = $Crown
@onready var _stump: Node3D = $Stump


func setup(frost_sim: FrostSim, tree_index: int) -> void:
	sim = frost_sim
	index = tree_index
	var tree := sim.trees[index]
	position = Vector3(tree.pos.x, 0.0, tree.pos.y)
	var model: Node3D = MODELS[index % MODELS.size()].instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	model.rotation.y = index * 1.3  # 같은 모델도 돌려 놓아 숲이 덜 반복돼 보이게
	_crown.add_child(model)
	_chips = Juice.make_burst(self, CHIP_COLOR, 10)
	_chips.position.y = 0.7
	_snow = Juice.make_burst(self, SNOW_COLOR, 8, 0.18)
	_snow.position.y = 2.2
	_snow.initial_velocity_max = 2.0
	sim.tree_hit.connect(_on_tree_hit)
	sim.tree_felled.connect(_on_tree_felled)


func _process(_delta: float) -> void:
	var standing := sim.trees[index].is_standing()
	if standing and not _standing:
		_crown.quaternion = Quaternion.IDENTITY
		_crown.visible = true
		Juice.pop(_crown, Vector3(0.3, 0.3, 0.3), 0.4)
	_standing = standing
	_stump.visible = not standing


## 때린 쪽에서 나무로 향하는 방향을 축으로 바꾼다(그 방향으로 기울어지는 회전축).
func _away_axis(agent: SimAgent) -> Vector3:
	var dir := sim.trees[index].pos - agent.pos
	if dir.length() < 0.01:
		dir = Vector2(0, -1)
	dir = dir.normalized()
	return Vector3(dir.y, 0.0, -dir.x)


func _on_tree_hit(hit_index: int, agent: SimAgent) -> void:
	if hit_index != index:
		return
	var axis := _away_axis(agent)
	var tween := create_tween().set_parallel()
	tween.tween_method(func(a: float) -> void: _crown.quaternion = Quaternion(axis, a), HIT_TILT, 0.0, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_crown.scale = Vector3(1.12, 0.88, 1.12)
	tween.tween_property(_crown, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_chips.restart()
	_snow.restart()
	var damage: int = agent.damage if agent is Worker else sim.stats.axe_damage
	Juice.float_text(self, global_position + Vector3(0.0, 2.2, 0.0), "-%d" % damage)


func _on_tree_felled(felled_index: int, agent: SimAgent) -> void:
	if felled_index != index:
		return
	var axis := _away_axis(agent)
	var tween := create_tween()
	tween.tween_method(func(a: float) -> void: _crown.quaternion = Quaternion(axis, a), 0.0, PI / 2.0, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_crown.visible = false
		_chips.restart()
		_snow.restart())
	Juice.float_text(self, global_position + Vector3(0.0, 1.5, 0.0),
		"+%d" % int(sim.balance.tree.logs_dropped), Color(1.0, 0.85, 0.3), 80)
