extends RefCounted
## 테스트용 고정 데이터. balance.json을 조정해도 규칙 테스트가 깨지지 않게 따로 둔다.


static func balance() -> Dictionary:
	return {
		"player": {"move_speed": 5.0, "stack_capacity": 10},
		"interact": {"tree_radius": 1.5, "stall_radius": 1.5, "cash_radius": 1.0},
		"tree": {"hits_to_fell": 3, "hit_interval": 0.5, "logs_dropped": 2, "respawn_time": 8.0},
		"items": {"log": {"price": 5}},
		"stall": {
			"unload_interval": 0.1,
			"sell_interval": 0.5,
			"customer_interval": 1.0,
			"customer_patience": 5.0,
			"queue_max": 3,
		},
	}


static func layout() -> Dictionary:
	return {
		"player_start": [0, 0],
		"trees": [[-10, 0]],
		"stalls": [{"item": "log", "pos": [10, 0], "cash_pos": [10, 3]}],
	}


## 고정 간격으로 sim을 seconds만큼 돌린다.
static func run(sim: FrostSim, seconds: float, step: float = 0.05) -> void:
	for i in roundi(seconds / step):
		sim.tick(step)
