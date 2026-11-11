extends "res://frost_camp/tests/test_case.gd"


func test_loads_balance_file() -> void:
	var data := Balance.load_file()
	check(not data.is_empty(), "balance.json을 읽어야 한다")
	for key in ["player", "tree", "items", "stall"]:
		check(data.has(key), "balance.json에 %s 섹션이 있어야 한다" % key)
