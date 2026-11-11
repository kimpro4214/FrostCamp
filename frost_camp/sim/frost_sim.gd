class_name FrostSim
extends RefCounted
## Frost Camp 규칙 전체. 이동은 바깥에서 하고, 여기서는 위치를 보고 근접 규칙만 판정한다.
## 게임과 봇이 같은 규칙을 쓴다.

signal tree_hit(index: int)
signal tree_felled(index: int)
signal zone_purchased(id: String, level: int)

var balance: Dictionary
var money := 0
var player: SimAgent
var trees: Array[HarvestTree] = []
var stalls: Array[Stall] = []
var zones: Array[PurchaseZone] = []
## 업그레이드로 바뀌는 플레이어 능력치. 적재량은 player.stack.capacity에 있다.
var stats := {}


func _init(balance_data: Dictionary, layout: Dictionary) -> void:
	balance = balance_data
	player = SimAgent.new(_vec(layout.player_start), int(balance.player.stack_capacity))
	for p in layout.trees:
		trees.append(HarvestTree.new(_vec(p), balance.tree))
	for s in layout.stalls:
		stalls.append(Stall.new(s.item, _vec(s.pos), _vec(s.cash_pos), balance))
	for id in layout.zones:
		zones.append(PurchaseZone.new(id, _vec(layout.zones[id]), balance.zones[id]))
	stats = {
		"move_speed": float(balance.player.move_speed),
		"axe_damage": int(balance.player.axe_damage),
	}


func agent_speed(_agent: SimAgent) -> float:
	return stats.move_speed


## 선행 조건을 모두 샀고 아직 최대 레벨이 아니면 살 수 있다.
func is_zone_available(zone: PurchaseZone) -> bool:
	if zone.is_maxed():
		return false
	for required in zone.requires:
		if find_zone(required).level == 0:
			return false
	return true


func find_zone(id: String) -> PurchaseZone:
	for zone in zones:
		if zone.id == id:
			return zone
	return null


func tick(delta: float) -> void:
	for tree in trees:
		tree.tick(delta)
	for stall in stalls:
		stall.tick(delta)
	_tick_unload(player, delta)
	_tick_chop(player, delta)
	_tick_collect_cash(player)
	_tick_purchase(player, delta)


func _tick_unload(agent: SimAgent, delta: float) -> void:
	var radius := float(balance.interact.stall_radius)
	for stall in stalls:
		if agent.pos.distance_to(stall.pos) <= radius and agent.stack.items.has(stall.item):
			agent.unload_timer += delta
			if agent.unload_timer >= float(balance.stall.unload_interval):
				agent.unload_timer = 0.0
				agent.stack.take(stall.item)
				stall.stock += 1
			return
	agent.unload_timer = 0.0


func _tick_chop(agent: SimAgent, delta: float) -> void:
	var config: Dictionary = balance.tree
	var index := _nearest_standing_tree(agent.pos)
	if index == -1 or agent.stack.free_space() < int(config.logs_dropped):
		agent.chop_timer = 0.0
		return
	agent.chop_timer += delta
	if agent.chop_timer < float(config.hit_interval):
		return
	agent.chop_timer = 0.0
	tree_hit.emit(index)
	if trees[index].hit(stats.axe_damage):
		for i in int(config.logs_dropped):
			agent.stack.push("log")
		tree_felled.emit(index)


func _tick_collect_cash(agent: SimAgent) -> void:
	var radius := float(balance.interact.cash_radius)
	for stall in stalls:
		if stall.cash > 0 and agent.pos.distance_to(stall.cash_pos) <= radius:
			money += stall.cash
			stall.cash = 0


func _tick_purchase(agent: SimAgent, delta: float) -> void:
	var config: Dictionary = balance.purchase
	for zone in zones:
		if not is_zone_available(zone) or agent.pos.distance_to(zone.pos) > float(config.zone_radius):
			continue
		var rate := maxf(zone.cost() / float(config.fill_time), float(config.min_rate))
		money -= zone.pay(money, rate, delta)
		if zone.try_complete():
			_apply_effect(zone.effect)
			zone_purchased.emit(zone.id, zone.level)
		return


func _apply_effect(effect: Dictionary) -> void:
	match effect.get("stat", ""):
		"stack_capacity":
			player.stack.capacity += int(effect.add)
		"move_speed", "axe_damage":
			stats[effect.stat] += effect.add


func _nearest_standing_tree(pos: Vector2) -> int:
	var best := -1
	var best_dist := float(balance.interact.tree_radius)
	for i in trees.size():
		var dist := pos.distance_to(trees[i].pos)
		if trees[i].is_standing() and dist <= best_dist:
			best = i
			best_dist = dist
	return best


static func _vec(p: Array) -> Vector2:
	return Vector2(p[0], p[1])
