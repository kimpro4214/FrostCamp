class_name Stall
extends RefCounted
## 판매대 하나. 재고, 손님 줄, 아직 줍지 않은 돈을 가진다.
## 손님은 떠나지 않고, 한 명이 사 가면 refill 간격 뒤 다음 손님이 와서 줄은 늘 가득 찬다.

var item: String
## 비어 있지 않으면 이 이름이 해금되어야 판매대가 열린다.
var unlock := ""
var pos: Vector2
var cash_pos: Vector2
var price: int
var sell_interval: float
var customer_refill: float
var queue_max: int

var stock := 0
var cash := 0
## 줄 선 손님 수
var queue := 0
var served := 0
## 이 판매대의 체력. 부서지면 팔지도 받지도 않는다(sim이 판단).
var structure: Structure

var _spawn_timer := 0.0
var _sell_timer := 0.0


func _init(stall_item: String, stall_pos: Vector2, stall_cash_pos: Vector2, balance: Dictionary) -> void:
	item = stall_item
	pos = stall_pos
	cash_pos = stall_cash_pos
	price = int(balance.items[item].price)
	var config: Dictionary = balance.stall
	sell_interval = float(config.sell_interval)
	customer_refill = float(config.customer_refill)
	queue_max = int(config.queue_max)


func tick(delta: float) -> void:
	if queue < queue_max:
		_spawn_timer += delta
		if _spawn_timer >= customer_refill:
			_spawn_timer = 0.0
			queue += 1
	else:
		_spawn_timer = 0.0

	if queue == 0 or stock == 0:
		_sell_timer = 0.0
		return
	_sell_timer += delta
	if _sell_timer >= sell_interval:
		_sell_timer = 0.0
		stock -= 1
		cash += price
		queue -= 1
		served += 1
