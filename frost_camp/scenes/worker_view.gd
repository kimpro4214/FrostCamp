extends CharacterBody3D
## 일꾼 몸. sim의 worker_brain이 정한 목표까지 NavigationAgent3D로 길을 찾아 걷고, 위치를 sim에 넘긴다.

## 역할마다 다른 캐릭터를 써서 한눈에 구분되게 한다.
const ROLE_MODELS := {
	"lumberjack": "res://frost_camp/assets/models/characters/character-worker.glb",
	"porter": "res://frost_camp/assets/models/characters/character-male-c.glb",
	"hunter": "res://frost_camp/assets/models/characters/character-male-e.glb",
	"fisher": "res://frost_camp/assets/models/characters/character-female-d.glb",
	"miner": "res://frost_camp/assets/models/characters/character-female-a.glb",
	"cashier": "res://frost_camp/assets/models/characters/character-female-b.glb",
	"merc": "res://frost_camp/assets/models/characters/character-soldier.glb",
}

var sim: FrostSim
var index: int
var _goal := Vector2.INF
var _leaving := false
## 맞을 때 잠깐 덮는 붉은 색
var _hit_overlay: StandardMaterial3D

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _pivot: Node3D = $Pivot
@onready var _model: Node3D = $Pivot/Model


func setup(frost_sim: FrostSim, worker_index: int) -> void:
	sim = frost_sim
	index = worker_index
	var worker := sim.workers[index]
	position = Vector3(worker.pos.x, 0.0, worker.pos.y)
	$Pivot/StackAnchor.setup(worker.stack)
	_model.setup(ROLE_MODELS[worker.role])
	_hit_overlay = StandardMaterial3D.new()
	_hit_overlay.albedo_color = Color(1.0, 0.2, 0.2, 0.6)
	_hit_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sim.worker_hit.connect(_on_worker_hit)
	if worker.dead or worker.retired:
		# 이어하기: 이미 쓰러지거나 물러난 일꾼은 연출 없이 숨긴다.
		_leaving = true
		visible = false
		set_physics_process(false)
		return
	if worker.role == "miner":
		_model.set_tool("res://frost_camp/assets/models/survival/tool-pickaxe.glb")
		sim.tree_hit.connect(_on_tree_hit)
	if worker.role == "lumberjack":
		_model.set_tool("res://frost_camp/assets/models/survival/tool-axe.glb")
		sim.tree_hit.connect(_on_tree_hit)
	if worker.role == "fisher":
		_model.set_tool("res://frost_camp/scenes/fishing_rod.tscn")
	if worker.role == "merc":
		_model.set_tool(_model.GUN)
		_model.set_holding(true)
		sim.boss_raid.shot.connect(func(from: Vector2, _to: Vector2, weapon: String) -> void:
			if weapon == "merc" and from.distance_to(sim.workers[index].pos) < 0.05:
				_on_hit(sim.workers[index], _to))
		sim.raider_hit.connect(func(i: int, agent: SimAgent) -> void: _on_hit(agent, sim.raid.bears[i].pos))
	if worker.role == "hunter":
		_model.set_tool(_model.GUN)
		_model.set_holding(true)
		sim.bear_hit.connect(func(i: int, agent: SimAgent) -> void: _on_hit(agent, sim.bears[i].pos))
		sim.raider_hit.connect(func(i: int, agent: SimAgent) -> void: _on_hit(agent, sim.raid.bears[i].pos))


func _physics_process(_delta: float) -> void:
	var worker := sim.workers[index]
	if worker.dead and not _leaving:
		_fall()
	elif worker.retired and not _leaving:
		_leave()
	if worker.role == "merc" and sim.boss_raid.active and not worker.retired:
		# 레이드 영역에는 길찾기 메시가 없으니 sim이 정한 자리로 바로 옮긴다.
		var step := Vector3(worker.pos.x, 0.0, worker.pos.y) - position
		if step.length() > 0.01:
			_pivot.rotation.y = atan2(-step.x, -step.z)
		position = Vector3(worker.pos.x, 0.0, worker.pos.y)
		_model.set_moving(step.length() > 0.01)
		return
	var goal: Vector2 = worker.target.pos
	if goal != _goal:
		_goal = goal
		_agent.target_position = Vector3(goal.x, 0.0, goal.y)
	velocity = Vector3.ZERO
	var here := Vector2(position.x, position.z)
	if here.distance_to(goal) > worker.target.stop and not _agent.is_navigation_finished():
		var next := _agent.get_next_path_position()
		var direction := Vector3(next.x - position.x, 0.0, next.z - position.z)
		if direction.length() > 0.01:
			velocity = direction.normalized() * sim.agent_speed(worker)
			_pivot.rotation.y = atan2(-direction.x, -direction.z)
	move_and_slide()
	worker.pos = Vector2(position.x, position.z)
	_model.set_moving(velocity.length() > 0.1)
	_model.set_frozen(worker.warmth <= 0.0)


## 내가 친 것이면 휘두르고 나무를 바라본다.
func _on_tree_hit(tree_index: int, agent: SimAgent) -> void:
	if agent != sim.workers[index]:
		return
	_model.play_action()
	var dir := sim.trees[tree_index].pos - agent.pos
	_pivot.rotation.y = atan2(-dir.x, -dir.y)


## 내가 쏜 것이면 총을 쏘는 동작을 하고 맞은 쪽을 바라본다(사냥꾼).
func _on_hit(agent: SimAgent, target: Vector2) -> void:
	if agent != sim.workers[index]:
		return
	_model.play_action(_model.SHOOT)
	var dir := target - agent.pos
	_pivot.rotation.y = atan2(-dir.x, -dir.y)


## 습격 곰에게 맞으면 붉게 번쩍이며 움찔한다.
func _on_worker_hit(hit_index: int) -> void:
	if hit_index != index:
		return
	var pivot := _pivot
	pivot.scale = Vector3(1.15, 0.85, 1.15)
	create_tween().tween_property(pivot, "scale", Vector3.ONE, 0.15)
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _hit_overlay
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		for mesh in _model.find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = null)


## 쓰러진 일꾼: 옆으로 넘어지고 잠시 뒤 땅속으로 사라진다.
func _fall() -> void:
	_leaving = true
	velocity = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:z", PI / 2.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(1.2)
	tween.tween_property(self, "scale", Vector3(1.0, 0.01, 1.0), 0.4)
	tween.tween_callback(func() -> void:
		visible = false
		set_physics_process(false))


## 컨베이어로 바뀌어 물러난 운반꾼: 손을 흔들 듯 한 번 휘두르고 스폰 쪽으로 걸어가며 작아져 사라진다.
func _leave() -> void:
	_leaving = true
	_model.play_action()
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		visible = false
		set_physics_process(false))
