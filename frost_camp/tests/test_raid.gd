extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")

const LOG_STALL := 0
const MEAT_STALL := 1
const WOODPILE := 2
const TOWER := 3


func _make_sim() -> FrostSim:
	return FrostSim.new(Fixtures.balance(), Fixtures.layout())


## 습격 곰 한 마리를 바로 세워 둔다(웨이브 시계를 거치지 않는다).
func _place_raider(sim: FrostSim, pos: Vector2, hp: int = 4, speed: float = 2.0) -> RaidBear:
	var bear := RaidBear.new(pos, hp, speed)
	sim.raid.state = Raid.State.ATTACKING
	sim.raid.bears.append(bear)
	return bear


func test_raids_wait_until_habitat_opens() -> void:
	var sim := _make_sim()
	var warnings := []
	sim.raid_warning.connect(func(wave: int, _pos: Vector2) -> void: warnings.append(wave))
	Fixtures.run(sim, 30.0)
	check(warnings.is_empty(), "서식지를 열기 전에는 습격이 없다")


func test_warning_then_wave_spawns_bears() -> void:
	var sim := _make_sim()
	var events := []
	sim.raid_warning.connect(func(wave: int, _pos: Vector2) -> void: events.append("warning %d" % wave))
	sim.raid_started.connect(func(wave: int) -> void: events.append("attack %d" % wave))
	sim._apply_effect({"unlock": "habitat"})
	Fixtures.run(sim, 9.8)
	check(events.is_empty(), "start_delay 전에는 경고가 없다")
	Fixtures.run(sim, 0.4)
	check_eq(events, ["warning 1"], "start_delay가 지나면 첫 경고가 뜬다")
	Fixtures.run(sim, 5.0)
	check_eq(events, ["warning 1", "attack 1"], "warning초 뒤 첫 웨이브가 온다")
	check_eq(sim.raid.bears.size(), 2, "첫 웨이브는 count_base마리")
	check_eq(sim.raid.bears[0].max_hp, 4, "첫 웨이브 체력은 hp_base")


func test_wave_size_and_hp_grow() -> void:
	var sim := _make_sim()
	check_eq(sim.raid.wave_count(2), 3, "웨이브마다 count_growth만큼 는다")
	check_eq(sim.raid.wave_count(5), 3, "count_max를 넘지 않는다")
	check_eq(sim.raid.wave_hp(3), 8, "웨이브마다 hp_growth만큼 단단해진다")


func test_raider_attacks_nearest_standing_structure() -> void:
	var sim := _make_sim()
	var bear := _place_raider(sim, Vector2(10, 4))
	Fixtures.run(sim, 0.1)
	check_eq(bear.target, WOODPILE, "첫 원목 판매대, 닫힌 판매대, 안 산 포탑은 노리지 않는다")
	bear.pos = Vector2(-6, 3)
	Fixtures.run(sim, 3.0)
	check(sim.structures[WOODPILE].hp < 10, "도착하면 시설을 때린다 (%d)" % sim.structures[WOODPILE].hp)
	check_eq(sim.structures[LOG_STALL].hp, 10, "첫 원목 판매대는 멀쩡하다")


func test_raider_moves_on_after_breaking_structure() -> void:
	var sim := _make_sim()
	sim._apply_effect({"unlock": "meat_stall"})
	var bear := _place_raider(sim, Vector2(-6, 2))
	Fixtures.run(sim, 7.0)
	check(sim.structures[WOODPILE].is_broken(), "계속 때리면 부서진다")
	check_eq(bear.target, MEAT_STALL, "부서진 시설을 버리고 다음 시설로 간다")


func test_clearing_wave_starts_next_timer() -> void:
	var sim := _make_sim()
	var cleared := []
	sim.raid_cleared.connect(func(wave: int) -> void: cleared.append(wave))
	var bear := _place_raider(sim, Vector2(30, 30), 4, 0.0)
	sim.raid.wave = 1
	bear.take_hit(4)
	Fixtures.run(sim, 0.1)
	check_eq(cleared, [1], "무리를 다 잡으면 방어 성공")
	check_eq(sim.raid.state, Raid.State.WAITING, "다음 웨이브까지 다시 기다린다")


func test_player_fights_raider_even_with_full_stack() -> void:
	var sim := _make_sim()
	for i in 10:
		sim.player.stack.push("log")
	var bear := _place_raider(sim, sim.player.pos + Vector2(1, 0), 4, 0.0)
	Fixtures.run(sim, 1.5)
	check(not bear.is_alive(), "등이 가득 차도 습격 곰은 막는다")
	check_eq(sim.bears_killed, 1, "잡은 곰 수에 들어간다")
	check_eq(sim.money, 10, "현상금이 지갑에 들어온다")
	check_eq(sim.player.stack.items.count("meat"), 0, "고기는 떨구지 않는다")


func test_tower_fires_only_after_purchase() -> void:
	var sim := _make_sim()
	var shots := []
	sim.tower_fired.connect(func(t: int, r: int) -> void: shots.append([t, r]))
	var bear := _place_raider(sim, Vector2(0, 12), 4, 0.0)
	Fixtures.run(sim, 3.0)
	check_eq(bear.hp, 4, "사지 않은 포탑은 쏘지 않는다")
	sim._apply_effect({"tower": "tower_1"})
	Fixtures.run(sim, 0.1)
	check_eq(bear.hp, 2, "산 포탑은 사거리 안의 곰을 바로 쏜다")
	Fixtures.run(sim, 1.0)
	check(not bear.is_alive(), "간격마다 다시 쏴서 잡는다")
	check_eq(shots, [[0, 0], [0, 0]], "발사 이벤트가 나온다")


func test_tower_upgrade_raises_damage_and_broken_tower_stops() -> void:
	var sim := _make_sim()
	sim._apply_effect({"tower": "tower_1"})
	sim._apply_effect({"tower": "tower_1"})
	var bear := _place_raider(sim, Vector2(0, 12), 10, 0.0)
	Fixtures.run(sim, 0.1)
	check_eq(bear.hp, 6, "2레벨 포탑은 damage + damage_add")
	sim.damage_structure(TOWER, 10)
	Fixtures.run(sim, 3.0)
	check_eq(bear.hp, 6, "부서진 포탑은 쏘지 않는다")


func test_raider_out_of_range_is_ignored_by_tower() -> void:
	var sim := _make_sim()
	sim._apply_effect({"tower": "tower_1"})
	var bear := _place_raider(sim, Vector2(0, 20), 4, 0.0)
	Fixtures.run(sim, 2.0)
	check_eq(bear.hp, 4, "사거리 밖은 쏘지 않는다")


func test_raider_without_target_comes_for_player() -> void:
	var sim := _make_sim()
	sim.damage_structure(WOODPILE, 10)
	var bear := _place_raider(sim, Vector2(0, 10))
	sim.player.pos = Vector2(-20, 0)
	Fixtures.run(sim, 0.5)
	check_eq(bear.target, -1, "노릴 시설이 없다")
	check(bear.pos.distance_to(sim.player.pos) < Vector2(0, 10).distance_to(sim.player.pos), "플레이어 쪽으로 다가온다")
