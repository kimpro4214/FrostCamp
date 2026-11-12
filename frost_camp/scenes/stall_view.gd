extends Node3D
## 판매대 하나의 겉모습. sim의 재고·손님 줄·돈 더미를 매 프레임 따라 그린다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const MAX_SHOWN_STOCK := 12
const MAX_SHOWN_CASH := 20
const QUEUE_START := 1.5
const QUEUE_GAP := 1.1
const CUSTOMER_MODELS := [
	preload("res://frost_camp/assets/models/characters/character-female-a.glb"),
	preload("res://frost_camp/assets/models/characters/character-male-e.glb"),
	preload("res://frost_camp/assets/models/characters/character-female-d.glb"),
]
const CUSTOMER_SCALE := 2.3

var sim: FrostSim
var index: int
var _shown := Vector3i(-1, -1, -1)  # 재고, 돈 더미 개수, 줄 길이

@onready var _stock_root: Node3D = $Stock
@onready var _cash_root: Node3D = $Cash
@onready var _queue_root: Node3D = $Queue
@onready var _unload_zone: MeshInstance3D = $UnloadZone
@onready var _cash_zone: MeshInstance3D = $Cash/CashZone
@onready var _collision: CollisionShape3D = $StaticBody3D/CollisionShape3D


func setup(frost_sim: FrostSim, stall_index: int) -> void:
	sim = frost_sim
	index = stall_index
	var stall := sim.stalls[index]
	position = Vector3(stall.pos.x, 0.0, stall.pos.y)
	var cash_offset := stall.cash_pos - stall.pos
	_cash_root.position = Vector3(cash_offset.x, 0.0, cash_offset.y)
	_set_disc_radius(_unload_zone, float(sim.balance.interact.stall_radius))
	_set_disc_radius(_cash_zone, float(sim.balance.interact.cash_radius))


func _process(_delta: float) -> void:
	var stall := sim.stalls[index]
	var open := sim.is_stall_open(stall)
	if open and not visible:
		Juice.pop(self, Vector3(0.3, 1.6, 0.3), 0.4)
	visible = open
	_collision.disabled = not open
	var state := Vector3i(
		mini(stall.stock, MAX_SHOWN_STOCK),
		mini(ceili(float(stall.cash) / stall.price), MAX_SHOWN_CASH),
		stall.queue.size())
	if state == _shown:
		return
	_shown = state
	var item_template: Node3D = $Templates.get_node(stall.item.capitalize())
	_rebuild(_stock_root, state.x, func(i: int) -> Vector3:
		return Vector3(0.0, 1.1 + (i / 4) * 0.22, -0.6 + (i % 4) * 0.4), func(_i: int) -> Node3D: return item_template.duplicate())
	_rebuild(_cash_root, state.y, func(i: int) -> Vector3:
		return Vector3(0.0, 0.08 + i * 0.12, 0.0), func(_i: int) -> Node3D: return $Templates/Coin.duplicate())
	_rebuild(_queue_root, state.z, func(i: int) -> Vector3:
		return Vector3(QUEUE_START + i * QUEUE_GAP, 0.0, 0.0), _make_customer)


func _rebuild(root: Node3D, count: int, place: Callable, make: Callable) -> void:
	for child in root.get_children():
		if child != _cash_zone:
			child.queue_free()
	for i in count:
		var node: Node3D = make.call(i)
		node.visible = true
		node.position = place.call(i)
		root.add_child(node)


## 줄 선 손님. 판매대(-X 쪽)를 바라보고 서 있는다. 자리마다 모델이 정해져 있다.
func _make_customer(slot: int) -> Node3D:
	var customer: Node3D = CUSTOMER_MODELS[slot % CUSTOMER_MODELS.size()].instantiate()
	customer.scale = Vector3.ONE * CUSTOMER_SCALE
	customer.rotation.y = -PI / 2.0
	var anim: AnimationPlayer = customer.find_children("*", "AnimationPlayer", true, false)[0]
	anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	anim.play("idle")
	return customer


func _set_disc_radius(disc: MeshInstance3D, radius: float) -> void:
	var mesh: CylinderMesh = disc.mesh.duplicate()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	disc.mesh = mesh
