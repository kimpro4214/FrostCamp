class_name PurchaseZone
extends RefCounted
## 바닥 구매 존. 위에 서 있으면 돈이 빨려 들어가고, 다 차면 다음 레벨로 넘어간다.
## 넣은 돈은 존을 떠나도 남는다.

var id: String
var pos: Vector2
var costs: Array
var effect: Dictionary
var requires: Array
var level := 0
var paid := 0
var _carry := 0.0


func _init(zone_id: String, zone_pos: Vector2, config: Dictionary) -> void:
	id = zone_id
	pos = zone_pos
	costs = config.costs
	effect = config.get("effect", {})
	requires = config.get("requires", [])


func is_maxed() -> bool:
	return level >= costs.size()


func cost() -> int:
	return int(costs[level])


func remaining() -> int:
	return cost() - paid


## 이번 프레임에 money에서 낼 금액을 계산해 반영한다. 낸 금액을 돌려준다.
func pay(money: int, rate: float, delta: float) -> int:
	_carry += rate * delta
	var amount := mini(mini(int(_carry), money), remaining())
	_carry = _carry - amount if amount == int(_carry) else 0.0
	paid += amount
	return amount


## 다 찼으면 레벨을 올리고 true.
func try_complete() -> bool:
	if is_maxed() or paid < cost():
		return false
	level += 1
	paid = 0
	_carry = 0.0
	return true
