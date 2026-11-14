extends "res://frost_camp/tests/test_case.gd"
## 다음 목표 안내(8차 QA 다음 개발): 살 수 있는 존 중 남은 금액이 가장 적은 것, 선택 존은 뺀다.

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim() -> FrostSim:
	var balance := Fixtures.balance()
	balance.zones.merc = {"costs": [1], "effect": {"hire": "merc"}, "optional": true}
	balance.workers.merc = {"speed": 3.0, "hp": 6}
	var layout := Fixtures.layout()
	layout.zones.merc = [-15, 8]
	return FrostSim.new(balance, layout)


func test_goal_is_cheapest_available_zone() -> void:
	var sim := _make_sim()
	sim.find_zone("axe").paid = 9
	check_eq(sim.next_goal().id, "axe", "남은 금액이 가장 적은 존")


func test_goal_skips_optional_and_locked() -> void:
	var sim := _make_sim()
	var goal := sim.next_goal()
	check(goal.id != "merc", "레이드용 선택 존은 고르지 않는다")
	check(goal.id != "boots", "선행 조건을 못 갖춘 존은 고르지 않는다")
	for zone in sim.zones:
		if zone.optional or not sim.is_zone_available(zone):
			continue
		check(goal.remaining() <= zone.remaining(), "%s보다 비싸지 않다" % zone.id)


func test_no_goal_when_everything_bought() -> void:
	var sim := _make_sim()
	for zone in sim.zones:
		if not zone.optional:
			zone.level = zone.costs.size()
	check(sim.next_goal() == null, "다 사면 목표가 없다")
