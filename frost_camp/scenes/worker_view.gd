extends CharacterBody3D
## 일꾼 몸. sim의 worker_brain이 정한 목표까지 NavigationAgent3D로 길을 찾아 걷고, 위치를 sim에 넘긴다.

const ROLE_COLORS := {
	"lumberjack": Color(0.3, 0.6, 0.3),
	"porter": Color(0.9, 0.72, 0.25),
	"cashier": Color(0.6, 0.4, 0.85),
}

var sim: FrostSim
var index: int
var _goal := Vector2.INF

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _pivot: Node3D = $Pivot


func setup(frost_sim: FrostSim, worker_index: int) -> void:
	sim = frost_sim
	index = worker_index
	var worker := sim.workers[index]
	position = Vector3(worker.pos.x, 0.0, worker.pos.y)
	$Pivot/StackAnchor.setup(worker.stack)
	var material := StandardMaterial3D.new()
	material.albedo_color = ROLE_COLORS[worker.role]
	$Pivot/Body.material_override = material


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
