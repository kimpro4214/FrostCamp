extends Node3D
## 얼음 구멍 낚시터. 구멍마다 짙은 물빛 원판과 얼음 테두리를 두고,
## 연어가 잡히면 물보라가 튀고 연어가 낚은 사람 등으로 포물선을 그리며 날아간다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const HOLE_RADIUS := 0.75
const WATER_COLOR := Color(0.1, 0.28, 0.42)
const RIM_COLOR := Color(0.88, 0.95, 1.0)
const SALMON_COLOR := Color(0.98, 0.55, 0.5)
const FLY_TIME := 0.4

var sim: FrostSim
var _splashes: Array[CPUParticles3D] = []
## 품목을 들어 올린 사람 노드를 찾을 때 쓴다(플레이어 또는 일꾼 화면)
var _find_body: Callable


func setup(frost_sim: FrostSim, find_body: Callable) -> void:
	sim = frost_sim
	_find_body = find_body
	for hole in sim.fishing_holes:
		var root := Node3D.new()
		root.position = Vector3(hole.x, 0.0, hole.y)
		add_child(root)
		var water := MeshInstance3D.new()
		var water_mesh := CylinderMesh.new()
		water_mesh.top_radius = HOLE_RADIUS
		water_mesh.bottom_radius = HOLE_RADIUS
		water_mesh.height = 0.02
		water_mesh.material = _material(WATER_COLOR)
		water.mesh = water_mesh
		water.position.y = 0.02
		root.add_child(water)
		var rim := MeshInstance3D.new()
		var rim_mesh := TorusMesh.new()
		rim_mesh.inner_radius = HOLE_RADIUS
		rim_mesh.outer_radius = HOLE_RADIUS + 0.22
		rim_mesh.material = _material(RIM_COLOR)
		rim.mesh = rim_mesh
		rim.scale = Vector3(1.0, 0.5, 1.0)
		root.add_child(rim)
		var splash := Juice.make_burst(root, Color(0.75, 0.9, 1.0), 10, 0.1)
		splash.position.y = 0.1
		_splashes.append(splash)
	sim.fish_caught.connect(_on_fish_caught)


func _on_fish_caught(hole: int, agent: SimAgent) -> void:
	_splashes[hole].restart()
	var body: Node3D = _find_body.call(agent)
	if body == null:
		return
	var salmon := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 0.16, 0.22)
	mesh.material = _material(SALMON_COLOR)
	salmon.mesh = mesh
	add_child(salmon)
	var from := Vector3(sim.fishing_holes[hole].x, 0.2, sim.fishing_holes[hole].y)
	salmon.global_position = from
	var tween := salmon.create_tween()
	tween.tween_method(func(t: float) -> void:
		var to := body.global_position + Vector3(0.0, 1.2, 0.0)
		salmon.global_position = from.lerp(to, t) + Vector3(0.0, sin(t * PI) * 1.6, 0.0)
		salmon.rotation.z = t * TAU, 0.0, 1.0, FLY_TIME)
	tween.tween_callback(salmon.queue_free)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
