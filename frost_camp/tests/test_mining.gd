extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim() -> FrostSim:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim._apply_effect({"unlock": "expand_1"})
	return sim


func _crystal(sim: FrostSim) -> HarvestTree:
	for tree in sim.trees:
		if tree.item == "crystal":
			return tree
	return null


func test_crystals_come_from_region() -> void:
	var sim := _make_sim()
	var crystal := _crystal(sim)
	check(crystal != null, "확장 땅에 빙결정 바위가 있다")
	check_eq(crystal.unlock, "expand_1", "그 땅을 사야 캘 수 있다")
	check_eq(crystal.hits_to_fell, 4, "빙결정은 더 단단하다")


func test_mining_crystal_gives_crystals() -> void:
	var sim := _make_sim()
	var crystal := _crystal(sim)
	sim.player.pos = crystal.pos + Vector2(1, 0)
	Fixtures.run(sim, 2.2)
	check_eq(sim.player.stack.items.count("crystal"), 2, "다 캐면 빙결정 2개")
	check_eq(sim.player.stack.items.count("log"), 0, "원목은 나오지 않는다")


func test_lumberjack_ignores_crystals_and_miner_fills_pile() -> void:
	var sim := _make_sim()
	sim._apply_effect({"hire": "lumberjack"})
	var lumberjack := sim.workers[0]
	lumberjack.pos = _crystal(sim).pos
	check_eq(WorkerBrain.choose(sim, lumberjack).pos, Vector2(-15, 15), "벌목꾼은 바위 대신 가까운 나무로 간다")
	sim.workers.clear()
	sim._apply_effect({"hire": "miner"})
	Fixtures.run_with_workers(sim, 25.0)
	check(sim.pile_count("crystal") >= 2, "광부가 빙결정 적치장을 채운다 (%d)" % sim.pile_count("crystal"))
	check_eq(sim.woodpile, 0, "광부는 원목을 캐지 않는다")


## 광부 둘이 같은 바위에 몰리지 않는다(4차 QA 2번).
func test_two_miners_pick_different_crystals() -> void:
	var sim := _make_sim()
	sim._apply_effect({"hire": "miner"})
	sim._apply_effect({"hire": "miner"})
	for worker in sim.workers:
		worker.target = WorkerBrain.choose(sim, worker)
	var first := WorkerBrain.choose(sim, sim.workers[0])
	var second := WorkerBrain.choose(sim, sim.workers[1])
	check_eq(first.kind, "tree", "첫 광부는 바위로 간다")
	check_eq(second.kind, "tree", "둘째 광부도 바위로 간다")
	check(first.pos != second.pos, "서로 다른 바위를 고른다")
