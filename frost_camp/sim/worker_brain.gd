class_name WorkerBrain
extends RefCounted
## 일꾼의 다음 목표를 정한다. 게임(길찾기)과 봇(직선 이동)이 같은 목표를 따라간다.

const STOP := {"tree": 1.0, "bear": 1.0, "hole": 0.2, "pile": 0.8, "stall": 1.0, "cash": 0.4, "idle": 0.3}


static func choose(sim: FrostSim, worker: Worker) -> Dictionary:
	match worker.role:
		"lumberjack":
			return _gatherer(sim, worker, "log")
		"miner":
			return _gatherer(sim, worker, "crystal")
		"porter":
			return _porter(sim, worker)
		"hunter":
			return _hunter(sim, worker)
		"fisher":
			return _fisher(sim, worker)
		"cashier":
			return _cashier(sim, worker)
	return _go("idle", worker.pos)


## 맡은 품목(벌목꾼은 원목, 광부는 빙결정)의 가장 가까운 나무·바위를 캐다가, 더 담을 수 없으면 그 적치장에 쌓는다.
## 같은 역할의 다른 일꾼이 노리는 나무·바위는 건너뛴다(남은 게 없을 때만 겹친다).
static func _gatherer(sim: FrostSim, worker: Worker, item: String) -> Dictionary:
	var stack := worker.stack
	var pile := sim.pile_pos(item)
	var taken := {}
	for other in sim.workers:
		if other != worker and other.role == worker.role and other.target.get("kind", "") == "tree":
			taken[other.target.pos] = true
	var best: HarvestTree = null
	var best_free := false
	for tree in sim.trees:
		if tree.item != item or not sim.is_tree_ready(tree):
			continue
		var free := not taken.has(tree.pos)
		if best == null or (free and not best_free) or (free == best_free and worker.pos.distance_to(tree.pos) < worker.pos.distance_to(best.pos)):
			best = tree
			best_free = free
	if stack.items.is_empty():
		worker.delivering = false
	elif best and stack.free_space() < sim.drops_of(best):
		worker.delivering = true
	if worker.delivering:
		return _go("pile", pile)
	if best:
		return _go("tree", best.pos)
	if not stack.items.is_empty():
		worker.delivering = true
		return _go("pile", pile)
	return _go("idle", pile)


## 원목·고기 적치장 중 더 많이 쌓인 쪽에서 채워, 그 품목의 일하는 판매대에 내려놓는다.
static func _porter(sim: FrostSim, worker: Worker) -> Dictionary:
	var stack := worker.stack
	if stack.items.is_empty():
		worker.delivering = false
		worker.carry_item = worker.line if worker.line != "" else _fullest_pile(sim)
	elif stack.free_space() == 0 or sim.pile_count(worker.carry_item) == 0:
		worker.delivering = true
	if worker.delivering:
		for stall in sim.stalls:
			if stall.item == worker.carry_item and sim.is_stall_working(stall):
				return _go("stall", stall.pos)
	return _go("pile", sim.pile_pos(worker.carry_item))


## 쌓인 게 있고 받을 판매대가 있는 적치장 중 더 많이 쌓인 품목. 둘 다 비었으면 원목.
static func _fullest_pile(sim: FrostSim) -> String:
	var best := "log"
	var best_count := -1
	for item in sim.pile_items():
		if not sim.is_pile_open(item) or not _has_working_stall(sim, item):
			continue
		if sim.pile_count(item) > best_count:
			best = item
			best_count = sim.pile_count(item)
	return best


static func _has_working_stall(sim: FrostSim, item: String) -> bool:
	for stall in sim.stalls:
		if stall.item == item and sim.is_stall_working(stall):
			return true
	return false


## 가장 가까운 살아 있는 서식지 곰을 잡으러 간다. 고기를 더 담을 수 없으면 고기 적치장에 쌓는다.
static func _hunter(sim: FrostSim, worker: Worker) -> Dictionary:
	var stack := worker.stack
	if stack.items.is_empty():
		worker.delivering = false
	elif stack.free_space() < int(sim.balance.bear.meat_dropped):
		worker.delivering = true
	if worker.delivering:
		return _go("pile", sim.meat_pile_pos)
	var best: HarvestBear = null
	for bear in sim.bears:
		if bear.is_alive() and (best == null or worker.pos.distance_to(bear.pos) < worker.pos.distance_to(best.pos)):
			best = bear
	if best:
		return _go("bear", best.pos)
	if not stack.items.is_empty():
		worker.delivering = true
	return _go("pile", sim.meat_pile_pos)


## 맡은 얼음 구멍(낚시꾼 순서대로 나눔)에서 낚고, 등이 차면 연어 적치장에 쌓는다.
static func _fisher(sim: FrostSim, worker: Worker) -> Dictionary:
	var stack := worker.stack
	if stack.items.is_empty():
		worker.delivering = false
	elif stack.free_space() == 0:
		worker.delivering = true
	if worker.delivering:
		return _go("pile", sim.pile_pos("salmon"))
	var order := 0
	for other in sim.workers:
		if other == worker:
			break
		if other.role == "fisher":
			order += 1
	return _go("hole", sim.fishing_holes[order % sim.fishing_holes.size()])


## 전담 판매대가 있으면 그 돈 더미 자리에 서 있고, 없으면 돈이 가장 많이 쌓인 판매대로 간다.
static func _cashier(sim: FrostSim, worker: Worker) -> Dictionary:
	if worker.stall >= 0:
		return _go("cash", sim.stalls[worker.stall].cash_pos)
	var best: Stall = null
	for stall in sim.stalls:
		if sim.is_stall_open(stall) and (best == null or stall.cash > best.cash):
			best = stall
	return _go("cash", best.cash_pos)


static func _go(kind: String, pos: Vector2) -> Dictionary:
	return {"kind": kind, "pos": pos, "stop": STOP[kind]}
