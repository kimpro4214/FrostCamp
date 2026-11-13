extends "res://frost_camp/tests/test_case.gd"
## 작살총(5차 QA 6번): 플레이어가 사거리 안의 습격 곰을 자동으로 쏜다.

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim() -> FrostSim:
	var balance := Fixtures.balance()
	balance.gun = {"interval": 0.5, "range": [4.0, 6.0], "damage": [2, 3]}
	return FrostSim.new(balance, Fixtures.layout())


func _place_raider(sim: FrostSim, pos: Vector2) -> RaidBear:
	var bear := RaidBear.new(pos, 100, 0.0)
	sim.raid.state = Raid.State.ATTACKING
	sim.raid.bears.append(bear)
	return bear


func test_no_gun_no_shots() -> void:
	var sim := _make_sim()
	var bear := _place_raider(sim, Vector2(3, 0))
	sim.player.pos = Vector2.ZERO
	Fixtures.run(sim, 2.0)
	check_eq(bear.hp, 100, "작살총이 없으면 근접 거리 밖 곰은 못 친다")


func test_gun_shoots_in_range_only() -> void:
	var sim := _make_sim()
	var shots := []
	sim.gun_fired.connect(func(i: int) -> void: shots.append(i))
	sim._apply_effect({"gun": 1})
	var near := _place_raider(sim, Vector2(3.5, 0))
	var far := _place_raider(sim, Vector2(0, 5.0))
	sim.player.pos = Vector2.ZERO
	Fixtures.run(sim, 1.2)
	check_eq(shots.size(), 3, "사자마자 쏘고 interval마다 쏜다")
	check_eq(near.hp, 94, "1단계 피해 2")
	check_eq(far.hp, 100, "사거리 밖 곰은 쏘지 않는다")


func test_gun_upgrade_extends_range_and_damage() -> void:
	var sim := _make_sim()
	sim._apply_effect({"gun": 1})
	sim._apply_effect({"gun": 1})
	var far := _place_raider(sim, Vector2(0, 5.0))
	sim.player.pos = Vector2.ZERO
	Fixtures.run(sim, 0.05)
	check_eq(far.hp, 97, "2단계는 사거리가 늘고 피해 3")


func test_gun_kill_rewards_player() -> void:
	var sim := _make_sim()
	sim._apply_effect({"gun": 1})
	var bear := _place_raider(sim, Vector2(3, 0))
	bear.hp = 2
	sim.player.pos = Vector2.ZERO
	Fixtures.run(sim, 0.05)
	check(not bear.is_alive(), "쓰러뜨린다")
	check_eq(sim.money, 10, "고기 판매대가 없으면 현상금")
