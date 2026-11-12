extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")

const LOG_STALL := 0
const CONVEYOR := 4


func _make_sim() -> FrostSim:
	return FrostSim.new(Fixtures.balance(), Fixtures.layout())


func _buy(sim: FrostSim) -> void:
	sim._apply_effect({"conveyor": "log"})


func test_idle_before_purchase() -> void:
	var sim := _make_sim()
	sim.woodpile = 5
	Fixtures.run(sim, 3.0)
	check_eq(sim.woodpile, 5, "사기 전에는 적치장에서 가져가지 않는다")


func test_carries_woodpile_logs_to_log_stall() -> void:
	var sim := _make_sim()
	_buy(sim)
	sim.woodpile = 3
	Fixtures.run(sim, 10.0)
	check_eq(sim.woodpile, 0, "적치장 원목을 싣는다")
	var stall := sim.stalls[LOG_STALL]
	check_eq(stall.stock + stall.served, 3, "원목 판매대까지 실어 나른다")
	check(sim.conveyor.items.is_empty(), "벨트 위에 남은 원목이 없다")


func test_logs_keep_spacing() -> void:
	var sim := _make_sim()
	_buy(sim)
	sim.woodpile = 20
	Fixtures.run(sim, 3.0)
	var items := sim.conveyor.items
	check(items.size() >= 3, "여러 개가 함께 흐른다 (%d)" % items.size())
	for i in range(1, items.size()):
		check(items[i - 1] - items[i] >= 0.999, "앞 원목과 spacing 이상 떨어진다")


func test_broken_conveyor_stops() -> void:
	var sim := _make_sim()
	_buy(sim)
	sim.woodpile = 10
	Fixtures.run(sim, 2.0)
	sim.damage_structure(CONVEYOR, 10)
	var woodpile := sim.woodpile
	var front := sim.conveyor.items[0]
	Fixtures.run(sim, 3.0)
	check_eq(sim.woodpile, woodpile, "부서지면 더 싣지 않는다")
	check_eq(sim.conveyor.items[0], front, "실려 있던 원목은 그 자리에 멈춘다")


func test_logs_wait_at_end_when_stall_broken() -> void:
	var sim := _make_sim()
	_buy(sim)
	sim.damage_structure(LOG_STALL, 10)
	sim.woodpile = 3
	Fixtures.run(sim, 15.0)
	check_eq(sim.stalls[LOG_STALL].stock, 0, "부서진 판매대는 받지 않는다")
	check_eq(sim.conveyor.items.size(), 3, "끝에서 줄지어 기다린다")
	check_eq(sim.conveyor.items[0], sim.conveyor.length, "맨 앞 원목은 끝에 있다")


func test_upgrade_speeds_up_belt() -> void:
	var sim := _make_sim()
	_buy(sim)
	check_eq(sim.conveyor.speed(), 2.0, "1레벨 속도")
	_buy(sim)
	check_eq(sim.conveyor.speed(), 4.0, "2레벨은 더 빠르다")
	check_eq(sim.conveyor.take_interval(), 0.25, "더 자주 싣는다")
