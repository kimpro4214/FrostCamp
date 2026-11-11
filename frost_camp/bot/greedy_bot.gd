class_name GreedyBot
extends RefCounted
## 탐욕 봇. 살 수 있는 존 중 남은 금액이 가장 싼 것을 목표로 돈을 벌고 산다.
## 길찾기 없이 직선으로 움직이되 지역 울타리는 입구로 드나든다. 규칙 판정은 게임과 같은 FrostSim이 한다.

const STOP_DIST := {"tree": 1.0, "bear": 1.0, "stall": 1.0, "cash": 0.4, "zone": 0.4, "gate": 0.05}

var sim: FrostSim
var time := 0.0
## [시간, 존 id, 레벨]
var purchases: Array = []
var _delivering := false


func _init(frost_sim: FrostSim) -> void:
	sim = frost_sim
	sim.zone_purchased.connect(func(id: String, level: int) -> void: purchases.append([time, id, level]))


func step(delta: float) -> void:
	var target := _route(_choose_target())
	var agent := sim.player
	var to_target: Vector2 = target.pos - agent.pos
	if to_target.length() > STOP_DIST[target.kind]:
		agent.pos += to_target.limit_length(sim.agent_speed(agent) * delta)
	# 일꾼은 worker_brain이 정한 목표로 직선 이동한다(게임에서는 길찾기).
	for worker in sim.workers:
		if worker.pos.distance_to(worker.target.pos) > worker.target.stop:
			worker.pos = worker.pos.move_toward(worker.target.pos, sim.agent_speed(worker) * delta)
	sim.tick(delta)
	time += delta


## 살 수 있는 존 중 남은 금액이 가장 적은 것. 없으면 null.
func cheapest_zone() -> PurchaseZone:
	var best: PurchaseZone = null
	for zone in sim.zones:
		if sim.is_zone_available(zone) and (best == null or zone.remaining() < best.remaining()):
			best = zone
	return best


func is_done() -> bool:
	return cheapest_zone() == null


func _choose_target() -> Dictionary:
	var stack := sim.player.stack
	if stack.items.is_empty():
		_delivering = false
	elif stack.free_space() < _drop_size():
		_delivering = true

	var zone := cheapest_zone()
	if zone and sim.money >= zone.remaining():
		return {"kind": "zone", "pos": zone.pos}
	if _delivering:
		return {"kind": "stall", "pos": _delivery_stall().pos}
	if stack.items.is_empty():
		for stall in sim.stalls:
			if stall.cash > 0:
				return {"kind": "cash", "pos": stall.cash_pos}
	var source := _harvest_target(true)
	if not source.is_empty():
		return source
	if not stack.items.is_empty():
		_delivering = true
		return {"kind": "stall", "pos": _delivery_stall().pos}
	return _harvest_target(false)


## 고기 판매대가 열렸으면 곰을, 아니면 나무를 노린다.
## available_only면 지금 잡을 수 있는 것 중 가장 가까운 것, 아니면 가장 빨리 다시 나타나는 것.
func _harvest_target(available_only: bool) -> Dictionary:
	var hunting := sim.unlocked.has("habitat") and _has_open_stall("meat")
	var sources: Array = sim.bears if hunting else sim.trees
	var best: RefCounted = null
	var best_score := INF
	for source in sources:
		var ready: bool = source.is_alive() if hunting else source.is_standing()
		if available_only and not ready:
			continue
		var score: float = sim.player.pos.distance_to(source.pos) if available_only else source.respawn_left
		if score < best_score:
			best = source
			best_score = score
	if best == null:
		return {}
	return {"kind": "bear" if hunting else "tree", "pos": best.pos}


func _drop_size() -> int:
	return maxi(int(sim.balance.tree.logs_dropped), int(sim.balance.bear.meat_dropped))


## 들고 있는 아이템을 받는 열린 판매대 중 가장 가까운 것.
func _delivery_stall() -> Stall:
	var best: Stall = null
	for stall in sim.stalls:
		if sim.is_stall_open(stall) and sim.player.stack.items.has(stall.item):
			if best == null or sim.player.pos.distance_to(stall.pos) < sim.player.pos.distance_to(best.pos):
				best = stall
	return best if best else sim.stalls[0]


func _has_open_stall(item: String) -> bool:
	for stall in sim.stalls:
		if stall.item == item and sim.is_stall_open(stall):
			return true
	return false


## 목표와 봇이 울타리 안팎으로 갈려 있으면 먼저 입구로 간다.
func _route(target: Dictionary) -> Dictionary:
	var pos := sim.player.pos
	for region in sim.regions.values():
		var rect: Rect2 = region.rect
		if rect.has_point(pos) != rect.has_point(target.pos) and pos.distance_to(region.gate) > STOP_DIST.gate:
			return {"kind": "gate", "pos": region.gate}
	return target
