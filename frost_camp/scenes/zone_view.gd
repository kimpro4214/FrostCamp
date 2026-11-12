extends Node3D
## 구매 존의 겉모습. 낸 돈만큼 안쪽 원판이 차고, 남은 금액을 띄운다. 살 수 없으면 숨는다.

const Juice := preload("res://frost_camp/scenes/juice.gd")

var sim: FrostSim
var index: int

@onready var _base: MeshInstance3D = $Base
@onready var _fill: MeshInstance3D = $Fill
@onready var _label: Label3D = $Label


func setup(frost_sim: FrostSim, zone_index: int) -> void:
	sim = frost_sim
	index = zone_index
	var zone := sim.zones[index]
	position = Vector3(zone.pos.x, 0.0, zone.pos.y)
	var radius := float(sim.balance.purchase.zone_radius)
	scale = Vector3(radius, 1.0, radius)
	sim.zone_purchased.connect(func(id: String, _level: int) -> void:
		if id == zone.id:
			Juice.pop(_base, Vector3(1.4, 1.0, 1.4)))


func _process(_delta: float) -> void:
	var zone := sim.zones[index]
	visible = sim.is_zone_available(zone)
	if not visible:
		return
	var progress := float(zone.paid) / zone.cost()
	_fill.scale = Vector3(progress, 1.0, progress)
	_fill.visible = progress > 0.0
	_label.text = "%s Lv%d\n$ %d" % [zone.id.to_upper().replace("_", " "), zone.level + 1, zone.remaining()]
