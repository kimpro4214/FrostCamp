extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim() -> FrostSim:
	return FrostSim.new(Fixtures.balance(), Fixtures.layout())


func _expansion_tree(sim: FrostSim) -> HarvestTree:
	for tree in sim.trees:
		if tree.unlock == "expand_1":
			return tree
	return null


func test_expansion_trees_come_from_region() -> void:
	var sim := _make_sim()
	var tree := _expansion_tree(sim)
	check(tree != null, "확장 땅의 나무가 숲에 들어간다")
	check_eq(tree.pos, Vector2(-15, 15), "지역에 적힌 자리에 선다")
	check(sim.regions.expand_1.open, "확장 땅은 열리는 지역이다")
	check(not sim.regions.habitat.open, "서식지는 열리는 지역이 아니다")


func test_locked_expansion_tree_cannot_be_chopped() -> void:
	var sim := _make_sim()
	var tree := _expansion_tree(sim)
	sim.player.pos = tree.pos + Vector2(1, 0)
	Fixtures.run(sim, 3.0)
	check(sim.player.stack.items.is_empty(), "땅을 사기 전에는 벨 수 없다")
	check(not sim.is_tree_ready(tree), "준비되지 않은 나무로 친다")


func test_buying_expansion_opens_its_trees() -> void:
	var sim := _make_sim()
	var tree := _expansion_tree(sim)
	sim._apply_effect({"unlock": "expand_1"})
	sim.player.pos = tree.pos + Vector2(1, 0)
	Fixtures.run(sim, 3.0)
	check(sim.player.stack.items.size() > 0, "땅을 사면 그 숲을 벨 수 있다")


func test_lumberjack_skips_locked_trees() -> void:
	var sim := _make_sim()
	sim._apply_effect({"hire": "lumberjack"})
	var worker := sim.workers[0]
	worker.pos = _expansion_tree(sim).pos
	var target := WorkerBrain.choose(sim, worker)
	check_eq(target.pos, Vector2(-10, 0), "벌목꾼은 안 산 땅의 나무 대신 열린 나무로 간다")
