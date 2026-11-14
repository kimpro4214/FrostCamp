extends Node3D
## 플레이어 작살총의 겉모습. 쏠 때마다 총구 섬광이 번쩍이고 작살이 가슴 높이에서 곰까지 날아간다.
## 곰 쪽을 보고 총을 쏘는 동작은 player.gd가 맡는다.

const BOLT_TIME := 0.12
const BOLT_COLOR := Color(0.62, 0.66, 0.72)
const CHEST := 0.8

var sim: FrostSim
var _player: Node3D
var _bolt_mesh: CylinderMesh


func setup(frost_sim: FrostSim, player: Node3D) -> void:
	sim = frost_sim
	_player = player
	_bolt_mesh = CylinderMesh.new()
	_bolt_mesh.top_radius = 0.04
	_bolt_mesh.bottom_radius = 0.04
	_bolt_mesh.height = 0.7
	var material := StandardMaterial3D.new()
	material.albedo_color = BOLT_COLOR
	_bolt_mesh.material = material
	sim.gun_fired.connect(_on_fired)


func _on_fired(raider_index: int) -> void:
	var target := sim.raid.bears[raider_index].pos
	var from := _player.global_position + Vector3(0.0, CHEST, 0.0)
	var to := Vector3(target.x, CHEST, target.y)
	_flash(from + (to - from).normalized() * 0.6)
	var bolt := MeshInstance3D.new()
	bolt.mesh = _bolt_mesh
	add_child(bolt)
	bolt.look_at_from_position(from, to, Vector3.UP)
	bolt.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "global_position", to, BOLT_TIME)
	tween.tween_callback(bolt.queue_free)


## 총구 앞에 노란 섬광이 잠깐 번쩍인다.
func _flash(at: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.85, 0.35)
	mesh.material = material
	flash.mesh = mesh
	add_child(flash)
	flash.global_position = at
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 0.1, 0.12)
	tween.tween_callback(flash.queue_free)
