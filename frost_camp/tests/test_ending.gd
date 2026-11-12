extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim() -> FrostSim:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim.player.pos = Vector2(0, 15)
	return sim


func test_buying_all_ship_parts_wins_once() -> void:
	var sim := _make_sim()
	var wins := [0]
	sim.game_won.connect(func() -> void: wins[0] += 1)
	sim.money = 20
	sim.player.pos = Vector2(20, 0)
	Fixtures.run(sim, 1.5)
	check(not sim.won, "부품 하나로는 끝나지 않는다")
	sim.player.pos = Vector2(23, 0)
	Fixtures.run(sim, 1.5)
	check(sim.won, "부품을 모두 사면 엔딩")
	check_eq(wins[0], 1, "엔딩 이벤트는 한 번만 나온다")


func test_time_stops_at_ending() -> void:
	var sim := _make_sim()
	Fixtures.run(sim, 2.0)
	sim._apply_effect({"unlock": "ship_hull"})
	sim._apply_effect({"unlock": "ship_mast"})
	var ended_at := sim.time
	Fixtures.run(sim, 5.0)
	check(is_equal_approx(ended_at, 2.0), "플레이 시간이 쌓인다 (%.2f)" % ended_at)
	check_eq(sim.time, ended_at, "엔딩 뒤에는 시간이 멈춘다")


func test_total_earned_counts_collected_cash() -> void:
	var sim := _make_sim()
	sim.stalls[0].cash = 25
	sim.player.pos = Vector2(10, 3)
	sim.tick(0.05)
	sim.money -= 20
	check_eq(sim.total_earned, 25, "주운 돈은 써도 번 돈 기록에 남는다")
