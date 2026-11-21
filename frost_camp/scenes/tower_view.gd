extends Node3D
## 작살 포탑 하나의 겉모습. 사기 전에는 숨어 있다가 사면 솟아오르고,
## 쏠 때마다 발사대가 곰 쪽으로 돌고 작살이 날아간다.
## 레벨마다 받침대와 발사대 모델이 다르다(스테이지 theme.json의 towers: 1레벨 나무 받침대·노포, 2레벨 돌 받침대·작살 대포).
## 모델은 키 1, 가운데가 원점인 소품(tools/meshy_prop.py)이고, 발사대는 앞(작살 끝)이 -X를 본다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const Graphics := preload("res://frost_camp/scenes/graphics.gd")
const METAL := Color(0.62, 0.66, 0.72)
const BOLT_TIME := 0.12
## 발사대 모델의 앞(-X)을 이 게임의 앞(-Z)으로 돌리는 각도
const LAUNCHER_TURN := -PI / 2.0

var sim: FrostSim
var index: int
## 부서질 때 기울이고 어둡게 만들 모델(체력 표시가 쓴다)
var model: Node3D
var _launcher: Node3D
var _collision: CollisionShape3D
var _shown_level := -1


func setup(frost_sim: FrostSim, tower_index: int) -> void:
	sim = frost_sim
	index = tower_index
	var tower: Dictionary = sim.towers[index]
	position = Vector3(tower.pos.x, 0.0, tower.pos.y)
	model = Node3D.new()
	add_child(model)
	_launcher = Node3D.new()
	model.add_child(_launcher)
	add_to_group(Graphics.GROUP)
	var body := StaticBody3D.new()
	_collision = CollisionShape3D.new()
	_collision.shape = CylinderShape3D.new()
	_collision.shape.radius = 0.7
	_collision.shape.height = 2.0
	_collision.position.y = 1.0
	body.add_child(_collision)
	add_child(body)
	sim.tower_fired.connect(_on_fired)
	_refresh(false)


func _process(_delta: float) -> void:
	_refresh(true)


func _refresh(animate: bool) -> void:
	var level: int = sim.towers[index].level
	if level == _shown_level:
		return
	_shown_level = level
	visible = level > 0
	_collision.disabled = level == 0
	_build_models()
	if animate and level > 0:
		Juice.pop(model, Vector3(0.4, 1.5, 0.4), 0.4)


## 지금 레벨과 그래픽 단계에 맞는 받침대와 발사대를 붙인다. 발사대가 보던 방향은 그대로 둔다.
func _build_models() -> void:
	for child in model.get_children():
		if child != _launcher:
			child.free()
	for child in _launcher.get_children():
		child.free()
	if _shown_level <= 0:
		return
	var looks: Array = GameData.theme().towers
	var look: Dictionary = looks[mini(_shown_level, looks.size()) - 1]
	var base := _prop(look.base, look.base_height)
	model.add_child(base)
	var launcher := _prop(look.launcher, look.launcher_height)
	launcher.rotation.y = LAUNCHER_TURN
	_launcher.add_child(launcher)
	_launcher.position.y = float(look.top)


## 그래픽 단계가 바뀌면 모델을 다시 붙인다(graphics.gd가 부른다).
func refresh_models() -> void:
	_build_models()


## 키 1, 가운데가 원점인 소품 모델을 키 height로 키워 발이 0에 오게 한다.
func _prop(path: String, height: float) -> Node3D:
	var prop: Node3D = load(Graphics.model(path)).instantiate()
	prop.scale = Vector3.ONE * height
	prop.position.y = height / 2.0
	return prop


func _on_fired(tower_index: int, raider_index: int) -> void:
	if tower_index != index:
		return
	var target := sim.raid.bears[raider_index].pos
	var to := Vector3(target.x, 1.0, target.y)
	var from := _launcher.global_position
	_launcher.rotation.y = atan2(-(to.x - from.x), -(to.z - from.z))
	var bolt := _mesh(_cylinder(0.05, 0.05, 0.7), METAL)
	get_parent().add_child(bolt)
	bolt.global_position = from
	bolt.look_at_from_position(from, to, Vector3.UP)
	bolt.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "global_position", to, BOLT_TIME)
	tween.tween_callback(bolt.queue_free)
	Juice.pop(_launcher, Vector3(1.0, 1.0, 1.4), 0.15)


static func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	instance.mesh = mesh
	return instance


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh

