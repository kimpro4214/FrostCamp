extends "res://frost_camp/tests/test_case.gd"
## 플레이어만 얻는 고급 자원(5차 QA 8번): 황금 연어와 빛나는 빙결정(보석).

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim(gold_chance: float = 1.0) -> FrostSim:
	var balance := Fixtures.balance()
	balance.items.salmon = {"price": 9}
	balance.items.crystal = {"price": 30}
	balance.items.gold_salmon = {"price": 60, "sold_at": "salmon"}
	balance.items.gem = {"price": 120, "sold_at": "crystal"}
	balance.premium = {"gold_salmon_chance": gold_chance, "glow_interval": 5.0}
	var layout := Fixtures.layout()
	layout.stalls.append({"item": "salmon", "pos": [10, 6], "cash_pos": [10, 9], "repair_pos": [7, 6]})
	var sim := FrostSim.new(balance, layout)
	sim._apply_effect({"unlock": "fish_stall"})
	sim._apply_effect({"unlock": "expand_1"})
	return sim


func test_player_catches_gold_salmon_but_fisher_never() -> void:
	var sim := _make_sim(1.0)
	sim.player.pos = sim.fishing_holes[0]
	Fixtures.run(sim, 1.05)
	check_eq(sim.player.stack.items.count("gold_salmon"), 1, "플레이어는 황금 연어를 낚는다")
	sim._apply_effect({"hire": "fisher"})
	var fisher := sim.workers[0]
	fisher.pos = sim.fishing_holes[1]
	Fixtures.run(sim, 1.05)
	check_eq(fisher.stack.items.count("gold_salmon"), 0, "낚시꾼은 황금 연어를 못 잡는다")
	check_eq(fisher.stack.items.count("salmon"), 1, "낚시꾼은 보통 연어를 잡는다")


func test_salmon_stall_buys_gold_salmon_at_once() -> void:
	var sim := _make_sim()
	var stall: Stall = sim.stalls[2]
	sim.player.stack.push("gold_salmon")
	sim.player.pos = stall.pos
	Fixtures.run(sim, 0.05)
	check_eq(stall.cash, 60, "줄과 상관없이 바로 사 간다")
	check(not sim.player.stack.items.has("gold_salmon"), "등에서 빠진다")


func test_glowing_crystal_only_for_player() -> void:
	var sim := _make_sim()
	var glowed := []
	sim.crystal_glowed.connect(func(i: int) -> void: glowed.append(i))
	Fixtures.run(sim, 5.1)
	check_eq(glowed.size(), 1, "glow_interval마다 하나가 빛난다")
	var rock: HarvestTree = sim.trees[glowed[0]]
	check(rock.glowing, "빛나는 바위")
	sim._apply_effect({"hire": "miner"})
	var miner := sim.workers[0]
	miner.pos = rock.pos
	check(WorkerBrain.choose(sim, miner).pos != rock.pos, "광부는 빛나는 바위를 고르지 않는다")
	Fixtures.run(sim, 0.05)
	check_eq(rock.hits, 0, "광부는 빛나는 바위를 치지 않는다")
	sim.workers.clear()
	sim.player.pos = rock.pos + Vector2(1, 0)
	Fixtures.run(sim, 2.2)
	check_eq(sim.player.stack.items.count("gem"), 1, "플레이어가 캐면 보석 하나")
	check(not rock.glowing, "캐면 빛이 꺼진다")
