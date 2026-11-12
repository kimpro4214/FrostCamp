extends Node3D
## 열원(모닥불, 난로)의 겉모습. 따뜻한 범위를 바닥 원판으로 보여 주고, 켜지기 전에는 숨는다.

var sim: FrostSim
var index: int

@onready var _flame: Node3D = $Flame


func setup(frost_sim: FrostSim, source_index: int) -> void:
	sim = frost_sim
	index = source_index
	var source := sim.heat_sources[index]
	position = Vector3(source.pos.x, 0.0, source.pos.y)
	$Range.scale = Vector3(source.radius, 1.0, source.radius)
	$Campfire.visible = source.id == "campfire"
	$Stove.visible = source.id == "stove"
	$Stove/CollisionShape3D.disabled = true
	if source.id == "stove":
		_flame.position.y = 1.2
	var tween := create_tween().set_loops()
	tween.tween_property(_flame, "scale", Vector3(1.15, 1.25, 1.15), 0.18)
	tween.tween_property(_flame, "scale", Vector3(0.9, 0.85, 0.9), 0.22)


func _process(_delta: float) -> void:
	var source := sim.heat_sources[index]
	visible = sim.is_heat_active(source)
	if source.id == "stove":
		$Stove/CollisionShape3D.disabled = not visible
