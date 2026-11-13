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
