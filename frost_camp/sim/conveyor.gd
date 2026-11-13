class_name Conveyor
extends RefCounted
## 적치장에서 원목 판매대까지 원목을 실어 나르는 벨트. 경로(점 목록)를 따라 원목이 간격을 두고 흐른다.
## 일정 간격으로 적치장에서 하나를 싣고, 끝에 닿은 원목은 판매대가 받을 수 있을 때 재고가 된다.

var path: Array[Vector2] = []
var length := 0.0
## 벨트 위 원목들의 위치(시작점에서 잰 거리). 앞(끝에 가까운 것)부터 담는다.
var items: Array[float] = []
var level := 0
var speeds: Array = []
var take_intervals: Array = []
var spacing: float
var structure: Structure
## 나르는 품목과 받는 판매대 번호
var item := "log"
var stall := 0
var _take_timer := 0.0


func _init(points: Array[Vector2], config: Dictionary) -> void:
	path = points
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	speeds = config.speed
	take_intervals = config.take_interval
	spacing = float(config.spacing)


func speed() -> float:
	return float(speeds[mini(level, speeds.size()) - 1])


func take_interval() -> float:
	return float(take_intervals[mini(level, take_intervals.size()) - 1])


## 원목들을 앞으로 보낸다. 앞 원목과 spacing보다 가까워지지 않는다.
## can_deliver가 true면 끝에 닿은 원목을 내려놓고, 내려놓은 개수를 돌려준다.
func advance(delta: float, can_deliver: bool) -> int:
	var delivered := 0
	var step := speed() * delta
	var limit := length
	var i := 0
	while i < items.size():
		items[i] = minf(items[i] + step, limit)
		if i == 0 and items[0] >= length and can_deliver:
			items.remove_at(0)
			delivered += 1
			continue
		limit = items[i] - spacing
		i += 1
	return delivered


## 실을 차례이고 시작점이 비어 있으면 true. true를 돌려주면 원목 하나를 실은 것이다.
func try_load(delta: float, available: bool) -> bool:
	_take_timer = minf(_take_timer + delta, take_interval())
	if not available or _take_timer < take_interval():
		return false
	if not items.is_empty() and items[-1] < spacing:
		return false
	_take_timer = 0.0
	items.append(0.0)
	return true


## 시작점에서 dist만큼 간 경로 위의 점(화면용)
func point_at(dist: float) -> Vector2:
	var left := dist
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if left <= seg:
			return path[i - 1].lerp(path[i], left / seg)
		left -= seg
	return path[-1]
