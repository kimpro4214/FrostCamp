class_name FrostSim
extends RefCounted
## Frost Camp 규칙 전체. 이동은 바깥에서 하고, 여기서는 위치를 보고 근접 규칙만 판정한다.
## 게임과 봇이 같은 규칙을 쓴다.

signal tree_hit(index: int)
signal tree_felled(index: int)
signal bear_hit(index: int)
signal bear_killed(index: int)
signal zone_purchased(id: String, level: int)
signal worker_hired(index: int)
signal game_won

var balance: Dictionary
var money := 0
var bears_killed := 0
## 결과 화면용 기록. 엔딩에 도달하면 시간이 멈춘다.
var time := 0.0
var total_earned := 0
var won := false
var player: SimAgent
var trees: Array[HarvestTree] = []
var bears: Array[HarvestBear] = []
var stalls: Array[Stall] = []
var zones: Array[PurchaseZone] = []
var workers: Array[Worker] = []
## 벌목꾼이 쌓아 두고 운반꾼이 가져가는 원목 적치장
var woodpile := 0
var woodpile_pos: Vector2
var worker_spawn: Vector2
## 쇄빙선이 정박한 곳(연출용)
var ship_pos: Vector2
## 구매로 열린 것들(지역, 판매대). 이름 → true
var unlocked := {}
## 지역 이름 → {"rect": Rect2, "gate": Vector2}
var regions := {}
## 열원 목록. {"id": String, "pos": Vector2, "radius": float, "unlock": String}
var heat_sources: Array[Dictionary] = []
## 업그레이드로 바뀌는 플레이어 능력치. 적재량은 player.stack.capacity에 있다.
var stats := {}
var rng := RandomNumberGenerator.new()
var _fighting_bear := -1


func _init(balance_data: Dictionary, layout: Dictionary, seed_value: int = 1) -> void:
	balance = balance_data
	rng.seed = seed_value
	player = SimAgent.new(
		_vec(layout.player_start), int(balance.player.stack_capacity), float(balance.player.hp))
	woodpile_pos = _vec(layout.woodpile)
	worker_spawn = _vec(layout.worker_spawn)
	ship_pos = _vec(layout.ship)
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
	for id in layout.heat:
		var source: Dictionary = balance.cold.sources[id]
		heat_sources.append({
			"id": id, "pos": _vec(layout.heat[id]),
			"radius": float(source.radius), "unlock": source.get("unlock", ""),
		})
	stats = {
		"move_speed": float(balance.player.move_speed),
		"axe_damage": int(balance.player.axe_damage),
		"harpoon_damage": int(balance.player.harpoon_damage),
		"cold_drain": float(balance.cold.drain),
	}
	_fill_warmth(player)


func agent_speed(agent: SimAgent) -> float:
	var speed: float = agent.speed if agent is Worker else stats.move_speed
	if agent.dazed_left > 0.0:
		speed *= float(balance.player.dazed_speed_mult)
	if agent.warmth <= 0.0:
		speed *= float(balance.cold.frozen_speed_mult)
	return speed


func is_heat_active(source: Dictionary) -> bool:
	return source.unlock == "" or unlocked.has(source.unlock)


## 켜진 열원의 범위 안이면 true.
func is_warm(pos: Vector2) -> bool:
	for source in heat_sources:
		if is_heat_active(source) and pos.distance_to(source.pos) <= source.radius:
			return true
	return false


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
	if won:
		return
	time += delta
	for tree in trees:
		tree.tick(delta)
	for stall in stalls:
		if is_stall_open(stall):
			stall.tick(delta)
	_tick_unload(player, delta)
	_tick_chop(player, delta, stats.axe_damage)
	_tick_fight(player, delta)
	for i in bears.size():
		bears[i].tick(delta, i == _fighting_bear, rng)
	_tick_collect_cash(player)
	_tick_purchase(player, delta)
	_tick_cold(player, delta, stats.cold_drain)
	for worker in workers:
		_tick_cold(worker, delta, float(balance.cold.drain))
		worker.target = WorkerBrain.choose(self, worker)
		match worker.role:
			"lumberjack":
				_tick_chop(worker, delta, worker.damage)
				_tick_pile_drop(worker, delta)
			"porter":
				_tick_pile_take(worker, delta)
				_tick_unload(worker, delta)
			"cashier":
				_tick_collect_cash(worker)


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


func _tick_chop(agent: SimAgent, delta: float, damage: int) -> void:
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
	if trees[index].hit(damage):
		for i in int(config.logs_dropped):
			agent.stack.push("log")
		tree_felled.emit(index)


## 적치장 근처에서 원목을 하나씩 내려놓는다(벌목꾼).
func _tick_pile_drop(agent: SimAgent, delta: float) -> void:
	if agent.pos.distance_to(woodpile_pos) > float(balance.interact.pile_radius) or not agent.stack.items.has("log"):
		agent.unload_timer = 0.0
		return
	agent.unload_timer += delta
	if agent.unload_timer >= float(balance.stall.unload_interval):
		agent.unload_timer = 0.0
		agent.stack.take("log")
		woodpile += 1


## 적치장 근처에서 원목을 하나씩 집어 든다(운반꾼).
func _tick_pile_take(agent: SimAgent, delta: float) -> void:
	if agent.pos.distance_to(woodpile_pos) > float(balance.interact.pile_radius) or woodpile == 0 or agent.stack.free_space() == 0:
		agent.pickup_timer = 0.0
		return
	agent.pickup_timer += delta
	if agent.pickup_timer >= float(balance.stall.unload_interval):
		agent.pickup_timer = 0.0
		woodpile -= 1
		agent.stack.push("log")


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


## 열원 안에서는 온기가 차고, 밖에서는 drain만큼 준다.
func _tick_cold(agent: SimAgent, delta: float, drain: float) -> void:
	if is_warm(agent.pos):
		agent.warmth = minf(agent.warmth + float(balance.cold.recover) * delta, agent.max_warmth)
	else:
		agent.warmth = maxf(agent.warmth - drain * delta, 0.0)


func _fill_warmth(agent: SimAgent) -> void:
	agent.max_warmth = float(balance.cold.max)
	agent.warmth = agent.max_warmth


func _tick_collect_cash(agent: SimAgent) -> void:
	var radius := float(balance.interact.cash_radius)
	for stall in stalls:
		if stall.cash > 0 and agent.pos.distance_to(stall.cash_pos) <= radius:
			money += stall.cash
			total_earned += stall.cash
			stall.cash = 0


## 존 위에 pay_delay만큼 서 있어야 돈이 들어가기 시작한다. 지나가다 밟으면 쓰지 않는다.
func _tick_purchase(agent: SimAgent, delta: float) -> void:
	var config: Dictionary = balance.purchase
	for zone in zones:
		if not is_zone_available(zone) or agent.pos.distance_to(zone.pos) > float(config.zone_radius):
			continue
		if agent.zone_wait_id != zone.id:
			agent.zone_wait_id = zone.id
			agent.zone_wait = 0.0
		agent.zone_wait += delta
		if agent.zone_wait < float(config.pay_delay):
			return
		var rate := maxf(zone.cost() / float(config.fill_time), float(config.min_rate))
		money -= zone.pay(money, rate, delta)
		if zone.try_complete():
			_apply_effect(zone.effect)
			zone_purchased.emit(zone.id, zone.level)
		return
	agent.zone_wait_id = ""


func _apply_effect(effect: Dictionary) -> void:
	if effect.has("unlock"):
		unlocked[effect.unlock] = true
		_check_ending()
		return
	if effect.has("hire"):
		var worker := Worker.new(effect.hire, worker_spawn, balance.workers[effect.hire])
		_fill_warmth(worker)
		workers.append(worker)
		worker_hired.emit(workers.size() - 1)
		return
	match effect.get("stat", ""):
		"stack_capacity":
			player.stack.capacity += int(effect.add)
		"move_speed", "axe_damage", "harpoon_damage", "cold_drain":
			stats[effect.stat] += effect.add


## 쇄빙선 부품을 모두 사면 엔딩.
func _check_ending() -> void:
	for part in balance.ending.ship_parts:
		if not unlocked.has(part):
			return
	won = true
	game_won.emit()


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
