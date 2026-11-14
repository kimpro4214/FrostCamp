extends "res://frost_camp/tests/test_case.gd"
## 눈보라(8차 QA 다음 개발): 모닥불을 산 뒤 경고 → 불기 → 그침을 되풀이하고, 부는 동안 추위가 빨리 온다.

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim() -> FrostSim:
	var balance := Fixtures.balance()
	balance.blizzard = {"start_after": "fire", "start_delay": 5.0, "interval": 10.0, "warning": 2.0, "duration": 4.0, "cold_mult": 2.5}
	return FrostSim.new(balance, Fixtures.layout())


func test_blizzard_waits_for_fire() -> void:
	var sim := _make_sim()
	Fixtures.run(sim, 20.0)
	check_eq(sim.blizzard.state, Blizzard.State.DORMANT, "모닥불을 사기 전에는 오지 않는다")


func test_blizzard_cycle() -> void:
	var sim := _make_sim()
	var events: Array[String] = []
	sim.blizzard_warning.connect(func() -> void: events.append("warning"))
	sim.blizzard_started.connect(func() -> void: events.append("started"))
	sim.blizzard_ended.connect(func() -> void: events.append("ended"))
	sim.find_zone("fire").level = 1
	Fixtures.run(sim, 5.2)
	check_eq(events, ["warning"] as Array[String], "start_delay 뒤 경고")
	Fixtures.run(sim, 2.0)
	check_eq(sim.blizzard.state, Blizzard.State.ACTIVE, "경고 뒤 분다")
	Fixtures.run(sim, 4.0)
	check_eq(events, ["warning", "started", "ended"] as Array[String], "duration 뒤 그친다")
	check_eq(sim.blizzard.state, Blizzard.State.WAITING, "다시 interval을 기다린다")


func test_blizzard_speeds_up_cold() -> void:
	var calm := _make_sim()
	var storm := _make_sim()
	storm.blizzard.state = Blizzard.State.ACTIVE
	storm.blizzard.time_left = 100.0
	for sim in [calm, storm]:
		sim.player.pos = Vector2(40, 40)
		Fixtures.run(sim, 2.0)
	check(absf((30.0 - calm.player.warmth) - 2.0) < 0.2, "평소에는 초당 1씩 언다")
	check(absf((30.0 - storm.player.warmth) - 5.0) < 0.3, "눈보라에는 2.5배 빨리 언다")
