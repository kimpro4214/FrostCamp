extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func test_locked_stall_has_no_customers_and_takes_nothing() -> void:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim.player.stack.push("meat")
	sim.player.pos = Vector2(9, -8)
	Fixtures.run(sim, 3.0)
	check(not sim.is_stall_open(sim.stalls[1]), "해금 전에는 닫혀 있다")
	check(sim.stalls[1].queue == 0, "닫힌 판매대에는 손님이 오지 않는다")
	check_eq(sim.player.stack.items.size(), 1, "닫힌 판매대에는 내려놓지 않는다")


func test_buying_unlock_opens_stall() -> void:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim.money = 10
	sim.player.pos = Vector2(6, 5)
	Fixtures.run(sim, 1.5)
	check(sim.unlocked.has("meat_stall"), "구매하면 해금된다")
	sim.player.stack.push("meat")
	sim.player.pos = Vector2(9, -8)
	Fixtures.run(sim, 3.0)
	check(sim.player.stack.items.is_empty(), "열린 판매대에는 고기를 내려놓는다")
	check_eq(sim.stalls[1].cash, 15, "손님이 고기를 사 간다")
