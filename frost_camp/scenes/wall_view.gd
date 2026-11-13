extends Node3D
## 기지 방벽. 구간마다 충돌체를 붙이고, 방벽 레벨에 따라 모습을 바꾼다.
## 1단계 나무 울타리, 2단계 돌담, 3단계 철벽. 레벨이 오르면 구간마다 차례로 새 모습이 솟는다.
## 방벽을 사면 솟아오르고, 확장으로 안쪽이 된 구간은 땅속으로 꺼지며, 바깥 구간이 새로 솟는다.
## 부서진 구간은 지나갈 수 있다.

const FenceModel := preload("res://frost_camp/assets/models/survival/fence-fortified.glb")
const MetalModel := preload("res://frost_camp/assets/models/survival/structure-metal-wall.glb")
## 나무 울타리 모델 한 칸은 폭 0.5m, 철벽 모델 한 칸은 폭 0.535m다. 한 칸을 약 1.5m로 키운다.
const FENCE_WIDTH := 0.5
const METAL_WIDTH := 0.535
const STEP := 1.5
const MODEL_SCALE := 3.0
const WALL_HEIGHT := 1.6
const WALL_THICKNESS := 0.6
const STONE_HEIGHT := 1.5
const STONE_THICKNESS := 0.8
const MERLON_GAP := 1.2
const STONE_COLOR := Color(0.6, 0.6, 0.62)
const RISE_TIME := 0.5
## 레벨이 바뀔 때 구간마다 이만큼 늦게 솟는다(초)
const STAGGER := 0.05
## 레벨 → 모습 노드 이름
const LOOKS := ["Wood", "Stone", "Metal"]

var sim: FrostSim
## 시설 번호 → 구간 모델(체력 표시가 기울이고 어둡게 만든다)
var models := {}
var _bodies := {}
var _shown := {}
var _shown_level := 0
var _stone: StandardMaterial3D


func setup(frost_sim: FrostSim, layout_walls: Array) -> void:
	sim = frost_sim
	add_to_group("nav_source")
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = STONE_COLOR
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
	model.add_child(_tiled("Wood", FenceModel, FENCE_WIDTH, length))
	model.add_child(_stone_wall(length))
	model.add_child(_tiled("Metal", MetalModel, METAL_WIDTH, length))
	add_child(body)
	models[index] = model
	_bodies[index] = body
	_shown[index] = false
	body.visible = false
	body.collision_layer = 0


## 모델 한 칸을 구간 길이에 맞춰 줄지어 세운다.
func _tiled(look: String, scene: PackedScene, width: float, length: float) -> Node3D:
	var root := Node3D.new()
	root.name = look
	var count := maxi(ceili(length / STEP), 1)
	var step := length / count
	for i in count:
		var piece: Node3D = scene.instantiate()
		piece.scale = Vector3(step / width, MODEL_SCALE, MODEL_SCALE)
		piece.position = Vector3(-length / 2.0 + (i + 0.5) * step, 0.0, 0.0)
		root.add_child(piece)
	return root


## 돌담: 긴 돌 벽 위에 톱니(성가퀴)를 일정 간격으로 올린다.
func _stone_wall(length: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Stone"
	var wall := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length + STONE_THICKNESS, STONE_HEIGHT, STONE_THICKNESS)
	mesh.material = _stone
	wall.mesh = mesh
	wall.position.y = STONE_HEIGHT / 2.0
	root.add_child(wall)
	var merlon_mesh := BoxMesh.new()
	merlon_mesh.size = Vector3(0.5, 0.35, STONE_THICKNESS)
	merlon_mesh.material = _stone
	for i in int(length / MERLON_GAP) + 1:
		var merlon := MeshInstance3D.new()
		merlon.mesh = merlon_mesh
		merlon.position = Vector3(-length / 2.0 + i * MERLON_GAP, STONE_HEIGHT + 0.17, 0.0)
		root.add_child(merlon)
	return root


## 구간이 생기거나 사라지면 솟거나 꺼지고, 충돌은 서 있는 구간에만 둔다. 레벨이 바뀌면 모습을 바꾼다.
func _refresh(animate: bool) -> void:
	if sim.wall_level != _shown_level:
		_shown_level = sim.wall_level
		_show_look(animate)
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


## 지금 레벨의 모습만 보이게 하고, 새 모습은 구간마다 조금씩 늦게 아래에서 솟게 한다.
func _show_look(animate: bool) -> void:
	var look: String = LOOKS[clampi(sim.wall_level, 1, LOOKS.size()) - 1]
	var order := 0
	for index in models:
		var model: Node3D = models[index]
		for child in model.get_children():
			child.visible = child.name == look
		if not animate or not _shown[index]:
			continue
		var shown: Node3D = model.get_node(look)
		shown.scale = Vector3(1.0, 0.05, 1.0)
		var tween := shown.create_tween()
		tween.tween_interval(order * STAGGER)
		tween.tween_property(shown, "scale", Vector3.ONE, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		order += 1
