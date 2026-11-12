extends Node3D
## 기지 방벽. 구간마다 튼튼한 울타리 모델을 줄지어 세우고 충돌체를 붙인다.
## 방벽을 사면 솟아오르고, 확장으로 안쪽이 된 구간은 땅속으로 꺼지며, 바깥 구간이 새로 솟는다.
## 3레벨부터는 높아지고 금속색을 덧칠한다. 부서진 구간은 지나갈 수 있다.

const FenceModel := preload("res://frost_camp/assets/models/survival/fence-fortified.glb")
## 모델 한 칸은 폭 0.5m다. 이만큼 키워 한 칸을 1.5m로 쓴다.
const FENCE_SCALE := 3.0
const FENCE_STEP := 1.5
const WALL_HEIGHT := 1.6
const WALL_THICKNESS := 0.6
const RISE_TIME := 0.5
const HIGH_LEVEL := 3
const HIGH_SCALE := 1.4

var sim: FrostSim
## 시설 번호 → 구간 모델(체력 표시가 기울이고 어둡게 만든다)
var models := {}
var _bodies := {}
var _shown := {}
var _shown_level := 0
var _metal: StandardMaterial3D


func setup(frost_sim: FrostSim, layout_walls: Array) -> void:
	sim = frost_sim
	add_to_group("nav_source")
	_metal = StandardMaterial3D.new()
	_metal.albedo_color = Color(0.55, 0.6, 0.68, 0.45)
	_metal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for n in sim.walls.size():
		_build(sim.walls[n], layout_walls[n])
	_refresh(false)


func _process(_delta: float) -> void:
	_refresh(true)


func _build(index: int, w: Dictionary) -> void:
	var a := Vector2(w.a[0], w.a[1])
	var b := Vector2(w.b[0], w.b[1])
	var length := a.distance_to(b)
	var body := StaticBody3D.new()
	body.position = Vector3((a.x + b.x) / 2.0, 0.0, (a.y + b.y) / 2.0)
	body.rotation.y = -(b - a).angle()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(length + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS)
	shape.position.y = WALL_HEIGHT / 2.0
	body.add_child(shape)
	var model := Node3D.new()
	body.add_child(model)
	var count := maxi(ceili(length / FENCE_STEP), 1)
	var step := length / count
	for i in count:
		var fence: Node3D = FenceModel.instantiate()
		fence.scale = Vector3(step / 0.5, FENCE_SCALE, FENCE_SCALE)
		fence.position = Vector3(-length / 2.0 + (i + 0.5) * step, 0.0, 0.0)
		model.add_child(fence)
	add_child(body)
	models[index] = model
	_bodies[index] = body
	_shown[index] = false
	body.visible = false
	body.collision_layer = 0


## 구간이 생기거나 사라지면 솟거나 꺼지고, 충돌은 서 있는 구간에만 둔다.
func _refresh(animate: bool) -> void:
	if sim.wall_level != _shown_level:
		_shown_level = sim.wall_level
		var high := sim.wall_level >= HIGH_LEVEL
		for index in models:
			var model: Node3D = models[index]
			model.scale = Vector3(1.0, HIGH_SCALE if high else 1.0, 1.0)
			for mesh in model.find_children("*", "MeshInstance3D", true, false):
				mesh.material_overlay = _metal if high else null
	for index in models:
		var active := sim.is_structure_active(index)
		var body: StaticBody3D = _bodies[index]
		body.collision_layer = 1 if active and not sim.structures[index].is_broken() else 0
		if active == _shown[index]:
			continue
		_shown[index] = active
		if active:
			body.visible = true
			if animate:
				body.position.y = -WALL_HEIGHT * 1.5
				body.create_tween().tween_property(body, "position:y", 0.0, RISE_TIME) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif animate:
			var tween := body.create_tween()
			tween.tween_property(body, "position:y", -WALL_HEIGHT * 1.5, RISE_TIME).set_ease(Tween.EASE_IN)
			tween.tween_callback(func() -> void: body.visible = false)
		else:
			body.visible = false
