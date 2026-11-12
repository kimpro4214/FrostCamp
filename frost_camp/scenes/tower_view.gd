extends Node3D
## 작살 포탑 하나의 겉모습. 사기 전에는 숨어 있다가 사면 솟아오르고,
## 쏠 때마다 발사대가 곰 쪽으로 돌고 작살이 날아간다. 2레벨부터 지붕이 금속색이 된다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const WOOD := Color(0.55, 0.38, 0.24)
const ROOF := Color(0.75, 0.3, 0.25)
const METAL := Color(0.62, 0.66, 0.72)
const BOLT_TIME := 0.12

var sim: FrostSim
var index: int
## 부서질 때 기울이고 어둡게 만들 모델(체력 표시가 쓴다)
var model: Node3D
var _launcher: Node3D
var _roof_material: StandardMaterial3D
var _collision: CollisionShape3D
var _shown_level := -1


func setup(frost_sim: FrostSim, tower_index: int) -> void:
	sim = frost_sim
	index = tower_index
	var tower: Dictionary = sim.towers[index]
	position = Vector3(tower.pos.x, 0.0, tower.pos.y)
	model = Node3D.new()
	add_child(model)
	var post := _mesh(_cylinder(0.45, 0.6, 1.8), WOOD)
	post.position.y = 0.9
	model.add_child(post)
	var roof := _mesh(_box(Vector3(1.3, 0.25, 1.3)), ROOF)
	roof.position.y = 1.9
	_roof_material = roof.mesh.material
	model.add_child(roof)
	_launcher = Node3D.new()
	_launcher.position.y = 2.25
	model.add_child(_launcher)
	var barrel := _mesh(_cylinder(0.12, 0.12, 1.2), METAL)
	barrel.rotation.x = -PI / 2.0  # 실린더를 눕혀 -Z(앞)를 향하게
	barrel.position.z = -0.3
	_launcher.add_child(barrel)
	var body := StaticBody3D.new()
	_collision = CollisionShape3D.new()
	_collision.shape = CylinderShape3D.new()
	_collision.shape.radius = 0.6
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
	_roof_material.albedo_color = METAL if level >= 2 else ROOF
	if animate and level > 0:
		Juice.pop(model, Vector3(0.4, 1.5, 0.4), 0.4)


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


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
