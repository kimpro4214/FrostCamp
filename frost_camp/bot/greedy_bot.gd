class_name GreedyBot
extends RefCounted
## 탐욕 봇. 살 수 있는 존 중 남은 금액이 가장 싼 것을 목표로 돈을 벌고 산다.
## 길찾기 없이 직선으로 움직이고, 규칙 판정은 게임과 같은 FrostSim이 한다.

const STOP_DIST := {"tree": 1.0, "stall": 1.0, "cash": 0.4, "zone": 0.4}

var sim: FrostSim
var time := 0.0
## [시간, 존 id, 레벨]
var purchases: Array = []
var _delivering := false


func _init(frost_sim: FrostSim) -> void:
	sim = frost_sim
	sim.zone_purchased.connect(func(id: String, level: int) -> void: purchases.append([time, id, level]))


func step(delta: float) -> void:
	var target := _choose_target()
	var agent := sim.player
	var to_target: Vector2 = target.pos - agent.pos
	var travel := sim.agent_speed(agent) * delta
	if to_target.length() > STOP_DIST[target.kind]:
		agent.pos += to_target.limit_length(travel)
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
	var log_drop := int(sim.balance.tree.logs_dropped)
	if stack.items.is_empty():
		_delivering = false
	elif stack.free_space() < log_drop:
		_delivering = true

	var zone := cheapest_zone()
	if zone and sim.money >= zone.remaining():
		return {"kind": "zone", "pos": zone.pos}
	if _delivering:
		return {"kind": "stall", "pos": sim.stalls[0].pos}
	if stack.items.is_empty():
		for stall in sim.stalls:
			if stall.cash > 0:
				return {"kind": "cash", "pos": stall.cash_pos}
	var tree := _nearest_tree(true)
	if tree:
		return {"kind": "tree", "pos": tree.pos}
	if not stack.items.is_empty():
		_delivering = true
		return {"kind": "stall", "pos": sim.stalls[0].pos}
	return {"kind": "tree", "pos": _nearest_tree(false).pos}


## standing_only면 서 있는 나무 중 가장 가까운 것, 아니면 가장 빨리 다시 자라는 것.
func _nearest_tree(standing_only: bool) -> HarvestTree:
	var best: HarvestTree = null
	var best_score := INF
	for tree in sim.trees:
		if standing_only and not tree.is_standing():
			continue
		var score := sim.player.pos.distance_to(tree.pos) if standing_only else tree.respawn_left
		if score < best_score:
			best = tree
			best_score = score
	return best
