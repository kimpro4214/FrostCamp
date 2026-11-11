extends Node3D
## 지역 울타리. sim.regions의 사각형 둘레에 바위 벽을 세우고, 입구에는 얼음벽을 둔다.
## 지역을 사면 얼음벽이 사라진다.

const WALL_HEIGHT := 1.6
const WALL_THICKNESS := 0.6
const GATE_WIDTH := 3.0

var sim: FrostSim
var region_name: String
var _ice: Node3D

@onready var _rock_material: StandardMaterial3D = $Templates/Rock.material_override
@onready var _ice_template: Node3D = $Templates/Ice


func setup(frost_sim: FrostSim, name_in_sim: String) -> void:
	sim = frost_sim
	region_name = name_in_sim
	var rect: Rect2 = sim.regions[region_name].rect
	var gate: Vector2 = sim.regions[region_name].gate
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		_build_edge(corners[i], corners[(i + 1) % 4], gate)
	_ice = _ice_template.duplicate()
	_ice.visible = true
	add_child(_ice)
	var along_x := is_equal_approx(gate.y, rect.position.y) or is_equal_approx(gate.y, rect.end.y)
	_ice.position = Vector3(gate.x, 0.0, gate.y)
	_ice.rotation.y = 0.0 if along_x else PI / 2.0
	# 템플릿의 얼음벽 충돌체가 원점에 남지 않게 지운다.
	$Templates.queue_free()


func _process(_delta: float) -> void:
	if _ice and sim.unlocked.has(region_name):
		_ice.queue_free()
		_ice = null


## a→b 변 위에 벽을 세운다. 입구가 이 변 위에 있으면 입구 폭만큼 비운다.
func _build_edge(a: Vector2, b: Vector2, gate: Vector2) -> void:
	var dir := (b - a).normalized()
	var on_edge := absf((gate - a).cross(dir)) < 0.01 and (gate - a).dot(dir) > 0.0 and (gate - a).dot(dir) < a.distance_to(b)
	if not on_edge:
		_add_wall(a, b)
		return
	_add_wall(a, gate - dir * GATE_WIDTH / 2.0)
	_add_wall(gate + dir * GATE_WIDTH / 2.0, b)


func _add_wall(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var center := (a + b) / 2.0
	var size := Vector3(length + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS)
	var body := StaticBody3D.new()
	body.position = Vector3(center.x, WALL_HEIGHT / 2.0, center.y)
	body.rotation.y = -(b - a).angle()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.material_override = _rock_material
	body.add_child(mesh)
	add_child(body)
