extends RefCounted
## 테스트용 고정 데이터. balance.json을 조정해도 규칙 테스트가 깨지지 않게 따로 둔다.


static func balance() -> Dictionary:
	return {
		"player": {
			"move_speed": 5.0,
			"stack_capacity": 10,
			"axe_damage": 1,
			"harpoon_damage": 2,
			"harpoon_interval": 0.5,
			"hp": 10,
			"hp_regen": 2.0,
			"dazed_time": 3.0,
			"dazed_speed_mult": 0.5,
		},
		"interact": {
			"tree_radius": 1.5, "bear_radius": 1.5, "stall_radius": 1.5, "pile_radius": 1.0, "cash_radius": 1.0,
		},
		"structures": {
			"stall": {"hp": 10, "repair_cost": 20},
			"woodpile": {"hp": 10, "repair_cost": 20},
			"meat_pile": {"hp": 10, "repair_cost": 20},
			"wall": {"hp": [10, 20, 30], "repair_cost": 20},
			"salmon_pile": {"hp": 10, "repair_cost": 20},
			"crystal_pile": {"hp": 10, "repair_cost": 20},
			"tower": {"hp": 10, "repair_cost": 20},
			"conveyor": {"hp": 10, "repair_cost": 20},
		},
		"raid": {
			"start_after": "habitat", "start_delay": 10.0, "interval": 20.0, "warning": 5.0,
			"count_base": 2, "count_growth": 1, "count_max": 3, "hp_base": 4, "hp_growth": 2,
			"speed": 2.0, "damage": 2, "attack_interval": 1.0, "attack_radius": 1.5, "reward": 10, "meat_dropped": 2,
		},
		"conveyor": {"speed": [2.0, 4.0], "take_interval": [0.5, 0.25], "spacing": 1.0},
		"fish": {"catch_interval": 1.0, "hole_radius": 1.0},
		"tower": {"range": 6.0, "interval": 1.0, "damage": 2, "damage_add": 2},
		"workers": {
			"lumberjack": {"speed": 4.0, "capacity": 4, "damage": 1},
			"porter": {"speed": 4.0, "capacity": 4},
			"cashier": {"speed": 4.0},
			"hunter": {"speed": 4.0, "capacity": 4, "damage": 2, "hp": 10},
			"fisher": {"speed": 4.0, "capacity": 4},
			"miner": {"speed": 4.0, "capacity": 4, "damage": 1},
		},
		"cold": {
			"max": 30,
			"drain": 1.0,
			"recover": 10.0,
			"frozen_speed_mult": 0.5,
			"sources": {"campfire": {"radius": [3.0, 5.0]}},
		},
		"tree": {"hits_to_fell": 3, "hit_interval": 0.5, "logs_dropped": 2, "respawn_time": 8.0},
		"crystal": {"hits_to_fell": 4, "dropped": 2, "respawn_time": 10.0},
		"bear": {
			"hp": 10,
			"wander_speed": 1.0,
			"respawn_time": 10.0,
			"attack_interval": 1.0,
			"damage": 3,
			"meat_dropped": 2,
			"wall_margin": 1.0,
		},
		"items": {"log": {"price": 5}, "meat": {"price": 15}},
		"stall": {
			"unload_interval": 0.1,
			"sell_interval": 0.5,
			"customer_refill": 1.0,
			"queue_max": 3,
		},
		"purchase": {"zone_radius": 1.0, "pay_delay": 0.5, "fill_time": 1.0, "min_rate": 10},
		"zones": {
			"backpack": {"costs": [20, 40], "effect": {"stat": "stack_capacity", "add": 4}},
			"boots": {
				"costs": [30],
				"effect": {"stat": "move_speed", "add": 1.0},
				"requires": ["backpack"],
			},
			"axe": {"costs": [10], "effect": {"stat": "axe_damage", "add": 2}},
			"habitat": {"costs": [10], "effect": {"unlock": "habitat"}},
			"meat_stall": {"costs": [10], "effect": {"unlock": "meat_stall"}},
			"harpoon": {"costs": [10], "effect": {"stat": "harpoon_damage", "add": 3}},
			"lumberjack": {"costs": [10], "effect": {"hire": "lumberjack"}},
			"porter": {"costs": [10], "effect": {"hire": "porter"}},
			"cashier": {"costs": [10], "effect": {"hire": "cashier"}},
			"fire": {"costs": [10], "effect": {"fire": "campfire"}},
			"coat": {"costs": [10], "effect": {"stat": "cold_drain", "add": -0.5}},
			"ship_hull": {"costs": [10], "effect": {"unlock": "ship_hull"}},
			"ship_mast": {"costs": [10], "effect": {"unlock": "ship_mast"}},
		},
		"ending": {"ship_parts": ["ship_hull", "ship_mast"]},
	}


## 캠프는 원점 근처, 서식지는 z가 -30~-20인 사각형이다.
static func layout() -> Dictionary:
	return {
		"player_start": [0, 0],
		"worker_spawn": [0, -2],
		"woodpile": [-6, 0],
		"woodpile_repair": [-6, -3],
		"meat_pile": [0, -15],
		"meat_pile_repair": [3, -15],
		"fishing_holes": [[15, -5], [17, -5]],
		"piles": {
			"salmon": {"pos": [15, -8], "repair_pos": [17, -8], "unlock": "fish_stall"},
			"crystal": {"pos": [-15, 12], "repair_pos": [-17, 12], "unlock": "expand_1"},
		},
		"ship": [30, 0],
		"heat": {"campfire": [0, 0]},
		"trees": [[-10, 0]],
		"regions": {
			"habitat": {"rect": [-10, -30, 20, 10], "gate": [0, -20]},
			"expand_1": {"rect": [-20, 10, 10, 10], "gate": [-15, 10], "open": true, "trees": [[-15, 15]], "crystals": [[-12, 15], [-18, 13]]},
		},
		"bears": [[0, -25]],
		"extra_bears": [[5, -25], [-5, -25], [3, -22]],
		"raid_spawns": [[0, 20]],
		"base": {
			"rects": {"": [-20, -12, 40, 22], "expand_1": [-20, 10, 10, 10]},
			"walls": [
				{"a": [-10, 10], "b": [10, 10]},
				{"a": [-20, 10], "b": [-10, 10], "until": "expand_1"},
				{"a": [-20, 20], "b": [-10, 20], "from": "expand_1"},
			],
		},
		"conveyors": {
			"log": {"path": [[-6, 2], [4, 2], [4, 0]], "pos": [-1, 2], "repair_pos": [-1, 4], "stall": 0},
			"meat": {"path": [[0, -15], [8, -15], [8, -8]], "pos": [4, -15], "repair_pos": [4, -13], "stall": 1},
		},
		"towers": [{"id": "tower_1", "pos": [0, 8], "repair_pos": [2, 8]}],
		"stalls": [
			{"item": "log", "pos": [10, 0], "cash_pos": [10, 3], "repair_pos": [7, 0], "raid_target": false},
			{"item": "meat", "pos": [10, -8], "cash_pos": [10, -11], "repair_pos": [7, -8], "unlock": "meat_stall"},
		],
		"zones": {
			"backpack": [0, 5],
			"boots": [3, 5],
			"axe": [-3, 5],
			"habitat": [0, -17],
			"meat_stall": [6, 5],
			"harpoon": [9, 5],
			"lumberjack": [-6, 5],
			"porter": [-9, 5],
			"cashier": [12, 5],
			"fire": [-12, 5],
			"coat": [15, 5],
			"ship_hull": [20, 0],
			"ship_mast": [23, 0],
		},
	}


## 일꾼을 각자 목표로 직선 이동시키며 sim을 seconds만큼 돌린다.
static func run_with_workers(sim: FrostSim, seconds: float, step: float = 0.05) -> void:
	for i in roundi(seconds / step):
		for worker in sim.workers:
			if worker.pos.distance_to(worker.target.pos) > worker.target.stop:
				worker.pos = worker.pos.move_toward(worker.target.pos, sim.agent_speed(worker) * step)
		sim.tick(step)


## 고정 간격으로 sim을 seconds만큼 돌린다.
static func run(sim: FrostSim, seconds: float, step: float = 0.05) -> void:
	for i in roundi(seconds / step):
		sim.tick(step)
