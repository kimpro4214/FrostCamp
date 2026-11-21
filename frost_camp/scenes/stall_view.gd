extends Node3D
## 판매대 하나의 겉모습. sim의 재고·돈 더미를 매 프레임 따라 그리고, 손님 줄을 걸어 다니는 사람들로 보여 준다.
## 손님은 한 방향으로 지나간다: 줄 끝(+X) 너머에서 걸어 들어와 맨 앞에서 사고,
## 산 손님은 판매대마다 정한 쪽(layout의 exit, 다른 줄과 엇갈리지 않게) 옆으로 곧게 걸어 나가 사라진다(줄을 거슬러 가지 않는다). 뒤 손님은 한 칸씩 당겨진다.

const Juice := preload("res://frost_camp/scenes/juice.gd")
const ArmDrop := preload("res://frost_camp/scenes/arm_drop.gd")
const ItemModel := preload("res://frost_camp/scenes/item_model.gd")
## 판매대에 놓이는 물건 하나의 크기
const ITEM_SIZE := Vector3(0.5, 0.2, 0.3)
const COIN_SIZE := Vector3(0.32, 0.1, 0.32)
## 산 물건을 드는 높이(손님 모델 비율 기준, 모델 키는 0.67)
const CARRY_HEIGHT := 0.76
const MAX_SHOWN_STOCK := 12
const MAX_SHOWN_CASH := 20
const QUEUE_START := 1.5
const QUEUE_GAP := 1.1
const CUSTOMER_SCALE := 2.3
const WALK_SPEED := 3.5
## 새 손님이 나타나는 곳: 줄 맨 끝 자리에서 이만큼 더 뒤
const ENTER_DISTANCE := 3.0
## 산 손님이 줄 옆으로 걸어 나가는 거리와 시간
const EXIT_DISTANCE := 2.2
const EXIT_TIME := 0.8
## 판매대(-X)를 바라보는 방향
const FACE_STALL := -PI / 2.0

var sim: FrostSim
var index: int
var _shown := Vector2i(-1, -1)  # 재고, 돈 더미 개수
var _customers: Array[Node3D] = []
var _last_served := 0
var _spawned := 0
## 산 손님이 나가는 방향
var _exit_dir := Vector3.BACK
## 이 판매대가 파는 물건의 본(복제해서 쓴다)
var _item_template: Node3D
var _coin_template: Node3D
## 떠난 손님을 버리지 않고 모아 두었다가 다음 손님으로 다시 쓴다(트리 밖에 둔다).
var _customer_pool: Array[Node3D] = []

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
	_exit_dir = Vector3(stall.exit_dir.x, 0.0, stall.exit_dir.y).normalized()
	_set_disc_radius(_unload_zone, float(sim.balance.interact.stall_radius))
	_set_disc_radius(_cash_zone, float(sim.balance.interact.cash_radius))
	_last_served = stall.served
	_item_template = ItemModel.make(stall.item, ITEM_SIZE)
	_coin_template = ItemModel.make("coin", COIN_SIZE)
	sim.premium_sold.connect(func(i: int, item: String) -> void:
		if i == index:
			Juice.float_text(self, global_position + Vector3(0.0, 2.6, 0.0), "+$%d" % int(sim.balance.items[item].price), Color(1.0, 0.8, 0.2), 96)
			Juice.pop(self, Vector3(1.2, 0.85, 1.2), 0.3))


func _process(delta: float) -> void:
	var stall := sim.stalls[index]
	var open := sim.is_stall_open(stall)
	if open and not visible:
		Juice.pop(self, Vector3(0.3, 1.6, 0.3), 0.4)
	visible = open
	_collision.disabled = not open
	_update_customers(stall, delta)
	var state := Vector2i(
		mini(stall.stock, MAX_SHOWN_STOCK),
		mini(ceili(float(stall.cash) / stall.price), MAX_SHOWN_CASH))
	if state == _shown:
		return
	_shown = state
	_rebuild(_stock_root, state.x, func(i: int) -> Vector3:
		return Vector3(0.0, 1.1 + (i / 4) * 0.22, -0.6 + (i % 4) * 0.4), func(_i: int) -> Node3D: return _item_template.duplicate())
	_rebuild(_cash_root, state.y, func(i: int) -> Vector3:
		return Vector3(0.0, 0.08 + i * 0.12, 0.0), func(_i: int) -> Node3D: return _coin_template.duplicate())


## 팔린 만큼 맨 앞 손님을 내보내고, 줄 길이만큼 새 손님을 들이고, 모두 자기 자리로 걸어가게 한다.
func _update_customers(stall: Stall, delta: float) -> void:
	for i in stall.served - _last_served:
		if not _customers.is_empty():
			_leave(_customers.pop_front(), stall)
	_last_served = stall.served
	while _customers.size() < stall.queue:
		var customer := _make_customer()
		customer.position = _slot(maxi(_customers.size(), stall.queue_max - 1)) + Vector3(ENTER_DISTANCE, 0.0, 0.0)
		_queue_root.add_child(customer)
		_customers.append(customer)
	while _customers.size() > stall.queue:
		_recycle(_customers.pop_back())
	for i in _customers.size():
		_walk_toward(_customers[i], _slot(i), delta)


func _slot(i: int) -> Vector3:
	return Vector3(QUEUE_START + i * QUEUE_GAP, 0.0, 0.0)


## 자리까지 걸어가며 가는 쪽을 보고, 도착하면 판매대를 보고 선다.
func _walk_toward(customer: Node3D, target: Vector3, delta: float) -> void:
	var to := target - customer.position
	var moving := to.length() > 0.02
	if moving:
		customer.position = customer.position.move_toward(target, WALK_SPEED * delta)
		customer.rotation.y = atan2(to.x, to.z)  # Kenney 캐릭터는 +Z를 본다
	else:
		customer.rotation.y = lerp_angle(customer.rotation.y, FACE_STALL, minf(delta * 10.0, 1.0))
	_play(customer, "walk" if moving else "idle")


## 산 물건을 머리 위로 들고 돈을 띄운 뒤, 줄 밖으로 걸어 나가며 작아져 사라진다.
func _leave(customer: Node3D, stall: Stall) -> void:
	var item: Node3D = _item_template.duplicate()
	item.name = "Carried"
	item.visible = true
	item.position = Vector3(0.0, CARRY_HEIGHT, 0.0)
	item.scale = Vector3.ONE / CUSTOMER_SCALE
	customer.add_child(item)
	Juice.pop(item, Vector3(0.3, 0.3, 0.3), 0.25)
	Juice.float_text(self, customer.global_position + Vector3(0.0, 2.2, 0.0), "+$%d" % stall.price, Color(1.0, 0.85, 0.3), 48)
	var exit := customer.position + _exit_dir * EXIT_DISTANCE
	customer.rotation.y = atan2(_exit_dir.x, _exit_dir.z)
	_play(customer, "walk")
	var tween := customer.create_tween()
	tween.tween_property(customer, "position", exit, EXIT_TIME)
	tween.tween_property(customer, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(_recycle.bind(customer))


## 손님을 줄에서 빼서 모아 둔다. 들고 있던 물건은 버린다.
func _recycle(customer: Node3D) -> void:
	var item := customer.get_node_or_null("Carried")
	if item:
		item.free()
	customer.get_parent().remove_child(customer)
	_customer_pool.append(customer)


func _exit_tree() -> void:
	for customer in _customer_pool:
		customer.free()
	_customer_pool.clear()


func _play(customer: Node3D, anim_name: String) -> void:
	var anim: AnimationPlayer = customer.get_meta("anim")
	if anim.current_animation != anim_name:
		anim.play(anim_name, 0.15)


## 물건은 한 번 만들면 두고, 개수만큼만 보인다.
func _rebuild(root: Node3D, count: int, place: Callable, make: Callable) -> void:
	var nodes := root.get_children().filter(func(child: Node) -> bool: return child != _cash_zone)
	for i in range(nodes.size(), count):
		var node: Node3D = make.call(i)
		node.position = place.call(i)
		root.add_child(node)
		nodes.append(node)
	for i in nodes.size():
		nodes[i].visible = i < count


## 손님 한 명. 모델은 들어온 순서대로 돌려 쓴다.
func _make_customer() -> Node3D:
	if not _customer_pool.is_empty():
		var reused: Node3D = _customer_pool.pop_back()
		reused.scale = Vector3.ONE * CUSTOMER_SCALE
		return reused
	var models: Array = GameData.theme().customers
	var customer: Node3D = load(models[_spawned % models.size()]).instantiate()
	_spawned += 1
	customer.scale = Vector3.ONE * CUSTOMER_SCALE
	var anim: AnimationPlayer = customer.find_children("*", "AnimationPlayer", true, false)[0]
	for anim_name in ["idle", "walk"]:
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	anim.play("walk")
	customer.set_meta("anim", anim)
	# 손님은 서기·걷기만 하므로 팔은 늘 내린다(scenes/arm_drop.gd).
	customer.find_children("*", "Skeleton3D", true, false)[0].add_child(ArmDrop.new())
	return customer


func _set_disc_radius(disc: MeshInstance3D, radius: float) -> void:
	var mesh: CylinderMesh = disc.mesh.duplicate()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	disc.mesh = mesh
