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


## 판매대마다 그 판매대를 맡는 계산원 고용 존이 있어야 한다(4차 QA 3번).
func test_every_stall_has_cashier_zone() -> void:
	var balance := GameData.load_json(GameData.BALANCE_PATH)
	var layout := GameData.load_json(GameData.LAYOUT_PATH)
	var covered := {}
	for id in balance.zones:
		var effect: Dictionary = balance.zones[id].effect
		if effect.get("hire", "") == "cashier":
			covered[int(effect.get("stall", -1))] = true
	for i in layout.stalls.size():
		check(covered.has(i), "판매대 %d(%s)에 계산원 존이 있다" % [i, layout.stalls[i].item])


## 빙결정은 남동쪽 장터에서만 판다(4차 QA 1번).
func test_crystal_sold_only_at_market() -> void:
	var layout := GameData.load_json(GameData.LAYOUT_PATH)
	var crystal_stalls: Array = layout.stalls.filter(func(s: Dictionary) -> bool: return s.item == "crystal")
	check_eq(crystal_stalls.size(), 1, "빙결정 판매대는 하나다")
	check_eq(crystal_stalls[0].get("unlock", ""), "expand_2", "장터 땅을 사야 열린다")
	check_eq(int(layout.conveyors.crystal.stall), layout.stalls.find(crystal_stalls[0]), "빙결정 컨베이어는 장터로 간다")
