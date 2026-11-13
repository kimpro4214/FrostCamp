extends Node3D
## 구매 존(또는 수리 존)의 겉모습. 낸 돈만큼 안쪽 원판이 차고, 남은 금액을 띄운다.
## 지금 살 수 없으면 숨는다. 모닥불 단계만 모자라면 흐리게 보이며 "모닥불 N단계 필요"를 띄운다.

const Juice := preload("res://frost_camp/scenes/juice.gd")

var sim: FrostSim
var zone: PurchaseZone
var display_name: String
var _available: Callable

@onready var _base: MeshInstance3D = $Base
@onready var _fill: MeshInstance3D = $Fill
@onready var _label: Label3D = $Label


## available은 존이 지금 보여야 하는지 돌려주는 함수다(구매 존은 선행 조건, 수리 존은 부서짐).
func setup(frost_sim: FrostSim, purchase_zone: PurchaseZone, zone_name: String, available: Callable) -> void:
	sim = frost_sim
	zone = purchase_zone
	display_name = zone_name
	_available = available
	position = Vector3(zone.pos.x, 0.0, zone.pos.y)
	var radius := float(sim.balance.purchase.zone_radius)
	scale = Vector3(radius, 1.0, radius)
	sim.zone_purchased.connect(func(id: String, _level: int) -> void:
		if id == zone.id:
			Juice.pop(_base, Vector3(1.4, 1.0, 1.4)))


func _process(_delta: float) -> void:
	visible = _available.call()
	if not visible:
		return
	var fire := sim.fire_needed(zone)
	_base.transparency = 0.6 if fire > 0 else 0.0
	_label.modulate = Color(0.75, 0.8, 0.9) if fire > 0 else Color.WHITE
	if fire > 0:
		_fill.visible = false
		_label.text = "%s
모닥불 %d단계 필요" % [display_name, fire]
		return
	var progress := float(zone.paid) / zone.cost()
	_fill.scale = Vector3(progress, 1.0, progress)
	_fill.visible = progress > 0.0
	var title := display_name if zone.costs.size() == 1 else "%s %d단계" % [display_name, zone.level + 1]
	_label.text = "%s\n$ %d" % [title, zone.remaining()]
