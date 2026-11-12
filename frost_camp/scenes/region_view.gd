extends Node3D
## 지역 울타리. sim.regions의 사각형 둘레에 바위 벽을 세우고, 입구에는 얼음벽을 둔다.
## 지역을 사면 얼음벽이 사라진다. 확장 땅(open)은 나무 울타리를 두르고, 사면 울타리가 모두 땅속으로 꺼진다.

const WALL_HEIGHT := 1.6
const WALL_THICKNESS := 0.6
const GATE_WIDTH := 3.0
const FenceModel := preload("res://frost_camp/assets/models/survival/fence.glb")
## 울타리 모델 한 칸은 폭 0.5m다. 이만큼 키워 한 칸을 1.5m로 쓴다.
const FENCE_SCALE := 3.0
const FENCE_STEP := 1.5
const SINK_TIME := 0.6

var sim: FrostSim
var region_name: String
var _ice: Node3D
var _open := false
var _walls: Array[StaticBody3D] = []

@onready var _rock_material: StandardMaterial3D = $Templates/Rock.material_override
@onready var _ice_template: Node3D = $Templates/Ice


func setup(frost_sim: FrostSim, name_in_sim: String) -> void:
	sim = frost_sim
	region_name = name_in_sim
	var rect: Rect2 = sim.regions[region_name].rect
	var gate: Vector2 = sim.regions[region_name].gate
	_open = sim.regions[region_name].open
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		_build_edge(corners[i], corners[(i + 1) % 4], gate)
	_ice = _ice_template.duplicate()
	_ice.visible = true
	add_child(_ice)
	var along_x := is_equal_approx(gate.y, rect.position.y) or is_equal_approx(gate.y, rect.end.y)
	_ice.position = Vector3(gate.x, 0.0, gate.y)
	_ice.rotation.y = 0.0 if along_x else PI / 2.0
	# 템플릿의 얼음벽 충돌체가 원점에 남지 않게(길찾기 메시에도 잡히지 않게) 바로 떼어 낸다.
	var templates := $Templates
	remove_child(templates)
	templates.queue_free()
	sim.zone_purchased.connect(_on_zone_purchased)


## 구매 즉시 얼음벽을 떼어 내야 메인 씬이 다시 굽는 길찾기 메시에 입구가 열린다.
func _on_zone_purchased(_id: String, _level: int) -> void:
	if _ice and sim.unlocked.has(region_name):
		remove_child(_ice)
		_ice.queue_free()
		_ice = null
		if _open:
			_sink_walls()


## 충돌체는 바로 떼어(길찾기 메시가 다시 구워질 때 길이 열리게) 두고, 겉모습만 땅속으로 꺼뜨린다.
func _sink_walls() -> void:
	for body in _walls:
		for shape in body.find_children("*", "CollisionShape3D", false, false):
			body.remove_child(shape)
			shape.queue_free()
		var tween := body.create_tween()
		tween.tween_property(body, "position:y", body.position.y - WALL_HEIGHT * 1.2, SINK_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_callback(body.queue_free)
	_walls.clear()


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
	if _open:
		var count := maxi(ceili(length / FENCE_STEP), 1)
		var step := length / count
		for i in count:
			var fence: Node3D = FenceModel.instantiate()
			fence.scale = Vector3(step / 0.5, FENCE_SCALE, FENCE_SCALE)
			fence.position = Vector3(-length / 2.0 + (i + 0.5) * step, -WALL_HEIGHT / 2.0, 0.0)
			body.add_child(fence)
	else:
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = size
		mesh.material_override = _rock_material
		body.add_child(mesh)
	add_child(body)
	_walls.append(body)
