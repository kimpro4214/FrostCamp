extends Node3D
## 북극곰 한 마리의 겉모습. sim이 움직인 위치를 따라가고, 맞으면 흔들리고, 체력바를 띄운다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const FUR_COLOR := Color(0.96, 0.93, 0.85)

var sim: FrostSim
var index: int
var _fur: CPUParticles3D

@onready var _body: Node3D = $Body
@onready var _hp_bar: Node3D = $HpBar
@onready var _hp_fill: Node3D = $HpBar/Fill


func setup(frost_sim: FrostSim, bear_index: int) -> void:
	sim = frost_sim
	index = bear_index
	_fur = Juice.make_burst(self, FUR_COLOR, 8, 0.14)
	_fur.position.y = 0.9
	sim.bear_hit.connect(_on_bear_hit)
	_sync(true)


func _process(_delta: float) -> void:
	_sync(false)


func _sync(snap: bool) -> void:
	var bear := sim.bears[index]
	visible = bear.is_alive()
	var target := Vector3(bear.pos.x, 0.0, bear.pos.y)
	var step := target - position
	if not snap and step.length() > 0.001:
		_body.rotation.y = atan2(-step.x, -step.z)
	position = target
	_hp_bar.visible = bear.hp < bear.max_hp
	_hp_fill.scale.x = maxf(float(bear.hp) / bear.max_hp, 0.001)


func _on_bear_hit(hit_index: int, _agent: SimAgent) -> void:
	if hit_index != index:
		return
	_fur.restart()
	Juice.float_text(self, global_position + Vector3(0.0, 2.0, 0.0), "-%d" % sim.stats.harpoon_damage, Color(1.0, 0.45, 0.4))
	var tween := create_tween()
	tween.tween_property(_body, "scale", Vector3(1.15, 0.85, 1.15), 0.05)
	tween.tween_property(_body, "scale", Vector3.ONE, 0.12)
