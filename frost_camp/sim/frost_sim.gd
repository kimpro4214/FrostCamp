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
signal fish_caught(hole: int, agent: SimAgent)
## 플레이어의 작살총이 습격 곰을 쐈다(곰 번호).
signal gun_fired(raider_index: int)
## 모닥불에 원목을 넣었다(열원 번호, 넣은 사람. 적치장에서 저절로 채우면 null).
signal fire_fueled(source_index: int, agent: SimAgent)
## 모닥불 연료가 다 떨어져 꺼졌다(열원 번호).
signal fire_out(source_index: int)
## 플레이어만 얻는 고급 자원을 얻었다(품목, 얻은 자리).
signal premium_found(item: String, pos: Vector2)
## 광맥의 빙결정 바위 하나가 빛나기 시작했다(나무 번호).
signal crystal_glowed(tree_index: int)
## 판매대가 고급 자원을 바로 사 갔다(판매대 번호, 품목).
signal premium_sold(stall_index: int, item: String)
## 얼음 구멍 하나를 새로 뚫었다(구멍 번호).
signal hole_drilled(hole: int)
signal worker_retired(index: int)
## 일꾼이 습격 곰에게 맞았다 / 쓰러졌다(일꾼 번호).
signal worker_hit(index: int)
signal worker_died(index: int)
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
## 기지 방벽. 구간마다 시설 번호(sim.structures). 방벽 구매 레벨이 0이면 서 있지 않다.
var walls: Array[int] = []
## 방벽 구간 시설 번호 → 두 끝점 {"a", "b"}
var wall_ends := {}
## 얼음 구멍 낚시터 자리
var fishing_holes: Array[Vector2] = []
## 뚫린 얼음 구멍 수. 앞에서부터 이만큼만 낚을 수 있다("얼음 구멍 뚫기"를 살 때마다 하나씩).
var holes_open := 0
## 구멍마다 지금 낚고 있는 사람(먼저 선 사람). 비었으면 null. 한 구멍에서는 한 사람만 낚는다.
var hole_users: Array = []
## 작살총 단계(0이면 없음)와 다음 발사까지 쌓인 시간
var gun_level := 0
var gun_timer := 0.0
## 다음 빛나는 빙결정까지 쌓인 시간
var glow_timer := 0.0
## 보스 레이드(빙하 곰왕). 레이드 중에는 플레이어와 용병이 레이드 영역에 있다.
var boss_raid: BossRaid
## 원목·고기 말고 다른 품목의 적치장. 품목 → {"count": int, "pos": Vector2, "structure": Structure}
var extra_piles := {}
var wall_level := 0
## 기지 영역. 해금 이름("" = 처음부터) → Rect2. 습격 곰이 이 밖에 있으면 방벽부터 부순다.
var base_rects := {}
var worker_spawn: Vector2
## 쇄빙선이 정박한 곳(연출용)
var ship_pos: Vector2
## 구매로 열린 것들(지역, 판매대). 이름 → true
var unlocked := {}
## 지역 이름 → {"rect": Rect2, "gate": Vector2, "open": bool}
## open인 지역(확장 땅)은 사면 울타리 전체가 없어져 기지가 넓어진다.
var regions := {}
## 열원 목록. {"id": String, "pos": Vector2, "radius": float, "radii": Array, "level": int, "unlock": String}
## 반경은 "모닥불 키우기" 구매로 radii의 다음 값이 된다.
var heat_sources: Array[Dictionary] = []
## 업그레이드로 바뀌는 플레이어 능력치. 적재량은 player.stack.capacity에 있다.
var stats := {}
var rng := RandomNumberGenerator.new()
## 습격 웨이브와 습격 곰들
var raid: Raid
## 자원 라인별 컨베이어(품목 → Conveyor). 적치장에서 그 품목 판매대로 나른다. 깔기 전에는 level 0이다.
var conveyors := {}
## 라인별 운반 레벨(품목 → 0~3). 1은 전담 운반꾼, 2부터는 운반꾼이 물러나고 컨베이어.
var haul_levels := {}
## 원목 라인 컨베이어(예전 이름)
var conveyor: Conveyor:
	get:
		return conveyors.get("log")
## 포탑 목록. {"id": String, "pos": Vector2, "level": int, "timer": float, "structure": Structure}
var towers: Array[Dictionary] = []
## 곰 늘리기 구매로 서식지에 더 나올 곰 자리. 앞에서부터 쓴다.
var extra_bear_spots: Array[Vector2] = []
var _bear_area: Rect2
## 이번 프레임에 누군가와 싸운 곰들(번호 → true). 싸우는 곰은 배회하거나 걸어가지 않는다.
var _fighting_bears := {}
var _fighting_raiders := {}
## 스폰 지점마다 그 곰들이 노리는 방벽 구간(시설 번호). 없으면 -1.
var spawn_gates: Array[int] = []
## 스폰 지점마다 곰이 거쳐 가는 두 점: 길목 바깥 접근점, 길목 안쪽 점. 길목이 없으면 빈 배열.
var spawn_paths: Array = []


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
			"openings": r.get("openings", []).map(func(p: Array) -> Vector2: return _vec(p)),
		}
		for p in r.get("trees", []):
			var tree := HarvestTree.new(_vec(p), balance.tree)
			tree.unlock = region_name
			trees.append(tree)
		for p in r.get("crystals", []):
			var crystal := HarvestTree.new(_vec(p), balance.crystal)
			crystal.unlock = region_name
			crystal.item = "crystal"
			trees.append(crystal)
	var bear_area: Rect2 = regions.habitat.rect.grow(-float(balance.bear.wall_margin))
	_bear_area = bear_area
	for p in layout.get("extra_bears", []):
		extra_bear_spots.append(_vec(p))
	for p in layout.bears:
		bears.append(HarvestBear.new(_vec(p), bear_area, balance.bear))
	for s in layout.stalls:
		var stall := Stall.new(s.item, _vec(s.pos), _vec(s.cash_pos), balance)
		stall.unlock = s.get("unlock", "")
		stall.exit_dir = _vec(s.get("exit", [0, 1]))
		for item in balance.items:
			if balance.items[item].get("sold_at", "") == stall.item:
				stall.premium.append(item)
		stall.structure = _add_structure("stall", stall.pos, _vec(s.repair_pos))
		stall.structure.unlock = stall.unlock
		stall.structure.raid_target = s.get("raid_target", true)
		stalls.append(stall)
	woodpile_structure = _add_structure("woodpile", woodpile_pos, _vec(layout.woodpile_repair))
	for t in layout.towers:
		var tower_structure := _add_structure("tower", _vec(t.pos), _vec(t.repair_pos))
		tower_structure.unlock = t.id
		towers.append({"id": t.id, "pos": _vec(t.pos), "level": 0, "timer": 0.0, "structure": tower_structure})
	for item in layout.conveyors:
		var line: Dictionary = layout.conveyors[item]
		var belt_points: Array[Vector2] = []
		for p in line.path:
			belt_points.append(_vec(p))
		var belt := Conveyor.new(belt_points, balance.conveyor)
		belt.item = item
		belt.stall = int(line.stall)
		belt.structure = _add_structure("conveyor", _vec(line.pos), _vec(line.repair_pos))
		belt.structure.unlock = "conveyor_" + item
		conveyors[item] = belt
		haul_levels[item] = 0
	meat_pile_structure = _add_structure("meat_pile", meat_pile_pos, _vec(layout.meat_pile_repair))
	meat_pile_structure.unlock = "habitat"
	for p in layout.get("fishing_holes", []):
		fishing_holes.append(_vec(p))
	holes_open = mini(int(layout.get("holes_open", 0)), fishing_holes.size())
	hole_users.resize(fishing_holes.size())
	for item in layout.get("piles", {}):
		var pile: Dictionary = layout.piles[item]
		var pile_structure := _add_structure(item + "_pile", _vec(pile.pos), _vec(pile.repair_pos))
		pile_structure.unlock = pile.get("unlock", "")
		extra_piles[item] = {"count": 0, "pos": _vec(pile.pos), "structure": pile_structure}
	for key in layout.base.rects:
		var r: Array = layout.base.rects[key]
		base_rects[key] = Rect2(r[0], r[1], r[2], r[3])
	for w in layout.base.walls:
		_add_wall(w)
	var spawns: Array[Vector2] = []
	for p in layout.raid_spawns:
		# [x, y] 또는 {"pos": [x, y], "gate": [a, b]}. gate는 그 스폰의 곰이 노리는 방벽 구간(길목)이다.
		spawns.append(_vec(p.pos) if p is Dictionary else _vec(p))
		spawn_gates.append(_wall_between(_vec(p.gate[0]), _vec(p.gate[1])) if p is Dictionary and p.has("gate") else -1)
		spawn_paths.append(_gate_path(_vec(p.gate[0]), _vec(p.gate[1])) if p is Dictionary and p.has("gate") else [])
	raid = Raid.new(balance.raid, spawns)
	for id in layout.zones:
		zones.append(PurchaseZone.new(id, _vec(layout.zones[id]), balance.zones[id]))
	for id in layout.heat:
		var source: Dictionary = balance.cold.sources[id]
		var radii: Array = source.radius
		# fuel_max가 0이면 연료가 줄지 않는다(테스트 지형 등).
		heat_sources.append({
			"id": id, "pos": _vec(layout.heat[id]), "radius": float(radii[0]), "radii": radii, "level": 0,
			"unlock": source.get("unlock", ""),
			"fuel_max": float(source.get("fuel_max", 0.0)), "fuel": float(source.get("fuel_max", 0.0)),
			"per_log": float(source.get("per_log", 0.0)), "auto_level": int(source.get("auto_level", 99)),
			"feed_timer": 0.0,
		})
	boss_raid = BossRaid.new(self, balance, layout)
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
	if source.fuel_max > 0.0 and source.fuel <= 0.0:
		return false
	return source.unlock == "" or unlocked.has(source.unlock)


## 이 열원은 원목 적치장에서 저절로 채워지는가(모닥불 키우기 auto_level단계부터, 벌목꾼이 있을 때).
func is_fire_auto(source: Dictionary) -> bool:
	if source.level < source.auto_level:
		return false
	for worker in workers:
		if worker.role == "lumberjack" and not worker.retired:
			return true
	return false


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


## 지금 기지에 있는 시설이면 true. 해금 전 시설, 확장으로 사라진 방벽 구간, 사기 전 방벽은 없는 것으로 친다.
func is_structure_active(index: int) -> bool:
	var structure := structures[index]
	if structure.unlock != "" and not unlocked.has(structure.unlock):
		return false
	if structure.until != "" and unlocked.has(structure.until):
		return false
	return structure.kind != "wall" or wall_level > 0


## 있고 부서지지 않은 시설이면 true.
func is_structure_standing(index: int) -> bool:
	return is_structure_active(index) and not structures[index].is_broken()


## 해금된 기지 영역 안이면 true.
func is_in_base(pos: Vector2) -> bool:
	for key in base_rects:
		if (key == "" or unlocked.has(key)) and base_rects[key].has_point(pos):
			return true
	return false


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
## 선행 조건은 존 id("habitat"), 또는 레벨이 붙은 "fire:2"(그 존이 2단계 이상) 형식이다.
func is_zone_available(zone: PurchaseZone) -> bool:
	if zone.is_maxed():
		return false
	for required in zone.requires:
		if not _requirement_met(required):
			return false
	return true


## 모닥불 단계만 모자라 못 사는 존이면 필요한 모닥불 단계, 아니면 0(화면이 "모닥불 N단계 필요"를 띄운다).
func fire_needed(zone: PurchaseZone) -> int:
	if zone.is_maxed():
		return 0
	var needed := 0
	for required in zone.requires:
		if _requirement_met(required):
			continue
		var parts: PackedStringArray = required.split(":")
		if parts[0] != "fire" or parts.size() < 2:
			return 0
		needed = int(parts[1])
	return needed


func _requirement_met(required: String) -> bool:
	var parts := required.split(":")
	var level := int(parts[1]) if parts.size() > 1 else 1
	return find_zone(parts[0]).level >= level


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
	for item in extra_piles:
		_tick_pile_take(player, delta, item)
	_free_left_holes()
	_tick_fish(player, delta)
	_tick_chop(player, delta, stats.axe_damage)
	# 레이드 중에는 동굴의 곰왕과만 싸운다(기지 근접 전투와 체력 회복은 멈춘다).
	if not boss_raid.active:
		_tick_fight(player, delta)
	_tick_collect_cash(player)
	_tick_purchase(player, delta)
	_tick_fuel(delta)
	_tick_glow(delta)
	# 레이드 중에는 동굴 안이라 춥지 않다. 기지 습격은 그대로 온다(8차 QA 2번).
	if boss_raid.active:
		boss_raid.tick(delta)
	else:
		boss_raid.tick_portal(delta)
		_tick_cold(player, delta, stats.cold_drain)
	# 일꾼은 추위를 타지 않는다(3차 QA: 일꾼이 계속 어는 것이 불편했다).
	for worker in workers:
		if worker.retired:
			worker.target = {"kind": "idle", "pos": worker_spawn, "stop": 0.3}
			continue
		if worker.role == "merc" and boss_raid.active:
			worker.target = {"kind": "idle", "pos": worker.pos, "stop": 0.3}
			continue  # 레이드 중 용병은 boss_raid가 움직인다.
		worker.target = WorkerBrain.choose(self, worker)
		# 습격 곰이 가까이 오면 겁에 질려 그 자리에 멈춘다(사냥꾼과 용병은 맞서 싸운다). 지켜 주지 않으면 쓰러진다.
		if not worker.role in ["hunter", "merc"] and _nearest_raider(worker.pos, float(balance.raid.get("worker_reach", 0.0))) != -1:
			worker.target = {"kind": "idle", "pos": worker.pos, "stop": 0.3}
		match worker.role:
			"lumberjack":
				_tick_chop(worker, delta, worker.damage, "log")
				_tick_pile_drop(worker, delta, "log")
			"miner":
				_tick_chop(worker, delta, worker.damage, "crystal")
				_tick_pile_drop(worker, delta, "crystal")
			"hunter":
				_tick_fight(worker, delta)
				_tick_pile_drop(worker, delta, "meat")
			"fisher":
				_tick_fish(worker, delta)
				_tick_pile_drop(worker, delta, "salmon")
			"porter":
				_tick_pile_take(worker, delta, worker.carry_item)
				_tick_unload(worker, delta)
			"cashier":
				_tick_collect_cash(worker)
			"merc":
				_tick_merc_guard(worker, delta)
	# 싸우는 곰은 이번 프레임에 싸운 모든 사람(플레이어, 사냥꾼)을 본 뒤에 움직인다.
	for i in bears.size():
		bears[i].tick(delta, _fighting_bears.has(i), rng)
	_tick_raid(delta)
	_tick_towers(delta)
	_tick_gun(delta)


func _tick_unload(agent: SimAgent, delta: float) -> void:
	var radius := float(balance.interact.stall_radius)
	for s in stalls.size():
		var stall := stalls[s]
		if not is_stall_working(stall) or agent.pos.distance_to(stall.pos) > radius:
			continue
		# 고급 자원은 줄 선 손님과 상관없이 판매대가 바로 사 간다(돈 더미에 쌓인다).
		for premium in stall.premium:
			if agent.stack.items.has(premium):
				agent.stack.take(premium)
				stall.cash += int(balance.items[premium].price)
				premium_sold.emit(s, premium)
		if agent.stack.items.has(stall.item):
			agent.unload_timer += delta
			if agent.unload_timer >= float(balance.stall.unload_interval):
				agent.unload_timer = 0.0
				agent.stack.take(stall.item)
				stall.stock += 1
			return
	agent.unload_timer = 0.0


## 근처 나무나 빙결정 바위를 친다. only_item을 주면 그 품목만 캔다(벌목꾼은 원목, 광부는 빙결정).
func _tick_chop(agent: SimAgent, delta: float, damage: int, only_item: String = "") -> void:
	var config: Dictionary = balance.tree
	var index := _nearest_standing_tree(agent.pos, only_item, agent is Worker)
	if index == -1 or agent.stack.free_space() < drops_of(trees[index]):
		agent.chop_timer = 0.0
		return
	agent.chop_timer += delta
	if agent.chop_timer < float(config.hit_interval):
		return
	agent.chop_timer = 0.0
	tree_hit.emit(index, agent)
	if trees[index].hit(damage):
		if trees[index].glowing:
			trees[index].glowing = false
			agent.stack.push("gem")
			premium_found.emit("gem", trees[index].pos)
		else:
			for i in drops_of(trees[index]):
				agent.stack.push(trees[index].item)
		tree_felled.emit(index, agent)


## 지금 칠 수 있는 가장 가까운 나무·바위 번호(화면이 들 도구를 고를 때 쓴다). 없으면 -1.
func tree_at(pos: Vector2) -> int:
	return _nearest_standing_tree(pos)


## 나무 한 그루(바위 하나)가 쓰러질 때 나오는 개수
func drops_of(tree: HarvestTree) -> int:
	if tree.glowing:
		return 1
	return int(balance.tree.logs_dropped) if tree.item == "log" else int(balance.crystal.dropped)


## 적치장 개수. 원목·고기는 따로 둔 변수, 나머지(연어 등)는 extra_piles에 있다.
func pile_count(item: String) -> int:
	match item:
		"log":
			return woodpile
		"meat":
			return meat_pile
	return extra_piles[item].count


func pile_pos(item: String) -> Vector2:
	match item:
		"log":
			return woodpile_pos
		"meat":
			return meat_pile_pos
	return extra_piles[item].pos


func pile_structure(item: String) -> Structure:
	match item:
		"log":
			return woodpile_structure
		"meat":
			return meat_pile_structure
	return extra_piles[item].structure


## 적치장이 있는 품목들
func pile_items() -> Array:
	return ["log", "meat"] + extra_piles.keys()


## 쓸 수 있는 적치장인가(부서지지 않았고 열려 있다).
func is_pile_open(item: String) -> bool:
	var structure := pile_structure(item)
	return not structure.is_broken() and (structure.unlock == "" or unlocked.has(structure.unlock))


func _change_pile(item: String, amount: int) -> void:
	match item:
		"log":
			woodpile += amount
		"meat":
			meat_pile += amount
		_:
			extra_piles[item].count += amount


## 낚시할 수 있는(뚫린) 얼음 구멍 번호. 범위 안에 없으면 -1.
func fishing_hole_at(pos: Vector2) -> int:
	for i in holes_open:
		if pos.distance_to(fishing_holes[i]) <= float(balance.fish.hole_radius):
			return i
	return -1


## 다른 사람이 낚고 있지 않은 구멍인가(agent 자신이 쓰는 구멍은 빈 것으로 본다).
func is_hole_free(hole: int, agent: SimAgent) -> bool:
	return hole_users[hole] == null or hole_users[hole] == agent


## 구멍을 떠난 사람의 자리를 비운다.
func _free_left_holes() -> void:
	for i in hole_users.size():
		var user: SimAgent = hole_users[i]
		if user and user.pos.distance_to(fishing_holes[i]) > float(balance.fish.hole_radius):
			hole_users[i] = null


## 얼음 구멍 위에 서 있으면 catch_interval마다 연어가 한 마리씩 등에 쌓인다(자리가 있을 때).
## 한 구멍에서는 먼저 선 한 사람만 낚는다.
func _tick_fish(agent: SimAgent, delta: float) -> void:
	var hole := fishing_hole_at(agent.pos)
	if hole != -1 and is_hole_free(hole, agent):
		hole_users[hole] = agent
	elif hole != -1:
		hole = -1
	if hole == -1 or agent.stack.free_space() == 0:
		agent.fish_timer = 0.0
		return
	agent.fish_timer += delta
	if agent.fish_timer >= float(balance.fish.catch_interval):
		agent.fish_timer = 0.0
		# 플레이어가 낚을 때만 가끔 황금 연어가 걸린다(낚시꾼은 못 잡는다).
		if agent == player and balance.has("premium") and rng.randf() < float(balance.premium.gold_salmon_chance):
			agent.stack.push("gold_salmon")
			premium_found.emit("gold_salmon", fishing_holes[hole])
		else:
			agent.stack.push("salmon")
		fish_caught.emit(hole, agent)


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
	for item in conveyors:
		var belt: Conveyor = conveyors[item]
		if belt.level == 0 or belt.structure.is_broken():
			continue
		var stall := stalls[belt.stall]
		stall.stock += belt.advance(delta, is_stall_working(stall))
		if belt.try_load(delta, pile_count(item) > 0 and is_pile_open(item)):
			_change_pile(item, -1)


## 습격 진행. 경고·습격·방어 성공 이벤트를 내고, 습격 곰을 가장 가까운 멀쩡한 시설로 몰아 부수게 한다.
func _tick_raid(delta: float) -> void:
	match raid.tick(delta, rng):
		"warning":
			raid_warning.emit(raid.wave + 1, raid.spawn_pos)
		"attack":
			for bear in raid.bears:
				bear.gate = spawn_gates[raid.spawn_index]
				bear.path = spawn_paths[raid.spawn_index].duplicate()
			raid_started.emit(raid.wave)
		"cleared":
			for w in workers:
				if not w.dead:
					w.hp = w.max_hp
			raid_cleared.emit(raid.wave)
	var config: Dictionary = balance.raid
	for i in raid.bears.size():
		var bear := raid.bears[i]
		if not bear.is_alive() or _fighting_raiders.has(i):
			continue
		if bear.target == -1 or not is_structure_standing(bear.target):
			if bear.target != -1 and structures[bear.target].kind == "wall":
				bear.breached = true  # 노리던 방벽 구간이 무너졌으니 그 틈으로 들어간다.
			bear.target = _raid_target(bear)
			bear.attack_timer = 0.0
		# 가는 길에 worker_reach 안에 일꾼이 있으면 그 일꾼부터 친다.
		var victim := _nearest_worker(bear.pos, float(config.get("worker_reach", 0.0)))
		if victim != -1:
			var prey := workers[victim]
			if bear.pos.distance_to(prey.pos) > float(config.attack_radius) * 0.6:
				bear.pos = bear.pos.move_toward(prey.pos, bear.speed * delta)
			else:
				bear.attack_timer += delta
				if bear.attack_timer >= float(config.attack_interval):
					bear.attack_timer = 0.0
					_hurt_worker(victim, float(config.damage))
			continue
		# 길목 바깥 접근점까지 먼저 걷고, 길목 방벽을 노리지 않으면 길목 안쪽 점도 거친다(서식지 벽 등을 가로지르지 않게).
		var attacking_gate := bear.target != -1 and bear.target == bear.gate
		if not bear.path.is_empty() and not (attacking_gate and bear.path.size() == 1):
			bear.pos = bear.pos.move_toward(bear.path[0], bear.speed * delta)
			if bear.pos.distance_to(bear.path[0]) < 0.2:
				bear.path.pop_front()
			continue
		if bear.target == -1:
			# 노릴 시설이 없으면 플레이어에게 달려든다. 닿으면 근접 전투가 시작된다.
			# 플레이어가 레이드에 가 있으면 그 자리에서 기다린다.
			if boss_raid.active:
				continue
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


## 광맥을 연 뒤 glow_interval마다, 빛나는 바위가 없으면 서 있는 빙결정 바위 하나가 빛나기 시작한다.
func _tick_glow(delta: float) -> void:
	if not balance.has("premium"):
		return
	var candidates: Array[int] = []
	for i in trees.size():
		if trees[i].glowing:
			return
		if trees[i].item == "crystal" and is_tree_ready(trees[i]):
			candidates.append(i)
	if candidates.is_empty():
		return
	glow_timer += delta
	if glow_timer < float(balance.premium.glow_interval):
		return
	glow_timer = 0.0
	var pick: int = candidates[rng.randi() % candidates.size()]
	trees[pick].glowing = true
	crystal_glowed.emit(pick)


## 기지에 있는 용병은 사거리 안의 습격 곰을 쏴서 막는다(레이드에 가지 않을 때도 쓸모가 있다).
func _tick_merc_guard(merc: Worker, delta: float) -> void:
	var config: Dictionary = balance.mercs
	merc.attack_timer = minf(merc.attack_timer + delta, float(config.interval))
	if merc.attack_timer < float(config.interval):
		return
	var target := _nearest_raider(merc.pos, float(config.range))
	if target == -1:
		return
	merc.attack_timer = 0.0
	raider_hit.emit(target, merc)
	if raid.bears[target].take_hit(int(config.damage)):
		bears_killed += 1
		_reward_raider_kill(null)
		raider_killed.emit(target, merc)


## 작살총: 플레이어가 사거리 안의 가장 가까운 습격 곰을 interval마다 자동으로 쏜다. 기절해 있으면 못 쏜다.
## 단계마다 사거리와 피해가 오른다. 플레이어가 잡은 것으로 쳐서 고기 보상을 받을 수 있다.
func _tick_gun(delta: float) -> void:
	if gun_level == 0 or player.dazed_left > 0.0:
		return
	var config: Dictionary = balance.gun
	gun_timer = minf(gun_timer + delta, float(config.interval))
	if gun_timer < float(config.interval):
		return
	var level := mini(gun_level, config.range.size()) - 1
	var target := _nearest_raider(player.pos, float(config.range[level]))
	if target == -1:
		return
	gun_timer = 0.0
	gun_fired.emit(target)
	raider_hit.emit(target, player)
	if raid.bears[target].take_hit(int(config.damage[level])):
		bears_killed += 1
		_reward_raider_kill(player)
		raider_killed.emit(target, player)


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


## 모닥불 연료는 초당 1씩 탄다. 플레이어가 원목을 들고 가까이 서 있으면 하나씩 넣어 채운다.
## 모닥불을 auto_level단계까지 키우면 벌목꾼이 원목 적치장에서 가져와 채운다(적치장 원목이 줄어든다).
func _tick_fuel(delta: float) -> void:
	for i in heat_sources.size():
		var source := heat_sources[i]
		if source.fuel_max <= 0.0:
			continue
		var was_lit: bool = source.fuel > 0.0
		source.fuel = maxf(source.fuel - delta, 0.0)
		if was_lit and source.fuel == 0.0:
			fire_out.emit(i)
		if source.fuel > source.fuel_max - source.per_log:
			source.feed_timer = 0.0
			continue
		var feeder: SimAgent = null
		if player.pos.distance_to(source.pos) <= float(balance.cold.refuel_radius) and player.stack.items.has("log"):
			feeder = player
		elif not (is_fire_auto(source) and woodpile > 0):
			source.feed_timer = 0.0
			continue
		source.feed_timer += delta
		if source.feed_timer < float(balance.stall.unload_interval) * 2.0:
			continue
		source.feed_timer = 0.0
		if feeder:
			feeder.stack.take("log")
		else:
			_change_pile("log", -1)
		source.fuel = minf(source.fuel + source.per_log, source.fuel_max)
		fire_fueled.emit(i, feeder)


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
				# 한 단계를 산 뒤에는 기다리는 시간을 처음부터(repeat_delay만큼 더) 다시 센다. 서 있기만 해도 다음 단계에 돈이 새지 않게.
				agent.zone_wait = -float(balance.purchase.get("repeat_delay", 0.0))
				var hired_before := workers.size()
				_apply_effect(zone.effect)
				for w in range(hired_before, workers.size()):
					workers[w].zone_id = zone.id
				zone_purchased.emit(zone.id, zone.level)
			return
	for i in structures.size():
		var structure := structures[i]
		if structure.is_broken() and is_structure_active(i) and can_repair() and _pay_into(agent, structure.repair, delta):
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
	if effect.has("fire"):
		for source in heat_sources:
			if source.id == effect.fire:
				source.level = mini(source.level + 1, source.radii.size() - 1)
				source.radius = float(source.radii[source.level])
		return
	if effect.has("gun"):
		gun_level += int(effect.gun)
		gun_timer = float(balance.gun.interval)  # 사자마자 쏠 수 있다.
		return
	if effect.has("holes"):
		holes_open = mini(holes_open + int(effect.holes), fishing_holes.size())
		hole_drilled.emit(holes_open - 1)
		return
	if effect.has("walls"):
		_raise_walls()
		return
	if effect.has("bears"):
		_add_bears(int(effect.bears))
		return
	if effect.has("conveyor"):
		_raise_conveyor(effect.conveyor)
		return
	if effect.has("haul"):
		_raise_haul(effect.haul)
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
		worker.line = effect.get("line", "")
		if worker.line != "":
			worker.carry_item = worker.line
		_fill_warmth(worker)
		workers.append(worker)
		worker_hired.emit(workers.size() - 1)
		return
	match effect.get("stat", ""):
		"stack_capacity":
			player.stack.capacity += int(effect.add)
		"move_speed", "axe_damage", "harpoon_damage", "cold_drain":
			stats[effect.stat] += effect.add


## 방벽 구간 하나. 위치는 구간 가운데, 수리 존은 그 단계 기지 영역 안쪽으로 조금 들어간 곳이다.
func _add_wall(w: Dictionary) -> void:
	var a := _vec(w.a)
	var b := _vec(w.b)
	var mid := (a + b) / 2.0
	var stage: String = w.get("from", "")
	var inward: Vector2 = (base_rects[stage].get_center() - mid).normalized()
	var config: Dictionary = balance.structures.wall
	var structure := Structure.new("wall", mid, mid + inward * 1.6, {"hp": config.hp[0], "repair_cost": config.repair_cost})
	structure.repair.id = "repair_%d" % structures.size()
	structure.unlock = stage
	structure.until = w.get("until", "")
	structure.raid_target = false  # 방벽은 _raid_target이 따로 고른다.
	walls.append(structures.size())
	wall_ends[structures.size()] = {"a": a, "b": b}
	structures.append(structure)


## 방벽 레벨을 올린다. 모든 구간이 새 최대 체력으로 다시 선다(부서진 구간도).
func _raise_walls() -> void:
	wall_level += 1
	var hp_levels: Array = balance.structures.wall.hp
	var max_hp := int(hp_levels[mini(wall_level, hp_levels.size()) - 1])
	for i in walls:
		var structure := structures[i]
		structure.max_hp = max_hp
		structure.hp = max_hp
		structure.repair.level = 1
		structure.repair.paid = 0


func _add_structure(kind: String, pos: Vector2, repair_pos: Vector2) -> Structure:
	var structure := Structure.new(kind, pos, repair_pos, balance.structures[kind])
	structure.repair.id = "repair_%d" % structures.size()
	structures.append(structure)
	return structure


func _raise_conveyor(item: String) -> void:
	unlocked["conveyor_" + item] = true
	conveyors[item].level += 1


## 라인 운반 단계를 올린다. 1단계는 그 품목만 나르는 운반꾼을 고용하고,
## 2단계에서 운반꾼이 물러나며 컨베이어가 깔리고, 그 뒤로는 컨베이어가 빨라진다.
func _raise_haul(item: String) -> void:
	haul_levels[item] += 1
	if haul_levels[item] == 1:
		_apply_effect({"hire": "porter", "line": item})
		return
	if haul_levels[item] == 2:
		for i in workers.size():
			if workers[i].role == "porter" and workers[i].line == item and not workers[i].retired:
				workers[i].retired = true
				workers[i].stack.items.clear()
				worker_retired.emit(i)
	_raise_conveyor(item)


## 쇄빙선 부품을 모두 사면 엔딩.
func _check_ending() -> void:
	for part in balance.ending.ship_parts:
		if not unlocked.has(part):
			return
	won = true
	game_won.emit()


func _nearest_standing_tree(pos: Vector2, only_item: String = "", skip_glowing := false) -> int:
	var best := -1
	var best_dist := float(balance.interact.tree_radius)
	for i in trees.size():
		var dist := pos.distance_to(trees[i].pos)
		if skip_glowing and trees[i].glowing:
			continue
		if (only_item == "" or trees[i].item == only_item) and is_tree_ready(trees[i]) and dist <= best_dist:
			best = i
			best_dist = dist
	return best


## 사거리 안에서 가장 가까운 살아 있는 습격 곰. 사거리를 안 주면 근접 전투 거리다.
func _nearest_raider(pos: Vector2, max_dist: float = -1.0) -> int:
	var best := -1
	var best_dist := INF
	var reach := max_dist if max_dist > 0.0 else float(balance.interact.bear_radius)
	for i in raid.bears.size():
		var bear := raid.bears[i]
		var dist := pos.distance_to(bear.pos)
		if bear.is_alive() and dist <= reach and dist < best_dist:
			best = i
			best_dist = dist
	return best


## pos에서 reach 안의 가장 가까운 일하는 일꾼 번호. 없으면 -1.
func _nearest_worker(pos: Vector2, reach: float) -> int:
	var best := -1
	var best_dist := reach
	for i in workers.size():
		var w := workers[i]
		var dist := pos.distance_to(w.pos)
		if not w.retired and dist <= best_dist:
			best = i
			best_dist = dist
	return best


## 일꾼이 맞는다. 체력이 다하면 쓰러지고, 고용한 존 단계가 하나 내려가 다시 사야 한다.
## 라인 운반꾼이면 그 라인 운반 단계도 하나 내려간다(컨베이어 단계에서는 운반꾼이 없다).
func _hurt_worker(index: int, damage: float) -> void:
	var w := workers[index]
	w.hp -= damage
	worker_hit.emit(index)
	if w.hp > 0.0:
		return
	w.hp = 0.0
	w.dead = true
	w.retired = true
	w.stack.items.clear()
	var zone := find_zone(w.zone_id)
	if zone and zone.level > 0:
		zone.level -= 1
		zone.paid = 0
	if w.line != "" and haul_levels.get(w.line, 0) == 1:
		haul_levels[w.line] = 0
	worker_died.emit(index)


## 길목 구간 a-b의 바깥 접근점과 안쪽 점. 바깥은 기지 중심에서 먼 쪽이다.
func _gate_path(a: Vector2, b: Vector2) -> Array:
	var mid := (a + b) / 2.0
	var normal := (b - a).orthogonal().normalized()
	if normal.dot(mid - base_rects[""].get_center()) < 0.0:
		normal = -normal
	var config: Dictionary = balance.raid
	return [mid + normal * float(config.get("gate_outside", 2.5)), mid - normal * float(config.get("gate_inside", 2.0))]


## 습격 중에는 수리할 수 없다(웨이브가 끝나야 고친다).
func can_repair() -> bool:
	return raid.state != Raid.State.ATTACKING


## 두 끝점이 a, b인 방벽 구간의 시설 번호(순서 무관). 없으면 -1.
func _wall_between(a: Vector2, b: Vector2) -> int:
	for i in walls:
		var w: Dictionary = wall_ends[i]
		if (w.a == a and w.b == b) or (w.a == b and w.b == a):
			return i
	return -1


## 기지 밖에 있고 아직 방벽을 뚫지 않았으면 그 스폰의 길목 구간(없거나 무너졌으면 가장 가까운 방벽 구간),
## 아니면 가장 가까운 시설.
func _raid_target(bear: RaidBear) -> int:
	if wall_level > 0 and not bear.breached and not is_in_base(bear.pos):
		if bear.gate != -1 and is_structure_standing(bear.gate):
			return bear.gate
		var best := -1
		var best_dist := INF
		for i in walls:
			var dist := bear.pos.distance_to(structures[i].pos)
			if is_structure_standing(i) and dist < best_dist:
				best = i
				best_dist = dist
		if best != -1:
			return best
	return _nearest_standing_structure(bear.pos)


## 습격 곰이 노릴 가장 가까운 시설(방벽 제외).
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
