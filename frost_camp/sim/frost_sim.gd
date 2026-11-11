class_name FrostSim
extends RefCounted
## Frost Camp 규칙 전체. 이동은 바깥에서 하고, 여기서는 위치를 보고 근접 규칙만 판정한다.
## 게임과 봇이 같은 규칙을 쓴다.

signal tree_hit(index: int)
signal tree_felled(index: int)
signal bear_hit(index: int)
signal bear_killed(index: int)
signal zone_purchased(id: String, level: int)

var balance: Dictionary
var money := 0
var bears_killed := 0
var player: SimAgent
var trees: Array[HarvestTree] = []
var bears: Array[HarvestBear] = []
var stalls: Array[Stall] = []
var zones: Array[PurchaseZone] = []
## 구매로 열린 것들(지역, 판매대). 이름 → true
var unlocked := {}
## 지역 이름 → {"rect": Rect2, "gate": Vector2}
var regions := {}
## 업그레이드로 바뀌는 플레이어 능력치. 적재량은 player.stack.capacity에 있다.
var stats := {}
var rng := RandomNumberGenerator.new()
var _fighting_bear := -1


func _init(balance_data: Dictionary, layout: Dictionary, seed_value: int = 1) -> void:
	balance = balance_data
	rng.seed = seed_value
	player = SimAgent.new(
		_vec(layout.player_start), int(balance.player.stack_capacity), float(balance.player.hp))
	for p in layout.trees:
		trees.append(HarvestTree.new(_vec(p), balance.tree))
	for region_name in layout.regions:
		var r: Dictionary = layout.regions[region_name]
		regions[region_name] = {"rect": Rect2(r.rect[0], r.rect[1], r.rect[2], r.rect[3]), "gate": _vec(r.gate)}
	var bear_area: Rect2 = regions.habitat.rect.grow(-float(balance.bear.wall_margin))
	for p in layout.bears:
		bears.append(HarvestBear.new(_vec(p), bear_area, balance.bear))
	for s in layout.stalls:
		var stall := Stall.new(s.item, _vec(s.pos), _vec(s.cash_pos), balance)
		stall.unlock = s.get("unlock", "")
		stalls.append(stall)
	for id in layout.zones:
		zones.append(PurchaseZone.new(id, _vec(layout.zones[id]), balance.zones[id]))
	stats = {
		"move_speed": float(balance.player.move_speed),
		"axe_damage": int(balance.player.axe_damage),
		"harpoon_damage": int(balance.player.harpoon_damage),
	}


func agent_speed(agent: SimAgent) -> float:
	if agent.dazed_left > 0.0:
		return stats.move_speed * float(balance.player.dazed_speed_mult)
	return stats.move_speed


func is_stall_open(stall: Stall) -> bool:
	return stall.unlock == "" or unlocked.has(stall.unlock)


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
		if is_stall_open(stall):
			stall.tick(delta)
	_tick_unload(player, delta)
	_tick_chop(player, delta)
	_tick_fight(player, delta)
	for i in bears.size():
		bears[i].tick(delta, i == _fighting_bear, rng)
	_tick_collect_cash(player)
	_tick_purchase(player, delta)


func _tick_unload(agent: SimAgent, delta: float) -> void:
	var radius := float(balance.interact.stall_radius)
	for stall in stalls:
		if is_stall_open(stall) and agent.pos.distance_to(stall.pos) <= radius and agent.stack.items.has(stall.item):
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


## 곰 근처에 가면 자동으로 싸운다. 곰도 반격하고, 체력이 0이 되면 잠시 멍해진다(죽지 않는다).
func _tick_fight(agent: SimAgent, delta: float) -> void:
	var config: Dictionary = balance.bear
	_fighting_bear = -1
	if agent.dazed_left > 0.0:
		agent.dazed_left -= delta
		if agent.dazed_left <= 0.0:
			agent.dazed_left = 0.0
			agent.hp = agent.max_hp
		return
	var index := _nearest_living_bear(agent.pos)
	if index == -1 or agent.stack.free_space() < int(config.meat_dropped):
		agent.attack_timer = 0.0
		agent.hp = minf(agent.hp + float(balance.player.hp_regen) * delta, agent.max_hp)
		return
	_fighting_bear = index
	var bear := bears[index]
	agent.attack_timer += delta
	if agent.attack_timer >= float(balance.player.harpoon_interval):
		agent.attack_timer = 0.0
		bear_hit.emit(index)
		if bear.take_hit(stats.harpoon_damage):
			for i in int(config.meat_dropped):
				agent.stack.push("meat")
			bears_killed += 1
			bear_killed.emit(index)
			_fighting_bear = -1
			return
	bear.attack_timer += delta
	if bear.attack_timer >= float(config.attack_interval):
		bear.attack_timer = 0.0
		agent.hp -= float(config.damage)
		if agent.hp <= 0.0:
			agent.hp = 0.0
			agent.dazed_left = float(balance.player.dazed_time)
			agent.attack_timer = 0.0


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
	if effect.has("unlock"):
		unlocked[effect.unlock] = true
		return
	match effect.get("stat", ""):
		"stack_capacity":
			player.stack.capacity += int(effect.add)
		"move_speed", "axe_damage", "harpoon_damage":
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


func _nearest_living_bear(pos: Vector2) -> int:
	var best := -1
	var best_dist := float(balance.interact.bear_radius)
	for i in bears.size():
		var dist := pos.distance_to(bears[i].pos)
		if bears[i].is_alive() and dist <= best_dist:
			best = i
			best_dist = dist
	return best


static func _vec(p: Array) -> Vector2:
	return Vector2(p[0], p[1])
