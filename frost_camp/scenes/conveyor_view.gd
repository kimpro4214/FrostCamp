extends Node3D
## 컨베이어 벨트의 겉모습. 경로 구간마다 벨트 판을 깔고, 그 위로 가로 살과 원목이 흐른다.
## 사기 전에는 숨어 있고, 부서지면 살이 멈춘다(체력 표시가 기울이고 어둡게 만든다).

const Juice := preload("res://frost_camp/scenes/juice.gd")
const BELT_WIDTH := 0.8
const BELT_HEIGHT := 0.16
const SLAT_GAP := 0.5
const BELT_COLOR := Color(0.22, 0.23, 0.27)
const RAIL_COLOR := Color(0.95, 0.75, 0.2)
const SLAT_COLOR := Color(0.38, 0.4, 0.45)
const LOG_COLOR := Color(0.55, 0.36, 0.2)

var sim: FrostSim
## 부서질 때 기울이고 어둡게 만들 모델(체력 표시가 쓴다)
var model: Node3D
var _slats: Array[MeshInstance3D] = []
var _logs: Array[MeshInstance3D] = []
var _log_mesh: CylinderMesh
var _scroll := 0.0
var _shown_level := 0
## 모델 원점(시설 위치). 부서질 때 이 점을 중심으로 기운다.
var _origin: Vector2


func setup(frost_sim: FrostSim) -> void:
	sim = frost_sim
	var belt := sim.conveyor
	_origin = belt.structure.pos
	model = Node3D.new()
	model.position = Vector3(_origin.x, 0.0, _origin.y)
	add_child(model)
	for i in range(1, belt.path.size()):
		_add_segment(belt.path[i - 1], belt.path[i])
	var slat_mesh := BoxMesh.new()
	slat_mesh.size = Vector3(BELT_WIDTH * 0.9, 0.04, 0.08)
	slat_mesh.material = _material(SLAT_COLOR)
	for i in int(belt.length / SLAT_GAP):
		var slat := MeshInstance3D.new()
		slat.mesh = slat_mesh
		model.add_child(slat)
		_slats.append(slat)
	_log_mesh = CylinderMesh.new()
	_log_mesh.top_radius = 0.16
	_log_mesh.bottom_radius = 0.16
	_log_mesh.height = 0.6
	_log_mesh.material = _material(LOG_COLOR)
	visible = false


func _process(delta: float) -> void:
	var belt := sim.conveyor
	if belt.level != _shown_level:
		_shown_level = belt.level
		visible = belt.level > 0
		Juice.pop(model, Vector3(1.0, 0.2, 1.0), 0.4)
	if not visible:
		return
	if not belt.structure.is_broken():
		_scroll = fmod(_scroll + belt.speed() * delta, SLAT_GAP)
	for i in _slats.size():
		_place(_slats[i], _scroll + i * SLAT_GAP, BELT_HEIGHT + 0.02)
	while _logs.size() < belt.items.size():
		var log_mesh := MeshInstance3D.new()
		log_mesh.mesh = _log_mesh
		model.add_child(log_mesh)
		_logs.append(log_mesh)
	for i in _logs.size():
		_logs[i].visible = i < belt.items.size()
		if _logs[i].visible:
			_place(_logs[i], belt.items[i], BELT_HEIGHT + 0.18)
			_logs[i].rotate_object_local(Vector3.FORWARD, PI / 2.0)  # 통나무를 벨트 폭 방향으로 눕힌다


## 경로 위 dist 지점에 놓고 진행 방향을 보게 돌린다.
func _place(node: Node3D, dist: float, height: float) -> void:
	var belt := sim.conveyor
	var here := belt.point_at(dist)
	var ahead := belt.point_at(minf(dist + 0.05, belt.length))
	if ahead.distance_to(here) < 0.001:
		ahead = here + (here - belt.point_at(maxf(dist - 0.05, 0.0)))
	node.position = Vector3(here.x - _origin.x, height, here.y - _origin.y)
	node.rotation = Vector3(0.0, atan2(-(ahead.x - here.x), -(ahead.y - here.y)), 0.0)


func _add_segment(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to) + BELT_WIDTH
	var center := (from + to) / 2.0
	var angle := atan2(-(to.x - from.x), -(to.y - from.y))
	var belt := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(BELT_WIDTH, BELT_HEIGHT, length)
	mesh.material = _material(BELT_COLOR)
	belt.mesh = mesh
	belt.position = Vector3(center.x - _origin.x, BELT_HEIGHT / 2.0, center.y - _origin.y)
	belt.rotation.y = angle
	model.add_child(belt)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.08, 0.12, length)
		rail_mesh.material = _material(RAIL_COLOR)
		rail.mesh = rail_mesh
		rail.position = Vector3(side * (BELT_WIDTH / 2.0 + 0.04), BELT_HEIGHT / 2.0 + 0.04, 0.0)
		belt.add_child(rail)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
