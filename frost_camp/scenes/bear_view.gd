extends Node3D
## 북극곰 한 마리의 겉모습. sim이 움직인 위치를 따라가고, 맞으면 흔들리고, 체력바를 띄운다.
## 서식지 곰과 습격 곰이 같이 쓴다. 습격 곰은 회색 털에 조금 더 크고, 쓰러지면 넘어진 뒤 사라진다.
## 모델은 스테이지 theme.json의 bear다(tools/meshy_quadruped.py로 다리 4개를 뗀 모델: 키 1, 발 0, 머리 +Z).
## 보스 습격(raid_view.gd)도 add_model()과 swing_legs()로 같은 모델을 쓴다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const Graphics := preload("res://frost_camp/scenes/graphics.gd")
const FUR_COLOR := Color(0.96, 0.93, 0.85)
const RAIDER_FUR := Color(0.4, 0.38, 0.4)
const RAIDER_SCALE := 1.2
## 곰 모델의 키(m)
const HEIGHT := 1.45

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
	add_model(_body, RAIDER_FUR if raider else Color.WHITE)
	add_to_group(Graphics.GROUP)
	if raider:
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
	swing_legs(_body, swing)
	position = target
	_hp_bar.visible = bear.hp < bear.max_hp
	_hp_fill.scale.x = maxf(float(bear.hp) / bear.max_hp, 0.001)
	# 맞은 만큼(작살이든 포탑이든) 숫자를 띄운다. 리스폰으로 체력이 차면 그냥 맞춘다.
	if bear.hp < _last_hp:
		Juice.float_text(self, global_position + Vector3(0.0, 2.0, 0.0), "-%d" % (_last_hp - bear.hp), Color(1.0, 0.45, 0.4))
	_last_hp = bear.hp


## 몸(body) 아래에 곰 모델을 붙인다. fur가 흰색이 아니면 털 텍스처에 그 색을 곱한다.
static func add_model(body: Node3D, fur: Color = Color.WHITE) -> void:
	var model: Node3D = load(Graphics.model(GameData.theme().bear)).instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * HEIGHT
	model.rotation.y = PI  # 모델 머리는 +Z, 이 게임의 앞은 -Z다.
	body.add_child(model)
	if fur == Color.WHITE:
		return
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var material: StandardMaterial3D = mesh.get_active_material(0).duplicate()
		material.albedo_color = fur
		mesh.material_override = material


## 대각선 다리끼리 같이 앞뒤로 흔든다.
static func swing_legs(body: Node3D, swing: float) -> void:
	for leg in ["LegFL", "LegBR"]:
		body.get_node("Model/" + leg).rotation.x = swing
	for leg in ["LegFR", "LegBL"]:
		body.get_node("Model/" + leg).rotation.x = -swing


## 그래픽 단계가 바뀌면 모델을 다시 붙인다(graphics.gd가 부른다).
func refresh_models() -> void:
	_body.get_node("Model").free()
	add_model(_body, RAIDER_FUR if raider else Color.WHITE)


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
