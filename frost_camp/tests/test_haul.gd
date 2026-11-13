extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")

const MEAT_STALL := 1


func _make_sim() -> FrostSim:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim._apply_effect({"unlock": "habitat"})
	sim._apply_effect({"unlock": "meat_stall"})
	return sim


func test_level_one_hires_line_porter() -> void:
	var sim := _make_sim()
	sim._apply_effect({"haul": "meat"})
	check_eq(sim.workers.size(), 1, "1단계는 운반꾼을 고용한다")
	check_eq(sim.workers[0].line, "meat", "고기 라인 전담이다")
	sim.woodpile = 6
	sim.meat_pile = 3
	Fixtures.run_with_workers(sim, 20.0)
	check_eq(sim.meat_pile, 0, "고기 적치장을 비운다")
	check_eq(sim.woodpile, 6, "원목이 더 많이 쌓여 있어도 원목은 나르지 않는다")
	check_eq(sim.conveyors.meat.level, 0, "아직 컨베이어는 없다")


func test_level_two_retires_porter_and_lays_conveyor() -> void:
	var sim := _make_sim()
	var retired := []
	sim.worker_retired.connect(func(i: int) -> void: retired.append(i))
	sim._apply_effect({"haul": "meat"})
	sim._apply_effect({"haul": "meat"})
	check(sim.workers[0].retired, "2단계에서 운반꾼이 물러난다")
	check_eq(retired, [0], "물러남 이벤트가 나온다")
	check_eq(sim.conveyors.meat.level, 1, "컨베이어가 깔린다")
	sim.meat_pile = 3
	Fixtures.run_with_workers(sim, 20.0)
	var stall := sim.stalls[MEAT_STALL]
	check_eq(stall.stock + stall.served, 3, "컨베이어가 고기를 판매대로 나른다")
	check(sim.workers[0].stack.items.is_empty(), "물러난 운반꾼은 아무것도 나르지 않는다")


func test_level_three_speeds_up_conveyor() -> void:
	var sim := _make_sim()
	for i in 3:
		sim._apply_effect({"haul": "meat"})
	check_eq(sim.conveyors.meat.level, 2, "3단계는 컨베이어가 빨라진다")
	check_eq(sim.conveyors.meat.speed(), 4.0, "2레벨 속도")


func test_lines_break_independently() -> void:
	var sim := _make_sim()
	sim._apply_effect({"haul": "meat"})
	sim._apply_effect({"haul": "meat"})
	sim._apply_effect({"conveyor": "log"})
	var meat_belt := sim.structures.find(sim.conveyors.meat.structure)
	sim.damage_structure(meat_belt, 10)
	check(sim.conveyors.meat.structure.is_broken(), "고기 컨베이어만 부서진다")
	check(not sim.conveyors.log.structure.is_broken(), "원목 컨베이어는 멀쩡하다")
	sim.woodpile = 2
	Fixtures.run(sim, 10.0)
	check_eq(sim.woodpile, 0, "다른 라인은 계속 나른다")
