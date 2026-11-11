extends "res://frost_camp/tests/test_case.gd"


func test_loads_balance_file() -> void:
	var data := GameData.load_json(GameData.BALANCE_PATH)
	check(not data.is_empty(), "balance.json을 읽어야 한다")
	for key in ["player", "interact", "tree", "items", "stall"]:
		check(data.has(key), "balance.json에 %s 섹션이 있어야 한다" % key)


func test_loads_layout_file() -> void:
	var data := GameData.load_json(GameData.LAYOUT_PATH)
	for key in ["player_start", "trees", "stalls"]:
		check(data.has(key), "layout.json에 %s 항목이 있어야 한다" % key)
