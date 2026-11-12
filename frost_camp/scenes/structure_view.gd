extends Node3D
## 기지 시설 하나의 체력 표시. 다치면 머리 위에 체력바가 뜨고, 맞을 때마다 빨간 숫자와 흔들림이 나온다.
## 부서지면 대상 모델이 기울고 어두워지며 연기가 나고, 수리되면 원래대로 튀어 오른다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const BAR_WIDTH := 1.6
const BAR_HEIGHT := 0.16
## 시설 종류별 체력바 높이
const BAR_Y := {"stall": 2.4, "woodpile": 1.8, "tower": 2.9}
const FULL_COLOR := Color(0.35, 0.85, 0.4)
const LOW_COLOR := Color(0.95, 0.3, 0.25)
const BROKEN_TILT := 0.3

var sim: FrostSim
var index: int
var _target: Node3D
var _bar: Node3D
var _fill: MeshInstance3D
var _fill_material: StandardMaterial3D
var _smoke: CPUParticles3D
var _dark: StandardMaterial3D
var _base_position: Vector3
var _base_scale: Vector3


## target은 부서질 때 기울이고 어둡게 만들 모델이다.
func setup(frost_sim: FrostSim, structure_index: int, target: Node3D) -> void:
	sim = frost_sim
	index = structure_index
	_target = target
	_base_position = target.position
	_base_scale = target.scale
	var structure := sim.structures[index]
	position = Vector3(structure.pos.x, 0.0, structure.pos.y)
	_build_bar(BAR_Y.get(structure.kind, 2.0))
	_build_smoke()
	_dark = StandardMaterial3D.new()
	_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dark.albedo_color = Color(0.08, 0.06, 0.06, 0.55)
	sim.structure_hit.connect(_on_hit)
	sim.structure_broken.connect(_on_broken)
	sim.structure_repaired.connect(_on_repaired)


func _process(_delta: float) -> void:
	var structure := sim.structures[index]
	_bar.visible = structure.hp < structure.max_hp
	var ratio := float(structure.hp) / structure.max_hp
	_fill.scale.x = maxf(ratio, 0.001)
	_fill.position.x = -BAR_WIDTH * (1.0 - ratio) / 2.0
	_fill_material.albedo_color = LOW_COLOR.lerp(FULL_COLOR, ratio)


func _build_bar(height: float) -> void:
	_bar = Node3D.new()
	_bar.position.y = height
	add_child(_bar)
	var back := MeshInstance3D.new()
	back.mesh = _box(Vector3(BAR_WIDTH + 0.08, BAR_HEIGHT + 0.08, 0.04), Color(0.1, 0.1, 0.14))
	_bar.add_child(back)
	_fill = MeshInstance3D.new()
	_fill.mesh = _box(Vector3(BAR_WIDTH, BAR_HEIGHT, 0.06), FULL_COLOR)
	_fill_material = _fill.mesh.material
	_bar.add_child(_fill)
	_bar.visible = false


func _build_smoke() -> void:
	_smoke = CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.3, 0.3, 0.32, 0.6)
	mesh.material = material
	_smoke.mesh = mesh
	_smoke.emitting = false
	_smoke.amount = 10
	_smoke.lifetime = 1.6
	_smoke.position.y = 0.8
	_smoke.direction = Vector3.UP
	_smoke.spread = 20.0
	_smoke.gravity = Vector3(0.0, 0.6, 0.0)
	_smoke.initial_velocity_min = 0.6
	_smoke.initial_velocity_max = 1.2
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.4
	add_child(_smoke)


static func _box(size: Vector3, color: Color) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	box.material = material
	return box


func _on_hit(hit_index: int, damage: int) -> void:
	if hit_index != index:
		return
	Juice.float_text(self, global_position + Vector3(0.0, _bar.position.y + 0.4, 0.0), "-%d" % damage, LOW_COLOR)
	var tween := create_tween()
	tween.tween_property(_target, "position", _base_position + Vector3(0.12, 0.0, 0.0), 0.04)
	tween.tween_property(_target, "position", _base_position + Vector3(-0.08, 0.0, 0.0), 0.05)
	tween.tween_property(_target, "position", _base_position, 0.06)


func _on_broken(broken_index: int) -> void:
	if broken_index != index:
		return
	create_tween().tween_property(_target, "rotation:z", BROKEN_TILT, 0.25) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_set_dark(true)
	_smoke.emitting = true


func _on_repaired(repaired_index: int) -> void:
	if repaired_index != index:
		return
	_target.rotation.z = 0.0
	_set_dark(false)
	_smoke.emitting = false
	_target.scale = _base_scale * Vector3(1.2, 0.8, 1.2)
	create_tween().tween_property(_target, "scale", _base_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.float_text(self, global_position + Vector3(0.0, _bar.position.y, 0.0), "수리 완료", FULL_COLOR, 56)


func _set_dark(dark: bool) -> void:
	for mesh in _target.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _dark if dark else null
