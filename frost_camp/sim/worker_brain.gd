class_name WorkerBrain
extends RefCounted
## 일꾼의 다음 목표를 정한다. 게임(길찾기)과 봇(직선 이동)이 같은 목표를 따라간다.

const STOP := {"tree": 1.0, "pile": 0.8, "stall": 1.0, "cash": 0.4, "idle": 0.3}


static func choose(sim: FrostSim, worker: Worker) -> Dictionary:
	match worker.role:
		"lumberjack":
			return _lumberjack(sim, worker)
		"porter":
			return _porter(sim, worker)
		"cashier":
			return _cashier(sim, worker)
	return _go("idle", worker.pos)


## 나무를 베다가 원목이 더 들어가지 않으면 적치장에 쌓는다.
static func _lumberjack(sim: FrostSim, worker: Worker) -> Dictionary:
	var stack := worker.stack
	if stack.items.is_empty():
		worker.delivering = false
	elif stack.free_space() < int(sim.balance.tree.logs_dropped):
		worker.delivering = true
	if worker.delivering:
		return _go("pile", sim.woodpile_pos)
	var best: HarvestTree = null
	for tree in sim.trees:
		if sim.is_tree_ready(tree) and (best == null or worker.pos.distance_to(tree.pos) < worker.pos.distance_to(best.pos)):
			best = tree
	if best:
		return _go("tree", best.pos)
	if not stack.items.is_empty():
		worker.delivering = true
		return _go("pile", sim.woodpile_pos)
	return _go("idle", sim.woodpile_pos)


## 적치장에서 원목을 채워 원목 판매대에 내려놓는다.
static func _porter(sim: FrostSim, worker: Worker) -> Dictionary:
	var stack := worker.stack
	if stack.items.is_empty():
		worker.delivering = false
	elif stack.free_space() == 0 or sim.woodpile == 0:
		worker.delivering = true
	if worker.delivering:
		for stall in sim.stalls:
			if stall.item == "log" and sim.is_stall_open(stall):
				return _go("stall", stall.pos)
	return _go("pile", sim.woodpile_pos)


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
