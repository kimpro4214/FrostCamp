extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func test_bot_earns_and_buys_first_zone() -> void:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	var bot := GreedyBot.new(sim)
	while bot.time < 120.0 and bot.purchases.is_empty():
		bot.step(0.05)
	check(not bot.purchases.is_empty(), "2분 안에 첫 존을 산다")
	check(sim.stalls[0].served > 0, "원목을 팔아서 번 돈으로 산다")
