extends Node3D
## 부두의 쇄빙선. 아직 사지 않은 부품은 반투명 윤곽으로 보여서 목표가 눈에 들어온다.
## 앞바다에는 얼음 조각이 떠 있고, 엔딩에 배가 지나가면 뱃머리에 밀려 갈라진다.

const GhostMaterial := preload("res://frost_camp/scenes/ghost_material.tres")
const Juice := preload("res://frost_camp/scenes/juice.gd")

var sim: FrostSim
## 해금 이름 → 그 부품의 메시들
var _parts := {}
const ICE_COUNT := 46
const ICE_SEED := 7
const BOW := 4.2  # 배 기준 뱃머리 x
const SAIL_DISTANCE := 70.0
var _floes: Array[MeshInstance3D] = []
var _sailing := false
var _sail_time := 0.0
var _spray: CPUParticles3D


func setup(frost_sim: FrostSim) -> void:
	sim = frost_sim
	position = Vector3(sim.ship_pos.x, 0.0, sim.ship_pos.y)
	for part in $Parts.get_children():
		_parts["ship_" + part.name.to_lower()] = part.find_children("*", "MeshInstance3D")
	_scatter_ice()
	_spray = Juice.make_burst(self, Color(0.9, 0.96, 1.0), 14, 0.16)
	_spray.one_shot = false
	_spray.position = Vector3(BOW, 0.4, 0.0)
	_spray.direction = Vector3(-0.3, 1.0, 0.0)


func _process(delta: float) -> void:
	if _sailing:
		_sail_time += delta
		rotation.z = sin(_sail_time * 2.2) * 0.035
		rotation.x = sin(_sail_time * 1.6) * 0.025
		_push_ice()
	for unlock in _parts:
		var material: Material = null if sim.unlocked.has(unlock) else GhostMaterial
		for mesh in _parts[unlock]:
			if mesh.material_override == GhostMaterial and material == null:
				Juice.pop(mesh, Vector3(1.3, 0.6, 1.3), 0.35)
			mesh.material_override = material


## 엔딩 연출: 배가 천천히 출발해 속도를 붙이며 바다로 떠난다. 흔들리며 물보라를 뿌리고 얼음을 밀어낸다.
func sail_away(duration: float) -> void:
	_sailing = true
	_spray.emitting = true
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + SAIL_DISTANCE, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_sailing = false
	_spray.emitting = false


## 배 앞바다(배 경로와 그 양옆)에 얼음 조각을 고정된 배치로 띄운다.
func _scatter_ice() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = ICE_SEED
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.95, 1.0)
	for i in ICE_COUNT:
		var floe := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rng.randf_range(1.0, 2.6), 0.3, rng.randf_range(0.9, 2.2))
		mesh.material = material
		floe.mesh = mesh
		var side := rng.randf_range(-9.0, 9.0)
		floe.position = Vector3(position.x + rng.randf_range(6.0, SAIL_DISTANCE - 4.0), 0.08, position.z + side)
		floe.rotation.y = rng.randf_range(0.0, TAU)
		_floes.append(floe)
	for floe in _floes:
		get_parent().add_child.call_deferred(floe)


## 뱃머리에 닿은 얼음 조각을 옆으로 밀어내며 기울여 가라앉힌다.
func _push_ice() -> void:
	var bow := position.x + BOW
	for floe in _floes:
		if floe.has_meta("pushed") or absf(floe.position.x - bow) > 1.5 or absf(floe.position.z - position.z) > 3.0:
			continue
		floe.set_meta("pushed", true)
		var away := signf(floe.position.z - position.z)
		if away == 0.0:
			away = 1.0
		var tween := floe.create_tween().set_parallel()
		tween.tween_property(floe, "position:z", floe.position.z + away * 3.5, 0.8).set_ease(Tween.EASE_OUT)
		tween.tween_property(floe, "rotation:x", away * 0.5, 0.8)
		tween.tween_property(floe, "position:y", -0.15, 0.8)
