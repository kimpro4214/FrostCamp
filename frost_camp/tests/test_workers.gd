extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")
const IDLE_SPOT := Vector2(0, 15)


func _make_sim() -> FrostSim:
	var sim := FrostSim.new(Fixtures.balance(), Fixtures.layout())
	sim.player.pos = IDLE_SPOT
	return sim


func _hire(sim: FrostSim, role: String) -> Worker:
	sim._apply_effect({"hire": role})
	return sim.workers[-1]


func test_buying_hire_zone_adds_worker_at_spawn() -> void:
	var sim := _make_sim()
	var hired := []
	sim.worker_hired.connect(func(index: int) -> void: hired.append(index))
	sim.money = 10
	sim.player.pos = Vector2(-6, 5)
	Fixtures.run(sim, 1.5)
	check_eq(sim.workers.size(), 1, "고용 존을 사면 일꾼이 생긴다")
	check_eq(sim.workers[0].role, "lumberjack", "존에 맞는 역할")
	check_eq(sim.workers[0].pos, Vector2(0, -2), "스폰 지점에서 나타난다")
	check_eq(hired, [0], "고용 이벤트가 나온다")


func test_lumberjack_fills_woodpile() -> void:
	var sim := _make_sim()
	_hire(sim, "lumberjack")
	Fixtures.run_with_workers(sim, 12.0)
	check(sim.woodpile >= 2, "벌목꾼이 원목을 적치장에 쌓는다 (%d)" % sim.woodpile)
	check(sim.player.stack.items.is_empty(), "플레이어는 아무것도 하지 않았다")


func test_porter_carries_woodpile_to_log_stall() -> void:
	var sim := _make_sim()
	sim.woodpile = 4
	var porter := _hire(sim, "porter")
	Fixtures.run_with_workers(sim, 12.0)
	check_eq(sim.woodpile, 0, "운반꾼이 적치장을 비운다")
	check(porter.stack.items.is_empty(), "들고 간 원목을 다 내려놓는다")
	check_eq(sim.stalls[0].stock + sim.stalls[0].served, 4, "원목 4개가 판매대로 간다")


func test_player_picks_up_from_woodpile() -> void:
	var sim := _make_sim()
	sim.woodpile = 3
	sim.player.pos = sim.woodpile_pos
	Fixtures.run(sim, 1.0)
	check_eq(sim.woodpile, 0, "플레이어도 적치장 원목을 집는다")
	check_eq(sim.player.stack.items.size(), 3, "집은 원목이 등에 쌓인다")


func test_cashier_collects_cash_into_wallet() -> void:
	var sim := _make_sim()
	sim.stalls[0].cash = 30
	_hire(sim, "cashier")
	Fixtures.run_with_workers(sim, 6.0)
	check_eq(sim.money, 30, "계산원이 판매대의 돈을 지갑에 넣는다")


func test_full_automation_earns_while_player_idles() -> void:
	var sim := _make_sim()
	for role in ["lumberjack", "porter", "cashier"]:
		_hire(sim, role)
	Fixtures.run_with_workers(sim, 90.0)
	check(sim.money > 0, "일꾼 셋이면 플레이어가 가만히 있어도 돈이 오른다 ($%d)" % sim.money)


func test_stall_cashier_only_collects_own_stall() -> void:
	var sim := _make_sim()
	sim._apply_effect({"unlock": "meat_stall"})
	sim._apply_effect({"hire": "cashier", "stall": 1})
	check_eq(sim.workers[0].stall, 1, "고용 효과의 판매대 번호를 맡는다")
	sim.stalls[0].cash = 30
	sim.stalls[1].cash = 45
	Fixtures.run_with_workers(sim, 8.0)
	check_eq(sim.money, 45, "맡은 판매대의 돈만 넣는다")
	check_eq(sim.stalls[0].cash, 30, "다른 판매대 돈은 그대로다")
