extends Node3D
## 구매 존(또는 수리 존)의 겉모습. 낸 돈만큼 안쪽 원판이 차고, 남은 금액을 띄운다.
## 지금 살 수 없으면 숨는다.

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
	var progress := float(zone.paid) / zone.cost()
	_fill.scale = Vector3(progress, 1.0, progress)
	_fill.visible = progress > 0.0
	var title := display_name if zone.costs.size() == 1 else "%s %d단계" % [display_name, zone.level + 1]
	_label.text = "%s\n$ %d" % [title, zone.remaining()]
