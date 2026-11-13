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
}

var sim: FrostSim
var index: int
var _goal := Vector2.INF

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
	if worker.role == "miner":
		_model.set_tool("res://frost_camp/assets/models/survival/tool-pickaxe.glb")
		sim.tree_hit.connect(_on_tree_hit)
	if worker.role == "lumberjack":
		_model.set_tool("res://frost_camp/assets/models/survival/tool-axe.glb")
		sim.tree_hit.connect(_on_tree_hit)
	if worker.role == "fisher":
		_model.set_tool("res://frost_camp/scenes/fishing_rod.tscn")
	if worker.role == "hunter":
		_model.set_tool("res://frost_camp/assets/models/survival/tool-axe-upgraded.glb")
		sim.bear_hit.connect(func(i: int, agent: SimAgent) -> void: _on_hit(agent, sim.bears[i].pos))
		sim.raider_hit.connect(func(i: int, agent: SimAgent) -> void: _on_hit(agent, sim.raid.bears[i].pos))


func _physics_process(_delta: float) -> void:
	var worker := sim.workers[index]
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


## 내가 친 것이면 휘두르고 맞은 쪽을 바라본다(사냥꾼).
func _on_hit(agent: SimAgent, target: Vector2) -> void:
	if agent != sim.workers[index]:
		return
	_model.play_action()
	var dir := target - agent.pos
	_pivot.rotation.y = atan2(-dir.x, -dir.y)
