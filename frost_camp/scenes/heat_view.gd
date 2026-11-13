extends Node3D
## 모닥불의 겉모습. 따뜻한 범위를 바닥 원판으로 보여 준다.
## "모닥불 키우기"를 사면 원판이 부드럽게 넓어지고 불꽃도 커진다.
## 위에 연료 막대를 띄우고, 연료가 다 떨어지면 불꽃과 원판이 사라지고 연기만 난다.

const GROW_TIME := 0.6
## 레벨마다 불꽃이 이만큼 더 커진다
const FLAME_GROWTH := 0.35
const Juice := preload("res://frost_camp/scenes/juice.gd")
const BAR_WIDTH := 1.4
const BAR_HEIGHT := 0.16
const BAR_Y := 2.3
const FUEL_COLOR := Color(1.0, 0.65, 0.2)
const LOW_COLOR := Color(0.95, 0.25, 0.2)
## 연료가 이 비율 밑이면 막대가 빨개진다
const LOW_FUEL := 0.3

var sim: FrostSim
var index: int
var _shown_level := 0
var _bar: Node3D
var _fill: MeshInstance3D
var _fill_material: StandardMaterial3D
var _smoke: CPUParticles3D
var _lit := true

@onready var _flame: Node3D = $Flame
@onready var _range: Node3D = $Range


func setup(frost_sim: FrostSim, source_index: int) -> void:
	sim = frost_sim
	index = source_index
	var source := sim.heat_sources[index]
	position = Vector3(source.pos.x, 0.0, source.pos.y)
	_range.scale = Vector3(source.radius, 1.0, source.radius)
	$Stove.queue_free()
	_build_bar()
	_smoke = Juice.make_burst(self, Color(0.35, 0.35, 0.38), 6, 0.3)
	_smoke.one_shot = false
	_smoke.direction = Vector3.UP
	_smoke.position.y = 0.6
	_smoke.emitting = false
	sim.fire_fueled.connect(func(i: int, _agent: SimAgent) -> void:
		if i == index:
			Juice.pop($Campfire, Vector3(1.25, 0.8, 1.25), 0.2))
	var tween := create_tween().set_loops()
	tween.tween_property(_flame, "scale", Vector3(1.15, 1.25, 1.15), 0.18)
	tween.tween_property(_flame, "scale", Vector3(0.9, 0.85, 0.9), 0.22)


func _process(_delta: float) -> void:
	var source := sim.heat_sources[index]
	_update_fuel(source)
	if source.level == _shown_level:
		return
	_shown_level = source.level
	create_tween().tween_property(_range, "scale", Vector3(source.radius, 1.0, source.radius), GROW_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var size: Vector3 = Vector3.ONE * (1.0 + FLAME_GROWTH * source.level)
	$Campfire.scale = size * Vector3(1.4, 0.6, 1.4)
	create_tween().tween_property($Campfire, "scale", size, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flame.position.y = 0.45 + 0.3 * source.level



## 연료 막대를 채우고, 불이 꺼지거나 다시 붙으면 불꽃·원판·연기를 바꾼다. 연료가 없는 열원은 막대를 숨긴다.
func _update_fuel(source: Dictionary) -> void:
	if source.fuel_max <= 0.0:
		_bar.visible = false
		return
	var ratio: float = source.fuel / source.fuel_max
	_fill.scale.x = maxf(ratio, 0.001)
	_fill.position.x = -BAR_WIDTH * (1.0 - ratio) / 2.0
	_fill_material.albedo_color = LOW_COLOR if ratio < LOW_FUEL else FUEL_COLOR
	_bar.visible = not sim.is_fire_auto(source) or ratio < 1.0 - source.per_log / source.fuel_max
	var lit: bool = source.fuel > 0.0
	if lit == _lit:
		return
	_lit = lit
	_flame.visible = lit
	_range.visible = lit
	_smoke.emitting = not lit
	if lit:
		# Juice.pop은 크기를 1로 되돌리므로 원래 반경으로 직접 키운다.
		_range.scale = Vector3(source.radius * 0.6, 1.0, source.radius * 0.6)
		create_tween().tween_property(_range, "scale", Vector3(source.radius, 1.0, source.radius), 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_bar() -> void:
	_bar = Node3D.new()
	_bar.position.y = BAR_Y
	add_child(_bar)
	var back := MeshInstance3D.new()
	back.mesh = _box(Vector3(BAR_WIDTH + 0.08, BAR_HEIGHT + 0.08, 0.04), Color(0.1, 0.1, 0.14))
	_bar.add_child(back)
	_fill = MeshInstance3D.new()
	_fill.mesh = _box(Vector3(BAR_WIDTH, BAR_HEIGHT, 0.06), FUEL_COLOR)
	_fill_material = _fill.mesh.material
	_bar.add_child(_fill)


static func _box(size: Vector3, color: Color) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	return mesh
