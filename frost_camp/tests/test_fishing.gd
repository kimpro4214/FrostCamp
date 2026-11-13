extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim() -> FrostSim:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim._apply_effect({"unlock": "fish_stall"})
	return sim


func test_standing_on_hole_catches_salmon() -> void:
	var sim := _make_sim()
	var caught := []
	sim.fish_caught.connect(func(hole: int, _a: SimAgent) -> void: caught.append(hole))
	sim.player.pos = sim.fishing_holes[0]
	Fixtures.run(sim, 3.1)
	check_eq(sim.player.stack.items.count("salmon"), 3, "catch_interval마다 연어 한 마리")
	check_eq(caught, [0, 0, 0], "잡을 때마다 이벤트가 나온다")


func test_moving_off_hole_resets_progress() -> void:
	var sim := _make_sim()
	sim.player.pos = sim.fishing_holes[0]
	Fixtures.run(sim, 0.8)
	sim.player.pos = Vector2.ZERO
	Fixtures.run(sim, 0.5)
	sim.player.pos = sim.fishing_holes[0]
	Fixtures.run(sim, 0.8)
	check_eq(sim.player.stack.items.count("salmon"), 0, "구멍을 떠나면 처음부터 다시 기다린다")


func test_full_stack_stops_fishing() -> void:
	var sim := _make_sim()
	for i in 10:
		sim.player.stack.push("log")
	sim.player.pos = sim.fishing_holes[0]
	Fixtures.run(sim, 3.0)
	check_eq(sim.player.stack.items.count("salmon"), 0, "등이 차면 낚지 않는다")


func test_fisher_fills_salmon_pile() -> void:
	var sim := _make_sim()
	sim._apply_effect({"hire": "fisher"})
	sim._apply_effect({"hire": "fisher"})
	check_eq(WorkerBrain.choose(sim, sim.workers[1]).pos, sim.fishing_holes[1], "두 번째 낚시꾼은 다른 구멍으로 간다")
	Fixtures.run_with_workers(sim, 20.0)
	check(sim.pile_count("salmon") >= 4, "낚시꾼이 연어 적치장을 채운다 (%d)" % sim.pile_count("salmon"))


func test_player_takes_from_salmon_pile() -> void:
	var sim := _make_sim()
	sim.extra_piles.salmon.count = 3
	sim.player.pos = sim.pile_pos("salmon")
	Fixtures.run(sim, 1.0)
	check_eq(sim.player.stack.items.count("salmon"), 3, "플레이어도 연어 적치장에서 집는다")
