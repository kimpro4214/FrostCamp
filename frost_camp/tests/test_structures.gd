extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")

const LOG_STALL := 0
const WOODPILE := 2


func _make_sim() -> FrostSim:
	return FrostSim.new(Fixtures.balance(), Fixtures.layout())


func test_hits_reduce_hp_and_break_at_zero() -> void:
	var sim := _make_sim()
	var broken := []
	sim.structure_broken.connect(func(i: int) -> void: broken.append(i))
	sim.damage_structure(LOG_STALL, 4)
	check_eq(sim.structures[LOG_STALL].hp, 6, "맞은 만큼 체력이 준다")
	sim.damage_structure(LOG_STALL, 9)
	check_eq(sim.structures[LOG_STALL].hp, 0, "체력은 0 밑으로 내려가지 않는다")
	check(sim.structures[LOG_STALL].is_broken(), "체력 0이면 부서진다")
	check_eq(broken, [LOG_STALL], "부서짐 이벤트가 한 번 나온다")
	sim.damage_structure(LOG_STALL, 3)
	check_eq(broken, [LOG_STALL], "부서진 시설은 더 맞지 않는다")


func test_broken_stall_stops_selling_and_taking() -> void:
	var sim := _make_sim()
	var stall := sim.stalls[LOG_STALL]
	stall.stock = 3
	sim.damage_structure(LOG_STALL, 10)
	sim.player.stack.push("log")
	sim.player.pos = stall.pos + Vector2(-1, 0)
	Fixtures.run(sim, 3.0)
	check_eq(stall.stock, 3, "부서진 판매대는 팔지 않는다")
	check_eq(sim.player.stack.items.size(), 1, "부서진 판매대에는 내려놓지 않는다")


func test_broken_woodpile_blocks_pickup() -> void:
	var sim := _make_sim()
	sim.woodpile = 3
	sim.damage_structure(WOODPILE, 10)
	sim.player.pos = sim.woodpile_pos
	Fixtures.run(sim, 1.0)
	check_eq(sim.woodpile, 3, "부서진 적치장에서는 집을 수 없다")


func test_paying_repair_zone_restores_structure() -> void:
	var sim := _make_sim()
	var repaired := []
	sim.structure_repaired.connect(func(i: int) -> void: repaired.append(i))
	sim.damage_structure(LOG_STALL, 10)
	sim.money = 100
	sim.player.pos = sim.structures[LOG_STALL].repair.pos
	Fixtures.run(sim, 2.0)
	check(not sim.structures[LOG_STALL].is_broken(), "수리를 마치면 다시 작동한다")
	check_eq(sim.structures[LOG_STALL].hp, 10, "체력이 가득 찬다")
	check_eq(sim.money, 80, "수리비만큼 돈이 빠진다")
	check_eq(repaired, [LOG_STALL], "수리 완료 이벤트가 나온다")


func test_partial_repair_stays_after_leaving() -> void:
	var sim := _make_sim()
	var structure := sim.structures[LOG_STALL]
	sim.damage_structure(LOG_STALL, 10)
	sim.money = 100
	sim.player.pos = structure.repair.pos
	Fixtures.run(sim, 0.8)
	sim.player.pos = Vector2.ZERO
	Fixtures.run(sim, 1.0)
	var paid := structure.repair.paid
	check(paid > 0 and structure.is_broken(), "덜 낸 수리비는 떠나도 남는다 (%d)" % paid)
	sim.player.pos = structure.repair.pos
	Fixtures.run(sim, 2.0)
	check(not structure.is_broken(), "돌아와서 마저 내면 고쳐진다")
	check_eq(sim.money, 80, "수리비는 한 번만 낸다")


func test_healthy_structure_repair_zone_takes_nothing() -> void:
	var sim := _make_sim()
	sim.money = 100
	sim.player.pos = sim.structures[LOG_STALL].repair.pos
	Fixtures.run(sim, 2.0)
	check_eq(sim.money, 100, "멀쩡한 시설의 수리 존은 돈을 받지 않는다")
