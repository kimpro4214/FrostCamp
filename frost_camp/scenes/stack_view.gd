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


func setup(stack: BackStack) -> void:
	_stack = stack


func _process(delta: float) -> void:
	_sway(delta)
	if _stack == null or _stack.items == _shown:
		return
	_shown = _stack.items.duplicate()
	for child in get_children():
		child.queue_free()
	for i in _shown.size():
		var box := ItemModel.make(_shown[i], ITEM_SIZE)
		box.position.y = i * (ITEM_SIZE.y + 0.02)
		add_child(box)


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

