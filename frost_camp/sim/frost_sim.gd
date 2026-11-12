class_name FrostSim
extends RefCounted
## Frost Camp 규칙 전체. 이동은 바깥에서 하고, 여기서는 위치를 보고 근접 규칙만 판정한다.
## 게임과 봇이 같은 규칙을 쓴다.

signal tree_hit(index: int, agent: SimAgent)
signal tree_felled(index: int, agent: SimAgent)
signal bear_hit(index: int, agent: SimAgent)
signal bear_killed(index: int, agent: SimAgent)
signal zone_purchased(id: String, level: int)
signal worker_hired(index: int)
signal cash_collected(stall_index: int, amount: int, agent: SimAgent)
signal structure_hit(index: int, damage: int)
signal structure_broken(index: int)
signal structure_repaired(index: int)
signal raid_warning(wave: int, spawn_pos: Vector2)
signal raid_started(wave: int)
signal raid_cleared(wave: int)
signal raider_hit(index: int, agent: SimAgent)
signal raider_killed(index: int, agent: SimAgent)
signal tower_fired(tower_index: int, raider_index: int)
signal bear_added(index: int)
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
## 기지 시설들의 체력(판매대, 적치장). 판매대는 stall.structure로도 닿는다.
var structures: Array[Structure] = []
var woodpile_structure: Structure
## 사냥꾼이 쌓아 두고 운반꾼·플레이어가 가져가는 고기 적치장. 서식지를 열어야 쓴다.
var meat_pile := 0
var meat_pile_pos: Vector2
var meat_pile_structure: Structure
var worker_spawn: Vector2
## 쇄빙선이 정박한 곳(연출용)
var ship_pos: Vector2
## 구매로 열린 것들(지역, 판매대). 이름 → true
var unlocked := {}
## 지역 이름 → {"rect": Rect2, "gate": Vector2, "open": bool}
## open인 지역(확장 땅)은 사면 울타리 전체가 없어져 기지가 넓어진다.
var regions := {}
## 열원 목록. {"id": String, "pos": Vector2, "radius": float, "unlock": String}
var heat_sources: Array[Dictionary] = []
## 업그레이드로 바뀌는 플레이어 능력치. 적재량은 player.stack.capacity에 있다.
var stats := {}
var rng := RandomNumberGenerator.new()
## 습격 웨이브와 습격 곰들
var raid: Raid
## 적치장 → 원목 판매대 컨베이어. 사기 전에는 level 0이다.
var conveyor: Conveyor
## 포탑 목록. {"id": String, "pos": Vector2, "level": int, "timer": float, "structure": Structure}
var towers: Array[Dictionary] = []
## 곰 늘리기 구매로 서식지에 더 나올 곰 자리. 앞에서부터 쓴다.
var extra_bear_spots: Array[Vector2] = []
var _bear_area: Rect2
## 이번 프레임에 누군가와 싸운 곰들(번호 → true). 싸우는 곰은 배회하거나 걸어가지 않는다.
var _fighting_bears := {}
var _fighting_raiders := {}


func _init(balance_data: Dictionary, layout: Dictionary, seed_value: int = 1) -> void:
	balance = balance_data
	rng.seed = seed_value
	player = SimAgent.new(
		_vec(layout.player_start), int(balance.player.stack_capacity), float(balance.player.hp))
	woodpile_pos = _vec(layout.woodpile)
	meat_pile_pos = _vec(layout.meat_pile)
	worker_spawn = _vec(layout.worker_spawn)
	ship_pos = _vec(layout.ship)
	for p in layout.trees:
		trees.append(HarvestTree.new(_vec(p), balance.tree))
	for region_name in layout.regions:
		var r: Dictionary = layout.regions[region_name]
		regions[region_name] = {
			"rect": Rect2(r.rect[0], r.rect[1], r.rect[2], r.rect[3]), "gate": _vec(r.gate), "open": r.get("open", false),
		}
		for p in r.get("trees", []):
			var tree := HarvestTree.new(_vec(p), balance.tree)
			tree.unlock = region_name
			trees.append(tree)
	var bear_area: Rect2 = regions.habitat.rect.grow(-float(balance.bear.wall_margin))
	_bear_area = bear_area
	for p in layout.get("extra_bears", []):
		extra_bear_spots.append(_vec(p))
	for p in layout.bears:
		bears.append(HarvestBear.new(_vec(p), bear_area, balance.bear))
	for s in layout.stalls:
		var stall := Stall.new(s.item, _vec(s.pos), _vec(s.cash_pos), balance)
		stall.unlock = s.get("unlock", "")
		stall.structure = _add_structure("stall", stall.pos, _vec(s.repair_pos))
		stall.structure.unlock = stall.unlock
		stall.structure.raid_target = s.get("raid_target", true)
		stalls.append(stall)
	woodpile_structure = _add_structure("woodpile", woodpile_pos, _vec(layout.woodpile_repair))
	for t in layout.towers:
		var tower_structure := _add_structure("tower", _vec(t.pos), _vec(t.repair_pos))
		tower_structure.unlock = t.id
		towers.append({"id": t.id, "pos": _vec(t.pos), "level": 0, "timer": 0.0, "structure": tower_structure})
	var belt_points: Array[Vector2] = []
	for p in layout.conveyor.path:
		belt_points.append(_vec(p))
	conveyor = Conveyor.new(belt_points, balance.conveyor)
	conveyor.structure = _add_structure("conveyor", _vec(layout.conveyor.pos), _vec(layout.conveyor.repair_pos))
	conveyor.structure.unlock = "conveyor"
	meat_pile_structure = _add_structure("meat_pile", meat_pile_pos, _vec(layout.meat_pile_repair))
	meat_pile_structure.unlock = "habitat"
	var spawns: Array[Vector2] = []
	for p in layout.raid_spawns:
		spawns.append(_vec(p))
	raid = Raid.new(balance.raid, spawns)
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


## 서 있고, 확장 땅의 나무라면 그 땅을 산 뒤여야 벨 수 있다.
func is_tree_ready(tree: HarvestTree) -> bool:
	return tree.is_standing() and (tree.unlock == "" or unlocked.has(tree.unlock))


func is_stall_open(stall: Stall) -> bool:
	return stall.unlock == "" or unlocked.has(stall.unlock)


## 열려 있고 부서지지 않았으면 손님에게 팔고 물건을 받는다.
func is_stall_working(stall: Stall) -> bool:
	return is_stall_open(stall) and not stall.structure.is_broken()


## 열려 있고(해금된) 부서지지 않은 시설이면 true.
func is_structure_standing(index: int) -> bool:
	var structure := structures[index]
	return not structure.is_broken() and (structure.unlock == "" or unlocked.has(structure.unlock))


## 시설 하나에 피해를 준다. 부서지면 structure_broken이 나온다.
func damage_structure(index: int, damage: int) -> void:
	var structure := structures[index]
	if structure.is_broken():
		return
	var broke := structure.take_hit(damage)
	structure_hit.emit(index, damage)
	if broke:
		structure_broken.emit(index)


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
	_fighting_bears.clear()
	_fighting_raiders.clear()
	for tree in trees:
		tree.tick(delta)
	for stall in stalls:
		if is_stall_working(stall):
			stall.tick(delta)
	_tick_conveyor(delta)
	_tick_unload(player, delta)
	_tick_pile_take(player, delta, "log")
	_tick_pile_take(player, delta, "meat")
	_tick_chop(player, delta, stats.axe_damage)
	_tick_fight(player, delta)
	_tick_collect_cash(player)
	_tick_purchase(player, delta)
	_tick_cold(player, delta, stats.cold_drain)
	for worker in workers:
		_tick_cold(worker, delta, float(balance.cold.drain))
		worker.target = WorkerBrain.choose(self, worker)
		match worker.role:
			"lumberjack":
				_tick_chop(worker, delta, worker.damage)
				_tick_pile_drop(worker, delta, "log")
			"hunter":
				_tick_fight(worker, delta)
				_tick_pile_drop(worker, delta, "meat")
			"porter":
				_tick_pile_take(worker, delta, worker.carry_item)
				_tick_unload(worker, delta)
			"cashier":
				_tick_collect_cash(worker)
	# 싸우는 곰은 이번 프레임에 싸운 모든 사람(플레이어, 사냥꾼)을 본 뒤에 움직인다.
	for i in bears.size():
		bears[i].tick(delta, _fighting_bears.has(i), rng)
	_tick_raid(delta)
	_tick_towers(delta)


func _tick_unload(agent: SimAgent, delta: float) -> void:
	var radius := float(balance.interact.stall_radius)
	for stall in stalls:
		if is_stall_working(stall) and agent.pos.distance_to(stall.pos) <= radius and agent.stack.items.has(stall.item):
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
	tree_hit.emit(index, agent)
	if trees[index].hit(damage):
		for i in int(config.logs_dropped):
			agent.stack.push("log")
		tree_felled.emit(index, agent)


## 적치장 개수. item은 "log"(원목 적치장) 또는 "meat"(고기 적치장).
func pile_count(item: String) -> int:
	return woodpile if item == "log" else meat_pile


func pile_pos(item: String) -> Vector2:
	return woodpile_pos if item == "log" else meat_pile_pos


func pile_structure(item: String) -> Structure:
	return woodpile_structure if item == "log" else meat_pile_structure


## 쓸 수 있는 적치장인가(부서지지 않았고 열려 있다).
func is_pile_open(item: String) -> bool:
	var structure := pile_structure(item)
	return not structure.is_broken() and (structure.unlock == "" or unlocked.has(structure.unlock))


func _change_pile(item: String, amount: int) -> void:
	if item == "log":
		woodpile += amount
	else:
		meat_pile += amount


## 적치장 근처에서 그 품목을 하나씩 내려놓는다(벌목꾼은 원목, 사냥꾼은 고기).
func _tick_pile_drop(agent: SimAgent, delta: float, item: String) -> void:
	if not is_pile_open(item) or agent.pos.distance_to(pile_pos(item)) > float(balance.interact.pile_radius) or not agent.stack.items.has(item):
		agent.unload_timer = 0.0
		return
	agent.unload_timer += delta
	if agent.unload_timer >= float(balance.stall.unload_interval):
		agent.unload_timer = 0.0
		agent.stack.take(item)
		_change_pile(item, 1)


## 적치장 근처에서 그 품목을 하나씩 집어 든다(운반꾼, 플레이어).
func _tick_pile_take(agent: SimAgent, delta: float, item: String) -> void:
	if not is_pile_open(item) or agent.pos.distance_to(pile_pos(item)) > float(balance.interact.pile_radius) or pile_count(item) == 0 or agent.stack.free_space() == 0:
		if agent.pos.distance_to(pile_pos(item)) <= float(balance.interact.pile_radius):
			agent.pickup_timer = 0.0
		return
	agent.pickup_timer += delta
	if agent.pickup_timer >= float(balance.stall.unload_interval):
		agent.pickup_timer = 0.0
		_change_pile(item, -1)
		agent.stack.push(item)


## 곰(서식지 곰이나 습격 곰) 근처에 가면 가까운 쪽과 자동으로 싸운다. 플레이어와 사냥꾼이 같은 규칙을 쓴다.
## 곰도 반격하고, 체력이 0이 되면 잠시 멍해진다(죽지 않는다).
## 서식지 곰은 고기를 담을 자리가 있어야 싸우지만, 습격 곰은 자리가 없어도 막는다.
func _tick_fight(agent: SimAgent, delta: float) -> void:
	var config: Dictionary = balance.bear
	if agent.dazed_left > 0.0:
		agent.dazed_left -= delta
		if agent.dazed_left <= 0.0:
			agent.dazed_left = 0.0
			agent.hp = agent.max_hp
		return
	var bear_index := _nearest_living_bear(agent.pos)
	if agent.stack.free_space() < int(config.meat_dropped):
		bear_index = -1
	var raider_index := _nearest_raider(agent.pos)
	if raider_index != -1 and bear_index != -1:
		if agent.pos.distance_to(raid.bears[raider_index].pos) <= agent.pos.distance_to(bears[bear_index].pos):
			bear_index = -1
		else:
			raider_index = -1
	if bear_index == -1 and raider_index == -1:
		agent.attack_timer = 0.0
		agent.hp = minf(agent.hp + float(balance.player.hp_regen) * delta, agent.max_hp)
		return
	var enemy = raid.bears[raider_index] if raider_index != -1 else bears[bear_index]
	if raider_index != -1:
		_fighting_raiders[raider_index] = true
	else:
		_fighting_bears[bear_index] = true
	var damage: int = agent.damage if agent is Worker else stats.harpoon_damage
	agent.attack_timer += delta
	if agent.attack_timer >= float(balance.player.harpoon_interval):
		agent.attack_timer = 0.0
		if raider_index != -1:
			raider_hit.emit(raider_index, agent)
		else:
			bear_hit.emit(bear_index, agent)
		if enemy.take_hit(damage):
			bears_killed += 1
			if raider_index != -1:
				_fighting_raiders.erase(raider_index)
				_reward_raider_kill(agent)
				raider_killed.emit(raider_index, agent)
			else:
				_fighting_bears.erase(bear_index)
				for i in int(config.meat_dropped):
					agent.stack.push("meat")
				bear_killed.emit(bear_index, agent)
			return
	enemy.attack_timer += delta
	if enemy.attack_timer >= float(config.attack_interval):
		enemy.attack_timer = 0.0
		agent.hp -= float(config.damage)
		if agent.hp <= 0.0:
			agent.hp = 0.0
			agent.dazed_left = float(balance.player.dazed_time)
			agent.attack_timer = 0.0


## 컨베이어가 적치장 원목을 싣고 첫 원목 판매대로 보낸다. 컨베이어나 적치장이 부서지면 멈추고,
## 판매대가 부서지면 끝에 닿은 원목이 거기서 기다린다.
func _tick_conveyor(delta: float) -> void:
	if conveyor.level == 0 or conveyor.structure.is_broken():
		return
	var stall := stalls[0]
	stall.stock += conveyor.advance(delta, is_stall_working(stall))
	if conveyor.try_load(delta, woodpile > 0 and not woodpile_structure.is_broken()):
		woodpile -= 1


## 습격 진행. 경고·습격·방어 성공 이벤트를 내고, 습격 곰을 가장 가까운 멀쩡한 시설로 몰아 부수게 한다.
func _tick_raid(delta: float) -> void:
	match raid.tick(delta, rng):
		"warning":
			raid_warning.emit(raid.wave + 1, raid.spawn_pos)
		"attack":
			raid_started.emit(raid.wave)
		"cleared":
			raid_cleared.emit(raid.wave)
	var config: Dictionary = balance.raid
	for i in raid.bears.size():
		var bear := raid.bears[i]
		if not bear.is_alive() or _fighting_raiders.has(i):
			continue
		if bear.target == -1 or not is_structure_standing(bear.target):
			bear.target = _nearest_standing_structure(bear.pos)
			bear.attack_timer = 0.0
		if bear.target == -1:
			# 노릴 시설이 없으면 플레이어에게 달려든다. 닿으면 근접 전투가 시작된다.
			var reach := float(balance.interact.bear_radius) * 0.8
			if bear.pos.distance_to(player.pos) > reach:
				bear.pos = bear.pos.move_toward(player.pos, bear.speed * delta)
			continue
		var goal := structures[bear.target].pos
		if bear.pos.distance_to(goal) > float(config.attack_radius):
			bear.pos = bear.pos.move_toward(goal, bear.speed * delta)
			continue
		bear.attack_timer += delta
		if bear.attack_timer >= float(config.attack_interval):
			bear.attack_timer = 0.0
			damage_structure(bear.target, int(config.damage))


## 산 포탑은 사거리 안의 가장 가까운 습격 곰을 일정 간격으로 쏜다. 부서진 포탑은 쏘지 않는다.
func _tick_towers(delta: float) -> void:
	var config: Dictionary = balance.tower
	for t in towers.size():
		var tower: Dictionary = towers[t]
		if tower.level == 0 or tower.structure.is_broken():
			continue
		tower.timer = minf(tower.timer + delta, float(config.interval))
		if tower.timer < float(config.interval):
			continue
		var target := _nearest_raider(tower.pos, float(config.range))
		if target == -1:
			continue
		tower.timer = 0.0
		tower_fired.emit(t, target)
		raider_hit.emit(target, null)
		var damage: int = int(config.damage) + int(config.damage_add) * (int(tower.level) - 1)
		if raid.bears[target].take_hit(damage):
			bears_killed += 1
			_reward_raider_kill(null)
			raider_killed.emit(target, null)


## 습격 곰 보상. 직접 잡았고 고기 판매대가 열려 있으면 등에 들어가는 만큼 고기를 준다.
## 포탑이 잡았거나, 판매대가 아직 없거나(등이 고기로 막히지 않게), 등에 자리가 없으면 현상금을 준다.
func _reward_raider_kill(agent: SimAgent) -> void:
	var meat := 0
	if agent and _has_open_stall("meat"):
		meat = mini(int(balance.raid.meat_dropped), agent.stack.free_space())
	for i in meat:
		agent.stack.push("meat")
	if meat > 0:
		return
	var reward := int(balance.raid.reward)
	money += reward
	total_earned += reward


func _has_open_stall(item: String) -> bool:
	for stall in stalls:
		if stall.item == item and is_stall_open(stall):
			return true
	return false


## 서식지에 곰을 count마리 더 풀어 놓는다(남은 자리만큼).
func _add_bears(count: int) -> void:
	for i in count:
		if extra_bear_spots.is_empty():
			return
		bears.append(HarvestBear.new(extra_bear_spots.pop_front(), _bear_area, balance.bear))
		bear_added.emit(bears.size() - 1)


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
	for i in stalls.size():
		var stall := stalls[i]
		if stall.cash > 0 and agent.pos.distance_to(stall.cash_pos) <= radius:
			var amount := stall.cash
			money += amount
			total_earned += amount
			stall.cash = 0
			cash_collected.emit(i, amount, agent)


## 구매 존과 부서진 시설의 수리 존에 돈을 넣는다.
func _tick_purchase(agent: SimAgent, delta: float) -> void:
	for zone in zones:
		if is_zone_available(zone) and _pay_into(agent, zone, delta):
			if zone.try_complete():
				_apply_effect(zone.effect)
				zone_purchased.emit(zone.id, zone.level)
			return
	for i in structures.size():
		var structure := structures[i]
		if structure.is_broken() and _pay_into(agent, structure.repair, delta):
			if structure.try_finish_repair():
				structure_repaired.emit(i)
			return
	agent.zone_wait_id = ""


## 존 위에 서 있으면 true. pay_delay만큼 서 있어야 돈이 들어가기 시작한다(지나가다 밟으면 쓰지 않는다).
func _pay_into(agent: SimAgent, zone: PurchaseZone, delta: float) -> bool:
	var config: Dictionary = balance.purchase
	if agent.pos.distance_to(zone.pos) > float(config.zone_radius):
		return false
	if agent.zone_wait_id != zone.id:
		agent.zone_wait_id = zone.id
		agent.zone_wait = 0.0
	agent.zone_wait += delta
	if agent.zone_wait >= float(config.pay_delay):
		var rate := maxf(zone.cost() / float(config.fill_time), float(config.min_rate))
		money -= zone.pay(money, rate, delta)
	return true


func _apply_effect(effect: Dictionary) -> void:
	if effect.has("unlock"):
		unlocked[effect.unlock] = true
		if effect.unlock == balance.raid.start_after:
			raid.activate()
		_check_ending()
		return
	if effect.has("bears"):
		_add_bears(int(effect.bears))
		return
	if effect.has("conveyor"):
		unlocked["conveyor"] = true
		conveyor.level += 1
		return
	if effect.has("tower"):
		unlocked[effect.tower] = true
		for tower in towers:
			if tower.id == effect.tower:
				if tower.level == 0:
					tower.timer = float(balance.tower.interval)  # 세우자마자 쏠 수 있다.
				tower.level += 1
		return
	if effect.has("hire"):
		var worker := Worker.new(effect.hire, worker_spawn, balance.workers[effect.hire])
		worker.stall = int(effect.get("stall", -1))
		_fill_warmth(worker)
		workers.append(worker)
		worker_hired.emit(workers.size() - 1)
		return
	match effect.get("stat", ""):
		"stack_capacity":
			player.stack.capacity += int(effect.add)
		"move_speed", "axe_damage", "harpoon_damage", "cold_drain":
			stats[effect.stat] += effect.add


func _add_structure(kind: String, pos: Vector2, repair_pos: Vector2) -> Structure:
	var structure := Structure.new(kind, pos, repair_pos, balance.structures[kind])
	structure.repair.id = "repair_%d" % structures.size()
	structures.append(structure)
	return structure


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
		if is_tree_ready(trees[i]) and dist <= best_dist:
			best = i
			best_dist = dist
	return best


## 사거리 안에서 가장 가까운 살아 있는 습격 곰. 사거리를 안 주면 근접 전투 거리다.
func _nearest_raider(pos: Vector2, max_dist: float = -1.0) -> int:
	var best := -1
	var best_dist := max_dist if max_dist > 0.0 else float(balance.interact.bear_radius)
	for i in raid.bears.size():
		var dist := pos.distance_to(raid.bears[i].pos)
		if raid.bears[i].is_alive() and dist <= best_dist:
			best = i
			best_dist = dist
	return best


## 습격 곰이 노릴 가장 가까운 시설.
func _nearest_standing_structure(pos: Vector2) -> int:
	var best := -1
	var best_dist := INF
	for i in structures.size():
		var dist := pos.distance_to(structures[i].pos)
		if structures[i].raid_target and is_structure_standing(i) and dist < best_dist:
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
