extends "res://frost_camp/tests/test_case.gd"
## 습격 곰이 일꾼을 죽인다(6차 QA 5번). 쓰러지면 고용 존 단계가 내려가 다시 사야 한다.

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim() -> FrostSim:
	var balance := Fixtures.balance()
	balance.raid.worker_reach = 3.0
	balance.workers.lumberjack.hp = 4
	balance.zones.lumberjack.costs = [10, 500]
	return FrostSim.new(balance, Fixtures.layout())


func _place_raider(sim: FrostSim, pos: Vector2) -> RaidBear:
	var bear := RaidBear.new(pos, 100, 2.0)
	sim.raid.state = Raid.State.ATTACKING
	sim.raid.bears.append(bear)
	return bear


func _buy(sim: FrostSim, id: String) -> void:
	sim.money += 100
	sim.player.pos = sim.find_zone(id).pos
	for i in 60:
		sim.tick(0.05)
	sim.player.pos = Vector2(0, 30)


func test_raider_attacks_nearby_worker_and_kills_it() -> void:
	var sim := _make_sim()
	_buy(sim, "lumberjack")
	check_eq(sim.find_zone("lumberjack").level, 1, "벌목꾼을 고용했다")
	var worker := sim.workers[0]
	check_eq(worker.zone_id, "lumberjack", "고용한 존을 기억한다")
	var died := []
	sim.worker_died.connect(func(i: int) -> void: died.append(i))
	worker.pos = Vector2(-15, 0)
	_place_raider(sim, Vector2(-16.5, 0))
	for i in 80:
		worker.pos = Vector2(-15, 0)  # 일꾼이 도망가지 않게 붙잡아 둔다
		sim.tick(0.05)
	check(worker.dead, "체력이 다하면 쓰러진다")
	check_eq(died, [0], "쓰러질 때 알린다")
	check_eq(sim.find_zone("lumberjack").level, 0, "고용 존 단계가 내려간다")
	check(sim.is_zone_available(sim.find_zone("lumberjack")), "다시 고용할 수 있다")


func test_far_worker_is_safe() -> void:
	var sim := _make_sim()
	_buy(sim, "lumberjack")
	var worker := sim.workers[0]
	worker.pos = Vector2(-15, 0)
	_place_raider(sim, Vector2(-15, 10))
	for i in 20:
		worker.pos = Vector2(-15, 0)
		sim.tick(0.05)
	check_eq(worker.hp, worker.max_hp, "worker_reach 밖 일꾼은 노리지 않는다")


func test_worker_freezes_when_raider_close() -> void:
	var sim := _make_sim()
	_buy(sim, "lumberjack")
	var worker := sim.workers[0]
	worker.pos = Vector2(-15, 0)
	_place_raider(sim, Vector2(-17, 0))
	sim.tick(0.05)
	check_eq(worker.target.pos, worker.pos, "곰이 가까이 오면 겁먹고 멈춘다")
