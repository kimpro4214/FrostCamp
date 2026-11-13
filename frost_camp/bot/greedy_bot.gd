class_name GreedyBot
extends RefCounted
## 탐욕 봇. 살 수 있는 존 중 남은 금액이 가장 싼 것을 목표로 돈을 벌고 산다.
## 습격 곰이 오면 먼저 막고, 부서진 시설은 돈이 모이는 대로 고친다.
## 길찾기 없이 직선으로 움직이되 지역 울타리는 입구로 드나든다. 규칙 판정은 게임과 같은 FrostSim이 한다.

const STOP_DIST := {"tree": 1.0, "bear": 1.0, "hole": 0.3, "stall": 1.0, "cash": 0.4, "zone": 0.4, "gate": 0.05, "heat": 1.0}
## 온기가 이 비율 밑으로 떨어지면 불가로 가서 WARM_UNTIL까지 녹인다.
const WARM_BELOW := 0.2
const WARM_UNTIL := 0.95

var sim: FrostSim
var time := 0.0
## [시간, 존 id, 레벨]
var purchases: Array = []
## false면 추위를 무시한다(추위 압박이 의미 있는지 비교할 때 쓴다).
var warm_up := true
var _delivering := false
var _warming := false


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

	var player := sim.player
	if player.warmth >= player.max_warmth * WARM_UNTIL:
		_warming = false
	elif player.warmth < player.max_warmth * WARM_BELOW:
		_warming = true
	if _warming and warm_up:
		return {"kind": "heat", "pos": _nearest_heat()}

	# 습격 곰이 있으면 먼저 막고, 부서진 시설은 돈이 되면 바로 고친다.
	var raider := _nearest_raider()
	if raider:
		return {"kind": "bear", "pos": raider.pos}
	for structure in sim.structures:
		if structure.is_broken() and sim.money >= structure.repair.remaining():
			return {"kind": "zone", "pos": structure.repair.pos}

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


## 일하는 판매대가 있는 품목 중 가장 비싼 것의 공급원을 노린다(곰 > 연어 > 나무).
## available_only면 지금 얻을 수 있는 것 중 가장 가까운 것, 아니면 가장 빨리 다시 나타나는 것.
func _harvest_target(available_only: bool) -> Dictionary:
	var items := ["meat", "salmon", "log"].filter(func(i: String) -> bool: return sim.balance.items.has(i))
	items.sort_custom(func(a: String, b: String) -> bool:
		return int(sim.balance.items[a].price) > int(sim.balance.items[b].price))
	for item in items:
		if not _has_open_stall(item):
			continue
		var target := _source_of(item, available_only)
		if not target.is_empty():
			return target
	return {}


func _source_of(item: String, available_only: bool) -> Dictionary:
	if item == "salmon":
		var hole := Vector2.INF
		for p in sim.fishing_holes:
			if sim.player.pos.distance_to(p) < sim.player.pos.distance_to(hole):
				hole = p
		return {} if hole == Vector2.INF else {"kind": "hole", "pos": hole}
	var hunting := item == "meat"
	if hunting and not sim.unlocked.has("habitat"):
		return {}
	var sources: Array = sim.bears if hunting else sim.trees
	var best: RefCounted = null
	var best_score := INF
	for source in sources:
		var ready: bool = source.is_alive() if hunting else sim.is_tree_ready(source)
		if available_only and not ready:
			continue
		if not hunting and source.unlock != "" and not sim.unlocked.has(source.unlock):
			continue  # 아직 안 산 확장 땅의 나무
		var score: float = sim.player.pos.distance_to(source.pos) if available_only else source.respawn_left
		if score < best_score:
			best = source
			best_score = score
	if best == null:
		return {}
	return {"kind": "bear" if hunting else "tree", "pos": best.pos}


func _nearest_raider() -> RaidBear:
	var best: RaidBear = null
	for bear in sim.raid.bears:
		if bear.is_alive() and (best == null or sim.player.pos.distance_to(bear.pos) < sim.player.pos.distance_to(best.pos)):
			best = bear
	return best


func _drop_size() -> int:
	return maxi(int(sim.balance.tree.logs_dropped), int(sim.balance.bear.meat_dropped))


## 들고 있는 아이템을 받는 열린 판매대 중 가장 가까운 것.
func _delivery_stall() -> Stall:
	var best: Stall = null
	for stall in sim.stalls:
		if sim.is_stall_working(stall) and sim.player.stack.items.has(stall.item):
			if best == null or sim.player.pos.distance_to(stall.pos) < sim.player.pos.distance_to(best.pos):
				best = stall
	return best if best else sim.stalls[0]


func _nearest_heat() -> Vector2:
	var best := Vector2.INF
	for source in sim.heat_sources:
		if sim.is_heat_active(source) and sim.player.pos.distance_to(source.pos) < sim.player.pos.distance_to(best):
			best = source.pos
	return best


func _has_open_stall(item: String) -> bool:
	for stall in sim.stalls:
		if stall.item == item and sim.is_stall_working(stall):
			return true
	return false


## 목표와 봇이 울타리 안팎으로 갈려 있으면 먼저 입구로 간다.
func _route(target: Dictionary) -> Dictionary:
	var pos := sim.player.pos
	for region_name in sim.regions:
		var region: Dictionary = sim.regions[region_name]
		if region.open and sim.unlocked.has(region_name):
			continue  # 산 확장 땅은 울타리가 없다.
		var rect: Rect2 = region.rect
		if rect.has_point(pos) != rect.has_point(target.pos) and pos.distance_to(region.gate) > STOP_DIST.gate:
			return {"kind": "gate", "pos": region.gate}
	return target
