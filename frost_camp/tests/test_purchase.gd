extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim(money: int) -> FrostSim:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim.money = money
	return sim


func test_walking_across_zone_spends_nothing() -> void:
	var sim := _make_sim(100)
	sim.player.pos = Vector2(-2, 5)
	for i in 16:
		sim.player.pos.x += 0.25
		sim.tick(0.05)
	check_eq(sim.money, 100, "지나가다 밟은 존에는 돈이 들어가지 않는다")
	sim.player.pos = Vector2(0, 5)
	Fixtures.run(sim, 0.4)
	check_eq(sim.money, 100, "pay_delay 동안은 서 있어도 아직 내지 않는다")
	Fixtures.run(sim, 0.3)
	check(sim.money < 100, "pay_delay가 지나면 돈이 들어가기 시작한다")


func test_partial_payment_stays_after_leaving() -> void:
	var sim := _make_sim(12)
	sim.player.pos = Vector2(0, 5)
	Fixtures.run(sim, 3.0)
	var zone := sim.find_zone("backpack")
	check_eq(zone.paid, 12, "가진 돈만큼만 들어간다")
	check_eq(sim.money, 0, "지갑이 빈다")
	sim.player.pos = Vector2.ZERO
	Fixtures.run(sim, 1.0)
	check_eq(zone.paid, 12, "존을 떠나도 넣은 돈은 남는다")
	check_eq(zone.level, 0, "다 차지 않으면 레벨이 오르지 않는다")


func test_filling_zone_applies_upgrade() -> void:
	var sim := _make_sim(100)
	var purchased := []
	sim.zone_purchased.connect(func(id: String, level: int) -> void: purchased.append([id, level]))
	sim.player.pos = Vector2(0, 5)
	Fixtures.run(sim, 1.5)
	check_eq(sim.find_zone("backpack").level, 1, "다 차면 레벨이 오른다")
	check_eq(sim.player.stack.capacity, 14, "배낭 효과로 적재량이 는다")
	check_eq(purchased, [["backpack", 1]], "구매 이벤트가 한 번 나온다")
	check_eq(sim.money + sim.find_zone("backpack").paid, 80, "1레벨 가격만큼 빠지고 나머지는 다음 레벨에 들어간다")


func test_payment_carries_on_to_next_level() -> void:
	var sim := _make_sim(100)
	sim.player.pos = Vector2(0, 5)
	Fixtures.run(sim, 10.0)
	var zone := sim.find_zone("backpack")
	check_eq(zone.level, 2, "계속 서 있으면 다음 레벨까지 산다")
	check(zone.is_maxed(), "마지막 레벨을 사면 더는 살 수 없다")
	check_eq(sim.money, 40, "두 레벨 값만 빠진다")


func test_locked_zone_takes_no_money() -> void:
	var sim := _make_sim(100)
	sim.player.pos = Vector2(3, 5)
	Fixtures.run(sim, 3.0)
	check(not sim.is_zone_available(sim.find_zone("boots")), "선행 존을 사기 전에는 잠겨 있다")
	check_eq(sim.money, 100, "잠긴 존은 돈을 받지 않는다")


func test_speed_upgrade_changes_agent_speed() -> void:
	var sim := _make_sim(100)
	sim.find_zone("backpack").level = 1
	sim.player.pos = Vector2(3, 5)
	Fixtures.run(sim, 3.0)
	check_eq(sim.agent_speed(sim.player), 6.0, "장화를 사면 이동 속도가 오른다")


func test_axe_upgrade_fells_tree_faster() -> void:
	var sim := _make_sim(10)
	sim.player.pos = Vector2(-3, 5)
	Fixtures.run(sim, 2.0)
	sim.player.pos = Vector2(-9, 0)
	Fixtures.run(sim, 1.2)
	check_eq(sim.player.stack.items.size(), 2, "공격력 3이면 2타 만에 쓰러진다")


## 모닥불 단계가 붙은 선행 조건(4차 QA 10번). "fire:2"는 모닥불을 2단계 이상 키워야 한다.
func test_leveled_requirement_needs_fire_level() -> void:
	var balance := Fixtures.balance()
	balance.zones.fire.costs = [10, 10, 10]
	balance.zones.coat.requires = ["fire:2"]
	var sim := FrostSim.new(balance, Fixtures.layout())
	var coat := sim.find_zone("coat")
	check(not sim.is_zone_available(coat), "모닥불 0단계에서는 못 산다")
	check_eq(sim.fire_needed(coat), 2, "모닥불 2단계가 필요하다고 알려 준다")
	sim.find_zone("fire").level = 1
	check(not sim.is_zone_available(coat), "1단계로는 모자라다")
	sim.find_zone("fire").level = 2
	check(sim.is_zone_available(coat), "2단계면 살 수 있다")
	check_eq(sim.fire_needed(coat), 0, "다 채우면 안내가 사라진다")


func test_fire_hint_only_when_fire_is_the_last_gap() -> void:
	var balance := Fixtures.balance()
	balance.zones.coat.requires = ["habitat", "fire:1"]
	var sim := FrostSim.new(balance, Fixtures.layout())
	check_eq(sim.fire_needed(sim.find_zone("coat")), 0, "다른 선행 조건도 모자라면 숨긴다")
	sim.find_zone("habitat").level = 1
	check_eq(sim.fire_needed(sim.find_zone("coat")), 1, "모닥불만 남으면 안내한다")


## 한 단계를 산 뒤에는 repeat_delay를 더 기다려야 다음 단계에 돈이 들어간다(7차 QA 3번).
func test_repeat_delay_after_each_level() -> void:
	var balance := Fixtures.balance()
	balance.purchase.repeat_delay = 1.5
	var sim := FrostSim.new(balance, Fixtures.layout())
	sim.money = 100
	sim.player.pos = sim.find_zone("backpack").pos
	var t := 0.0
	while sim.find_zone("backpack").level == 0 and t < 5.0:
		sim.tick(0.05)
		t += 0.05
	check_eq(sim.find_zone("backpack").level, 1, "첫 단계를 산다")
	var money_after := sim.money
	Fixtures.run(sim, 1.5)
	check_eq(sim.money, money_after, "산 뒤 pay_delay + repeat_delay 동안은 돈이 나가지 않는다")
	Fixtures.run(sim, 0.8)
	check(sim.money < money_after, "그 뒤에는 다음 단계에 돈이 들어간다")
