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


func test_raider_drops_meat_once_meat_stall_opens() -> void:
	var sim := _make_sim()
	sim._apply_effect({"unlock": "meat_stall"})
	var bear := _place_raider(sim, sim.player.pos + Vector2(1, 0), 4, 0.0)
	Fixtures.run(sim, 1.5)
	check(not bear.is_alive(), "잡았다")
	check_eq(sim.player.stack.items.count("meat"), 2, "고기 판매대가 열려 있으면 고기를 떨군다")
	check_eq(sim.money, 0, "고기를 받으면 현상금은 없다")


func test_tower_kill_pays_bounty_even_with_meat_stall() -> void:
	var sim := _make_sim()
	sim._apply_effect({"unlock": "meat_stall"})
	sim._apply_effect({"tower": "tower_1"})
	_place_raider(sim, Vector2(0, 12), 2, 0.0)
	Fixtures.run(sim, 0.2)
	check_eq(sim.money, 10, "포탑이 잡으면 현상금")


func test_bear_den_adds_habitat_bears() -> void:
	var sim := _make_sim()
	var added := []
	sim.bear_added.connect(func(i: int) -> void: added.append(i))
	sim._apply_effect({"bears": 2})
	check_eq(sim.bears.size(), 3, "곰이 2마리 늘어난다")
	check_eq(added, [1, 2], "새 곰마다 이벤트가 나온다")
	check_eq(sim.bears[1].pos, Vector2(5, -25), "준비된 자리에 나타난다")
	sim._apply_effect({"bears": 2})
	check_eq(sim.bears.size(), 4, "자리가 모자라면 남은 만큼만 는다")


## 습격 중에는 수리할 수 없고, 웨이브가 끝나면 고칠 수 있다(5차 QA 10번).
func test_repair_waits_until_wave_cleared() -> void:
	var sim := _make_sim()
	sim.money = 100
	sim.damage_structure(WOODPILE, 100)
	_place_raider(sim, Vector2(30, 30), 100, 0.0)
	sim.player.pos = sim.structures[WOODPILE].repair.pos
	Fixtures.run(sim, 3.0)
	check(sim.structures[WOODPILE].is_broken(), "습격 중에는 고쳐지지 않는다")
	check_eq(sim.money, 100, "돈도 들어가지 않는다")
	sim.raid.bears[0].hp = 0
	Fixtures.run(sim, 4.0)
	check(not sim.structures[WOODPILE].is_broken(), "웨이브가 끝나면 고칠 수 있다")


## 습격 곰은 길목 바깥 접근점과 안쪽 점을 거쳐 들어온다(5차 QA 9번).
func test_raider_walks_through_gate_path() -> void:
	var layout := Fixtures.layout()
	layout.raid_spawns = [{"pos": [0, 30], "gate": [[-10, 10], [10, 10]]}]
	var sim := FrostSim.new(Fixtures.balance(), layout)
	check_eq(sim.spawn_paths[0], [Vector2(0, 12.5), Vector2(0, 8.0)], "길목 바깥 2.5, 안쪽 2.0")
	sim._apply_effect({"unlock": "habitat"})
	Fixtures.run(sim, 15.1)
	check(sim.raid.bears.size() > 0, "웨이브가 왔다")
	var bear: RaidBear = sim.raid.bears[0]
	var passed_gate := false
	for i in 400:
		sim.tick(0.05)
		if bear.pos.distance_to(Vector2(0, 8.0)) < 1.6:
			passed_gate = true
	check(passed_gate, "길목 안쪽 점을 지나간다")
