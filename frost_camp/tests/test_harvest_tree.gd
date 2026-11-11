extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func test_falls_after_required_hits() -> void:
	var tree := HarvestTree.new(Vector2.ZERO, Fixtures.balance().tree)
	check(not tree.hit(), "1타에는 안 쓰러진다")
	check(not tree.hit(), "2타에는 안 쓰러진다")
	check(tree.hit(), "3타에 쓰러진다")
	check(not tree.is_standing(), "쓰러진 뒤에는 서 있지 않다")


func test_regrows_after_respawn_time() -> void:
	var tree := HarvestTree.new(Vector2.ZERO, Fixtures.balance().tree)
	for i in 3:
		tree.hit()
	tree.tick(7.9)
	check(not tree.is_standing(), "리스폰 시간 전에는 다시 자라지 않는다")
	tree.tick(0.2)
	check(tree.is_standing(), "리스폰 시간이 지나면 다시 선다")
