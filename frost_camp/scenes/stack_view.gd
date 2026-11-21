extends Node3D
## 등 뒤 스택 그리기. 플레이어와 일꾼이 같이 쓴다.

const ItemModel := preload("res://frost_camp/scenes/item_model.gd")
const ITEM_SIZE := Vector3(0.5, 0.2, 0.3)

## 걸을 때 스택이 진행 반대쪽으로 휘는 정도
const SWAY := 0.012
const SWAY_SMOOTHING := 8.0

var _stack: BackStack
var _shown: Array[String] = []
var _last_global := Vector3.INF
var _lean := Vector3.ZERO
## 내려놓은 물건 상자를 버리지 않고 물건 이름별로 모아 두었다가 다시 쓴다(트리 밖에 둔다).
var _pool := {}


func setup(stack: BackStack) -> void:
	_stack = stack


func _process(delta: float) -> void:
	_sway(delta)
	if _stack == null or _stack.items == _shown:
		return
	# 아래부터 같은 물건은 그대로 두고, 처음 달라진 칸부터 위만 바꾼다(보통 맨 위 하나만 바뀐다).
	var items := _stack.items
	var boxes := get_children()
	var keep := 0
	while keep < boxes.size() and keep < items.size() and boxes[keep].get_meta("item") == items[keep]:
		keep += 1
	for i in range(boxes.size() - 1, keep - 1, -1):
		remove_child(boxes[i])
		_pool.get_or_add(boxes[i].get_meta("item"), []).append(boxes[i])
	for i in range(keep, items.size()):
		var box := _take(items[i])
		box.position = Vector3(0.0, i * (ITEM_SIZE.y + 0.02), 0.0)
		add_child(box)
	_shown = items.duplicate()


func _take(item: String) -> Node3D:
	var free: Array = _pool.get(item, [])
	if not free.is_empty():
		return free.pop_back()
	var box := ItemModel.make(item, ITEM_SIZE)
	box.set_meta("item", item)
	return box


func _exit_tree() -> void:
	for free: Array in _pool.values():
		for box: Node in free:
			box.free()
	_pool.clear()


## 움직인 방향 반대로 위쪽 상자일수록 더 밀려나 탑이 휘어 보이게 한다.
func _sway(delta: float) -> void:
	var here := global_position
	var velocity := Vector3.ZERO if _last_global == Vector3.INF or delta == 0.0 else (here - _last_global) / delta
	_last_global = here
	var local_velocity := global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	_lean = _lean.lerp(-local_velocity * SWAY, 1.0 - exp(-SWAY_SMOOTHING * delta))
	var children := get_children()
	var count := children.size()
	for i in count:
		var t := float(i) / maxf(count - 1, 1)
		var box: Node3D = children[i]
		box.position.x = _lean.x * t * t * count * 0.6
		box.position.z = _lean.z * t * t * count * 0.6

