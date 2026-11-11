class_name Stall
extends RefCounted
## 판매대 하나. 재고, 손님 줄(손님마다 남은 인내심), 아직 줍지 않은 돈을 가진다.

var item: String
## 비어 있지 않으면 이 이름이 해금되어야 판매대가 열린다.
var unlock := ""
var pos: Vector2
var cash_pos: Vector2
var price: int
var sell_interval: float
var customer_interval: float
var customer_patience: float
var queue_max: int

var stock := 0
var cash := 0
var queue: Array[float] = []
var served := 0
var left_angry := 0

var _spawn_timer := 0.0
var _sell_timer := 0.0


func _init(stall_item: String, stall_pos: Vector2, stall_cash_pos: Vector2, balance: Dictionary) -> void:
	item = stall_item
	pos = stall_pos
	cash_pos = stall_cash_pos
	price = int(balance.items[item].price)
	var config: Dictionary = balance.stall
	sell_interval = float(config.sell_interval)
	customer_interval = float(config.customer_interval)
	customer_patience = float(config.customer_patience)
	queue_max = int(config.queue_max)


func tick(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= customer_interval:
		_spawn_timer = 0.0
		if queue.size() < queue_max:
			queue.append(customer_patience)

	for i in queue.size():
		queue[i] -= delta
	while not queue.is_empty() and queue[0] <= 0.0:
		queue.pop_front()
		left_angry += 1

	if queue.is_empty() or stock == 0:
		_sell_timer = 0.0
		return
	_sell_timer += delta
	if _sell_timer >= sell_interval:
		_sell_timer = 0.0
		stock -= 1
		cash += price
		queue.pop_front()
		served += 1
