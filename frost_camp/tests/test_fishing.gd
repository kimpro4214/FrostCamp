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
	sim.workers[0].target = WorkerBrain.choose(sim, sim.workers[0])
	check_eq(WorkerBrain.choose(sim, sim.workers[1]).pos, sim.fishing_holes[1], "두 번째 낚시꾼은 다른 구멍으로 간다")
	Fixtures.run_with_workers(sim, 20.0)
	check(sim.pile_count("salmon") >= 4, "낚시꾼이 연어 적치장을 채운다 (%d)" % sim.pile_count("salmon"))


func test_player_takes_from_salmon_pile() -> void:
	var sim := _make_sim()
	sim.extra_piles.salmon.count = 3
	sim.player.pos = sim.pile_pos("salmon")
	Fixtures.run(sim, 1.0)
	check_eq(sim.player.stack.items.count("salmon"), 3, "플레이어도 연어 적치장에서 집는다")


## 구멍은 사서 뚫는다(4차 QA 4번). 안 뚫린 구멍에서는 낚이지 않는다.
func test_holes_open_only_after_drilling() -> void:
	var layout := Fixtures.layout()
	layout.holes_open = 0
	var sim := FrostSim.new(Fixtures.balance(), layout)
	sim._apply_effect({"unlock": "fish_stall"})
	sim.player.pos = sim.fishing_holes[0]
	Fixtures.run(sim, 2.1)
	check_eq(sim.player.stack.items.count("salmon"), 0, "뚫기 전에는 낚이지 않는다")
	var drilled := []
	sim.hole_drilled.connect(func(hole: int) -> void: drilled.append(hole))
	sim._apply_effect({"holes": 1})
	check_eq(drilled, [0], "첫 구멍이 뚫린다")
	Fixtures.run(sim, 2.1)
	check_eq(sim.player.stack.items.count("salmon"), 2, "뚫은 구멍에서는 낚인다")
	sim.player.stack.items.clear()
	sim.player.pos = sim.fishing_holes[1]
	Fixtures.run(sim, 2.1)
	check_eq(sim.player.stack.items.count("salmon"), 0, "둘째 구멍은 아직 막혀 있다")


func test_fishers_share_open_holes() -> void:
	var layout := Fixtures.layout()
	layout.holes_open = 1
	var sim := FrostSim.new(Fixtures.balance(), layout)
	sim._apply_effect({"unlock": "fish_stall"})
	sim._apply_effect({"hire": "fisher"})
	sim._apply_effect({"hire": "fisher"})
	check_eq(WorkerBrain.choose(sim, sim.workers[1]).pos, sim.fishing_holes[0], "뚫린 구멍이 하나면 둘 다 그 구멍으로 간다")


## 한 구멍에서는 먼저 선 한 사람만 낚는다(5차 QA 2번).
func test_one_person_per_hole() -> void:
	var layout := Fixtures.layout()
	layout.holes_open = 1
	var sim := FrostSim.new(Fixtures.balance(), layout)
	sim._apply_effect({"unlock": "fish_stall"})
	sim._apply_effect({"hire": "fisher"})
	var fisher := sim.workers[0]
	fisher.pos = sim.fishing_holes[0]
	sim.player.pos = sim.fishing_holes[0] + Vector2(0.3, 0)
	Fixtures.run(sim, 0.05)
	var first: SimAgent = sim.hole_users[0]
	Fixtures.run(sim, 2.1)
	var other: SimAgent = sim.player if first == fisher else fisher
	check(first != null, "누군가 구멍을 차지한다")
	check_eq(other.stack.items.count("salmon"), 0, "다른 사람은 같은 구멍에서 낚지 못한다")
	check_eq(first.stack.items.count("salmon"), 2, "차지한 사람만 낚는다")


func test_fisher_skips_busy_hole_and_waits() -> void:
	var layout := Fixtures.layout()
	layout.holes_open = 1
	var sim := FrostSim.new(Fixtures.balance(), layout)
	sim._apply_effect({"unlock": "fish_stall"})
	sim.player.pos = sim.fishing_holes[0]
	Fixtures.run(sim, 0.05)
	sim._apply_effect({"hire": "fisher"})
	var goal := WorkerBrain.choose(sim, sim.workers[0])
	check_eq(goal.kind, "idle", "빈 구멍이 없으면 기다린다")
	sim.holes_open = 2
	goal = WorkerBrain.choose(sim, sim.workers[0])
	check_eq(goal.pos, sim.fishing_holes[1], "구멍이 늘면 빈 구멍으로 간다")
