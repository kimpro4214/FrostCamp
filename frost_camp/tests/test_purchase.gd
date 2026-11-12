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
