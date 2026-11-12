extends Node3D
## 부두의 쇄빙선. 아직 사지 않은 부품은 반투명 윤곽으로 보여서 목표가 눈에 들어온다.

const GhostMaterial := preload("res://frost_camp/scenes/ghost_material.tres")

var sim: FrostSim
## 해금 이름 → 그 부품의 메시들
var _parts := {}


func setup(frost_sim: FrostSim) -> void:
	sim = frost_sim
	position = Vector3(sim.ship_pos.x, 0.0, sim.ship_pos.y)
	for part in $Parts.get_children():
		_parts["ship_" + part.name.to_lower()] = part.find_children("*", "MeshInstance3D")


func _process(_delta: float) -> void:
	for unlock in _parts:
		var material: Material = null if sim.unlocked.has(unlock) else GhostMaterial
		for mesh in _parts[unlock]:
			mesh.material_override = material


## 엔딩 연출: 배가 바다로 떠난다.
func sail_away(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + 45.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished
