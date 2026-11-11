extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func test_bot_earns_and_buys_first_zone() -> void:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	var bot := GreedyBot.new(sim)
	while bot.time < 120.0 and bot.purchases.is_empty():
		bot.step(0.05)
	check(not bot.purchases.is_empty(), "2분 안에 첫 존을 산다")
	check(sim.stalls[0].served > 0, "원목을 팔아서 번 돈으로 산다")


func test_bot_hunts_after_meat_stall_opens() -> void:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim.unlocked["habitat"] = true
	sim.unlocked["meat_stall"] = true
	var bot := GreedyBot.new(sim)
	while bot.time < 90.0 and sim.stalls[1].served == 0:
		bot.step(0.05)
	check(sim.bears_killed > 0, "고기 판매대가 열리면 곰을 사냥한다")
	check(sim.stalls[1].served > 0, "잡은 고기를 판다")
