extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim() -> FrostSim:
	return FrostSim.new(Fixtures.balance(), Fixtures.layout())


func test_standing_near_tree_fills_stack() -> void:
	var sim := _make_sim()
	sim.player.pos = Vector2(-9, 0)
	Fixtures.run(sim, 1.8)
	check_eq(sim.player.stack.items.size(), 2, "3타면 원목 2개를 얻는다")
	check(not sim.trees[0].is_standing(), "나무가 쓰러진다")


func test_does_not_chop_without_room_for_drop() -> void:
	var sim := _make_sim()
	sim.player.pos = Vector2(-9, 0)
	for i in 9:
		sim.player.stack.push("log")
	Fixtures.run(sim, 3.0)
	check_eq(sim.trees[0].hits, 0, "원목이 들어갈 자리가 없으면 치지 않는다")


func test_far_from_everything_does_nothing() -> void:
	var sim := _make_sim()
	Fixtures.run(sim, 3.0)
	check_eq(sim.trees[0].hits, 0, "멀리 있으면 나무를 치지 않는다")


func test_full_loop_chop_sell_collect() -> void:
	var sim := _make_sim()
	sim.player.pos = Vector2(-9, 0)
	Fixtures.run(sim, 1.8)
	sim.player.pos = Vector2(9, 0)
	Fixtures.run(sim, 0.5)
	check(sim.player.stack.items.is_empty(), "판매대 근처에서 스택이 비워진다")
	Fixtures.run(sim, 2.0)
	check_eq(sim.stalls[0].cash, 10, "손님이 원목 2개를 사 간다")
	check_eq(sim.money, 0, "돈은 주워야 지갑에 들어온다")
	sim.player.pos = Vector2(10, 3)
	sim.tick(0.05)
	check_eq(sim.money, 10, "돈 더미에 서면 돈을 줍는다")
	check_eq(sim.stalls[0].cash, 0, "주운 돈은 더미에서 사라진다")
