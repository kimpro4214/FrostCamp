extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")
const NEAR_BEAR := Vector2(0, -24.5)


func _make_sim() -> FrostSim:
	return FrostSim.new(Fixtures.balance(), Fixtures.layout())


func test_fighting_bear_drops_meat_and_hurts_player() -> void:
	var sim := _make_sim()
	sim.player.pos = NEAR_BEAR
	Fixtures.run(sim, 3.0)
	check_eq(sim.player.stack.items, ["meat", "meat"] as Array[String], "곰을 잡으면 고기 2개를 얻는다")
	check_eq(sim.bears_killed, 1, "잡은 곰 수가 기록된다")
	check(not sim.bears[0].is_alive(), "곰이 쓰러진다")
	check(sim.player.hp < sim.player.max_hp, "곰의 반격으로 체력이 깎인다")


func test_player_gets_dazed_instead_of_dying() -> void:
	var sim := _make_sim()
	sim.player.pos = NEAR_BEAR
	sim.player.hp = 3.0
	Fixtures.run(sim, 1.1)
	check(sim.player.dazed_left > 0.0, "체력이 0이 되면 멍해진다")
	check_eq(sim.agent_speed(sim.player), 2.5, "멍한 동안 이동 속도가 절반이 된다")
	var bear_hp := sim.bears[0].hp
	Fixtures.run(sim, 1.5)
	check_eq(sim.bears[0].hp, bear_hp, "멍한 동안에는 공격하지 않는다")
	Fixtures.run(sim, 1.6)
	check_eq(sim.player.dazed_left, 0.0, "시간이 지나면 깨어난다")
	check_eq(sim.player.hp, sim.player.max_hp, "깨어나면 체력이 다시 찬다")


func test_harpoon_upgrade_kills_bear_faster() -> void:
	var sim := _make_sim()
	sim.money = 10
	sim.player.pos = Vector2(9, 5)
	Fixtures.run(sim, 1.5)
	sim.player.pos = sim.bears[0].pos + Vector2(0.5, 0)
	Fixtures.run(sim, 1.3)
	check_eq(sim.bears_killed, 1, "공격력 5면 2타(1초) 만에 잡는다")


func test_bear_respawns_at_spawn_with_full_hp() -> void:
	var sim := _make_sim()
	sim.player.pos = NEAR_BEAR
	Fixtures.run(sim, 3.0)
	sim.player.pos = Vector2.ZERO
	Fixtures.run(sim, 10.0)
	var bear := sim.bears[0]
	check(bear.is_alive(), "리스폰 시간이 지나면 다시 나타난다")
	check_eq(bear.hp, bear.max_hp, "체력이 다 찬 채로 나타난다")


func test_bear_wanders_inside_habitat() -> void:
	var sim := _make_sim()
	var start := sim.bears[0].pos
	var area: Rect2 = sim.regions.habitat.rect
	var moved := false
	for i in 1200:
		sim.tick(0.05)
		moved = moved or sim.bears[0].pos.distance_to(start) > 1.0
		if not area.has_point(sim.bears[0].pos):
			failures.append("곰이 서식지 밖으로 나갔다: %s" % sim.bears[0].pos)
			return
	check(moved, "곰이 배회한다")


func test_no_fight_without_room_for_meat() -> void:
	var sim := _make_sim()
	for i in 9:
		sim.player.stack.push("log")
	sim.player.pos = NEAR_BEAR
	Fixtures.run(sim, 2.0)
	check_eq(sim.bears[0].hp, sim.bears[0].max_hp, "고기가 들어갈 자리가 없으면 싸우지 않는다")
