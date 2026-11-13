extends Node3D
## 모닥불의 겉모습. 따뜻한 범위를 바닥 원판으로 보여 준다.
## "모닥불 키우기"를 사면 원판이 부드럽게 넓어지고 불꽃도 커진다.

const GROW_TIME := 0.6
## 레벨마다 불꽃이 이만큼 더 커진다
const FLAME_GROWTH := 0.35

var sim: FrostSim
var index: int
var _shown_level := 0

@onready var _flame: Node3D = $Flame
@onready var _range: Node3D = $Range


func setup(frost_sim: FrostSim, source_index: int) -> void:
	sim = frost_sim
	index = source_index
	var source := sim.heat_sources[index]
	position = Vector3(source.pos.x, 0.0, source.pos.y)
	_range.scale = Vector3(source.radius, 1.0, source.radius)
	$Stove.queue_free()
	var tween := create_tween().set_loops()
	tween.tween_property(_flame, "scale", Vector3(1.15, 1.25, 1.15), 0.18)
	tween.tween_property(_flame, "scale", Vector3(0.9, 0.85, 0.9), 0.22)


func _process(_delta: float) -> void:
	var source := sim.heat_sources[index]
	if source.level == _shown_level:
		return
	_shown_level = source.level
	create_tween().tween_property(_range, "scale", Vector3(source.radius, 1.0, source.radius), GROW_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var size: Vector3 = Vector3.ONE * (1.0 + FLAME_GROWTH * source.level)
	$Campfire.scale = size * Vector3(1.4, 0.6, 1.4)
	create_tween().tween_property($Campfire, "scale", size, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flame.position.y = 0.45 + 0.3 * source.level
