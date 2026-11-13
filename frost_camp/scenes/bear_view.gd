extends Node3D
## 북극곰 한 마리의 겉모습. sim이 움직인 위치를 따라가고, 맞으면 흔들리고, 체력바를 띄운다.
## 서식지 곰과 습격 곰이 같이 쓴다. 습격 곰은 회색 털에 조금 더 크고, 쓰러지면 넘어진 뒤 사라진다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const FUR_COLOR := Color(0.96, 0.93, 0.85)
const RAIDER_FUR := Color(0.4, 0.38, 0.4)
const RAIDER_SCALE := 1.2

var sim: FrostSim
## HarvestBear 또는 RaidBear
var bear: RefCounted
var raider := false
var _fur: CPUParticles3D
var _dying := false
var _last_hp := 0
var _body_scale := Vector3.ONE
## 걷는 동안 다리를 흔드는 위상
var _walk := 0.0
const WALK_SWING := 0.5
const WALK_RATE := 9.0

@onready var _body: Node3D = $Body
@onready var _hp_bar: Node3D = $HpBar
@onready var _hp_fill: Node3D = $HpBar/Fill


func setup(frost_sim: FrostSim, sim_bear: RefCounted, is_raider: bool) -> void:
	sim = frost_sim
	bear = sim_bear
	raider = is_raider
	var fur_color := RAIDER_FUR if raider else FUR_COLOR
	_fur = Juice.make_burst(self, fur_color, 8, 0.14)
	_fur.position.y = 0.9
	if raider:
		var material := StandardMaterial3D.new()
		material.albedo_color = RAIDER_FUR
		for part in _body.get_children():
			if not part.name in ["Nose", "EyeL", "EyeR"]:
				part.material_override = material
		_body.scale = Vector3.ONE * RAIDER_SCALE
		sim.raider_hit.connect(func(i: int, _agent: SimAgent) -> void:
			if sim.raid.bears[i] == bear:
				_on_hit())
		sim.raider_killed.connect(func(i: int, _agent: SimAgent) -> void:
			if sim.raid.bears[i] == bear:
				_on_raider_killed())
	else:
		sim.bear_hit.connect(func(i: int, _agent: SimAgent) -> void:
			if sim.bears[i] == bear:
				_on_hit())
	_body_scale = _body.scale
	_last_hp = bear.hp
	_sync(true)


func _process(_delta: float) -> void:
	if not _dying:
		_sync(false)


func _sync(snap: bool) -> void:
	visible = bear.is_alive()
	var target := Vector3(bear.pos.x, 0.0, bear.pos.y)
	var step := target - position
	var moving := not snap and step.length() > 0.001
	if moving:
		_body.rotation.y = atan2(-step.x, -step.z)
	_walk = _walk + get_process_delta_time() * WALK_RATE if moving else 0.0
	var swing := sin(_walk) * WALK_SWING if moving else 0.0
	for leg in ["LegFL", "LegBR"]:
		_body.get_node(leg).rotation.x = swing
	for leg in ["LegFR", "LegBL"]:
		_body.get_node(leg).rotation.x = -swing
	position = target
	_hp_bar.visible = bear.hp < bear.max_hp
	_hp_fill.scale.x = maxf(float(bear.hp) / bear.max_hp, 0.001)
	# 맞은 만큼(작살이든 포탑이든) 숫자를 띄운다. 리스폰으로 체력이 차면 그냥 맞춘다.
	if bear.hp < _last_hp:
		Juice.float_text(self, global_position + Vector3(0.0, 2.0, 0.0), "-%d" % (_last_hp - bear.hp), Color(1.0, 0.45, 0.4))
	_last_hp = bear.hp


func _on_hit() -> void:
	_fur.restart()
	var tween := create_tween()
	tween.tween_property(_body, "scale", _body_scale * Vector3(1.15, 0.85, 1.15), 0.05)
	tween.tween_property(_body, "scale", _body_scale, 0.12)


## 습격 곰은 리스폰하지 않으니 옆으로 쓰러진 뒤 사라진다.
func _on_raider_killed() -> void:
	_sync(false)
	_dying = true
	visible = true
	_hp_bar.visible = false
	var tween := create_tween()
	tween.tween_property(_body, "rotation:z", PI / 2.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.6)
	tween.tween_property(self, "scale", Vector3(1.0, 0.01, 1.0), 0.25)
	tween.tween_callback(queue_free)
