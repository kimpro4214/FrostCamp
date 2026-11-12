extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")

const MEAT_STALL := 1


func _make_sim() -> FrostSim:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim._apply_effect({"unlock": "habitat"})
	sim._apply_effect({"unlock": "meat_stall"})
	return sim


func test_hunter_hunts_bears_into_meat_pile() -> void:
	var sim := _make_sim()
	sim._apply_effect({"hire": "hunter"})
	check_eq(sim.workers[0].max_hp, 10.0, "사냥꾼은 체력이 있다")
	Fixtures.run_with_workers(sim, 40.0)
	check(sim.bears_killed >= 2, "서식지 곰을 잡는다 (%d)" % sim.bears_killed)
	check(sim.meat_pile >= 2, "고기를 고기 적치장에 쌓는다 (%d)" % sim.meat_pile)
	check(sim.player.stack.items.is_empty(), "플레이어는 아무것도 하지 않았다")


func test_porter_carries_meat_to_meat_stall() -> void:
	var sim := _make_sim()
	sim.meat_pile = 4
	sim._apply_effect({"hire": "porter"})
	Fixtures.run_with_workers(sim, 20.0)
	check_eq(sim.meat_pile, 0, "운반꾼이 고기 적치장을 비운다")
	var stall := sim.stalls[MEAT_STALL]
	check_eq(stall.stock + stall.served, 4, "고기 4개가 고기 판매대로 간다")


func test_porter_picks_fuller_pile() -> void:
	var sim := _make_sim()
	sim.woodpile = 2
	sim.meat_pile = 6
	var porter := Worker.new("porter", Vector2.ZERO, Fixtures.balance().workers.porter)
	sim.workers.append(porter)
	var target := WorkerBrain.choose(sim, porter)
	check_eq(porter.carry_item, "meat", "더 많이 쌓인 고기를 나르러 간다")
	check_eq(target.pos, sim.meat_pile_pos, "고기 적치장으로 간다")


func test_player_takes_from_meat_pile() -> void:
	var sim := _make_sim()
	sim.meat_pile = 3
	sim.player.pos = sim.meat_pile_pos
	Fixtures.run(sim, 1.0)
	check_eq(sim.player.stack.items.count("meat"), 3, "플레이어도 고기 적치장에서 집는다")


func test_meat_pile_closed_before_habitat() -> void:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim.meat_pile = 3
	sim.player.pos = sim.meat_pile_pos
	Fixtures.run(sim, 1.0)
	check_eq(sim.meat_pile, 3, "서식지를 열기 전에는 쓸 수 없다")
