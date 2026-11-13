extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")
const OUTSIDE := Vector2(0, 15)


func _make_sim() -> FrostSim:
	return FrostSim.new(Fixtures.balance(), Fixtures.layout())


func test_warmth_drains_outside_and_freezes() -> void:
	var sim := _make_sim()
	sim.player.pos = OUTSIDE
	Fixtures.run(sim, 10.0)
	check(is_equal_approx(sim.player.warmth, 20.0), "밖에서는 초당 drain만큼 준다 (%.2f)" % sim.player.warmth)
	Fixtures.run(sim, 25.0)
	check_eq(sim.player.warmth, 0.0, "0 밑으로는 내려가지 않는다")
	check_eq(sim.agent_speed(sim.player), 2.5, "얼면 이동 속도가 절반이 된다")


func test_campfire_recovers_warmth() -> void:
	var sim := _make_sim()
	sim.player.warmth = 0.0
	sim.player.pos = Vector2(2, 0)
	Fixtures.run(sim, 1.0)
	check(is_equal_approx(sim.player.warmth, 10.0), "모닥불 범위 안에서는 초당 recover만큼 찬다")
	Fixtures.run(sim, 5.0)
	check_eq(sim.player.warmth, 30.0, "최대치까지만 찬다")
	check_eq(sim.agent_speed(sim.player), 5.0, "녹으면 원래 속도로 돌아온다")


func test_fire_upgrade_grows_warm_circle() -> void:
	var sim := _make_sim()
	var edge := Vector2(0, 4)
	check(not sim.is_warm(edge), "처음 모닥불 범위 밖은 춥다")
	sim.money = 10
	sim.player.pos = Vector2(-12, 5)
	Fixtures.run(sim, 1.5)
	check_eq(sim.heat_sources[0].radius, 5.0, "모닥불 키우기를 사면 반경이 다음 단계가 된다")
	check(sim.is_warm(edge), "커진 범위가 따뜻해진다")
	check_eq(sim.heat_sources.size(), 1, "열원은 모닥불 하나다")


func test_coat_slows_drain() -> void:
	var sim := _make_sim()
	sim.money = 10
	sim.player.pos = Vector2(15, 5)
	Fixtures.run(sim, 1.5)
	var before := sim.player.warmth
	Fixtures.run(sim, 10.0)
	check(is_equal_approx(before - sim.player.warmth, 5.0), "방한복을 입으면 덜 춥다 (%.2f)" % (before - sim.player.warmth))


func test_workers_never_freeze() -> void:
	var sim := _make_sim()
	sim._apply_effect({"hire": "porter"})
	var porter := sim.workers[0]
	porter.pos = OUTSIDE
	Fixtures.run(sim, 60.0)
	check_eq(porter.warmth, porter.max_warmth, "일꾼은 밖에 오래 있어도 얼지 않는다")
	check_eq(sim.agent_speed(porter), porter.speed, "일꾼은 늘 제 속도로 걷는다")


func _make_fuel_sim() -> FrostSim:
	var balance := Fixtures.balance()
	balance.cold.refuel_radius = 2.0
	balance.cold.sources.campfire.fuel_max = 10.0
	balance.cold.sources.campfire.per_log = 4.0
	balance.cold.sources.campfire.auto_level = 1
	return FrostSim.new(balance, Fixtures.layout())


## 모닥불 연료가 다 타면 꺼져서 따뜻하지 않다(5차 QA 7번).
func test_fire_burns_out() -> void:
	var sim := _make_fuel_sim()
	var outs := []
	sim.fire_out.connect(func(i: int) -> void: outs.append(i))
	sim.player.pos = OUTSIDE
	check(sim.is_warm(Vector2(1, 0)), "처음에는 연료가 가득하다")
	Fixtures.run(sim, 10.1)
	check(not sim.is_warm(Vector2(1, 0)), "연료가 떨어지면 꺼진다")
	check_eq(outs, [0], "꺼질 때 알린다")


func test_player_feeds_logs() -> void:
	var sim := _make_fuel_sim()
	sim.player.pos = OUTSIDE
	Fixtures.run(sim, 10.1)
	for i in 3:
		sim.player.stack.push("log")
	sim.player.pos = Vector2(1, 0)
	Fixtures.run(sim, 1.0)
	check_eq(sim.player.stack.items.count("log"), 1, "가득 찰 때까지만 넣는다(4씩, 최대 10)")
	check(sim.is_warm(Vector2(1, 0)), "다시 붙는다")


func test_fire_auto_feeds_from_woodpile_after_upgrade() -> void:
	var sim := _make_fuel_sim()
	sim.woodpile = 5
	sim.player.pos = OUTSIDE
	Fixtures.run(sim, 8.0)
	check_eq(sim.woodpile, 5, "키우기 전에는 적치장에서 저절로 채우지 않는다")
	sim._apply_effect({"fire": "campfire"})
	sim._apply_effect({"hire": "lumberjack"})
	Fixtures.run(sim, 1.0)
	check(sim.woodpile < 5, "키우고 벌목꾼이 있으면 적치장 원목으로 채운다")
	check(sim.heat_sources[0].fuel > 6.0, "연료가 다시 찬다")
