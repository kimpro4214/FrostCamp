extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_sim() -> FrostSim:
	return FrostSim.new(Fixtures.balance(), Fixtures.layout())


func _place_raider(sim: FrostSim, pos: Vector2) -> RaidBear:
	var bear := RaidBear.new(pos, 100, 2.0)
	sim.raid.state = Raid.State.ATTACKING
	sim.raid.bears.append(bear)
	return bear


func test_walls_stand_only_after_purchase() -> void:
	var sim := _make_sim()
	var wall: int = sim.walls[0]
	check(not sim.is_structure_standing(wall), "사기 전에는 방벽이 없다")
	var bear := _place_raider(sim, Vector2(0, 16))
	Fixtures.run(sim, 0.1)
	check(sim.structures[bear.target].kind != "wall", "방벽이 없으면 바로 시설을 노린다")
	sim._apply_effect({"walls": 1})
	check(sim.is_structure_standing(wall), "사면 방벽이 선다")
	check_eq(sim.structures[wall].max_hp, 10, "1레벨 체력")


func test_raider_outside_base_attacks_nearest_wall_first() -> void:
	var sim := _make_sim()
	sim._apply_effect({"walls": 1})
	var bear := _place_raider(sim, Vector2(0, 16))
	Fixtures.run(sim, 0.1)
	check_eq(bear.target, sim.walls[0], "기지 밖 곰은 가장 가까운 방벽 구간부터 노린다")
	Fixtures.run(sim, 10.0)
	check(sim.structures[sim.walls[0]].is_broken(), "계속 때려 무너뜨린다")
	check(bear.breached, "방벽을 뚫었다")
	check(sim.structures[bear.target].kind != "wall", "뚫은 뒤에는 안쪽 시설로 간다")


func test_raider_inside_base_ignores_walls() -> void:
	var sim := _make_sim()
	sim._apply_effect({"walls": 1})
	var bear := _place_raider(sim, Vector2(-6, 3))
	Fixtures.run(sim, 0.1)
	check(sim.structures[bear.target].kind != "wall", "기지 안의 곰은 방벽을 노리지 않는다")


func test_wall_upgrade_raises_and_restores_hp() -> void:
	var sim := _make_sim()
	sim._apply_effect({"walls": 1})
	var wall: int = sim.walls[0]
	sim.damage_structure(wall, 10)
	check(sim.structures[wall].is_broken(), "무너졌다")
	sim._apply_effect({"walls": 1})
	check_eq(sim.structures[wall].max_hp, 20, "2레벨 체력")
	check_eq(sim.structures[wall].hp, 20, "레벨을 올리면 모든 구간이 다시 선다")


func test_expansion_moves_walls_outward() -> void:
	var sim := _make_sim()
	sim._apply_effect({"walls": 1})
	var inner: int = sim.walls[1]
	var outer: int = sim.walls[2]
	check(sim.is_structure_standing(inner), "확장 전에는 안쪽 구간이 서 있다")
	check(not sim.is_structure_standing(outer), "확장 전에는 바깥 구간이 없다")
	sim._apply_effect({"unlock": "expand_1"})
	check(not sim.is_structure_standing(inner), "확장하면 안쪽이 된 구간은 사라진다")
	check(sim.is_structure_standing(outer), "확장한 땅 둘레에 새 구간이 선다")
	check(sim.is_in_base(Vector2(-15, 15)), "확장한 땅도 기지 안이다")


func test_broken_wall_repair_zone_only_when_active() -> void:
	var sim := _make_sim()
	sim._apply_effect({"walls": 1})
	var inner: int = sim.walls[1]
	sim.damage_structure(inner, 10)
	sim._apply_effect({"unlock": "expand_1"})
	sim.money = 100
	sim.player.pos = sim.structures[inner].repair.pos
	Fixtures.run(sim, 2.0)
	check_eq(sim.money, 100, "사라진 구간은 수리비를 받지 않는다")


## 스폰마다 정해진 길목 구간만 친다(4차 QA 8번).
func test_raiders_hit_their_spawn_gate() -> void:
	var layout := Fixtures.layout()
	layout.raid_spawns = [{"pos": [-15, 14], "gate": [[10, 10], [-10, 10]]}]
	var sim := FrostSim.new(Fixtures.balance(), layout)
	check_eq(sim.spawn_gates, [sim.walls[0]], "끝점 순서가 달라도 길목 구간을 찾는다")
	sim._apply_effect({"walls": 1})
	sim._apply_effect({"unlock": "habitat"})
	Fixtures.run(sim, 15.1)
	check(sim.raid.bears.size() > 0, "웨이브가 왔다")
	Fixtures.run(sim, 0.1)
	for bear in sim.raid.bears:
		check_eq(bear.target, sim.walls[0], "더 가까운 구간이 있어도 길목 구간을 노린다")



## 방벽 너머 근접 공격은 없다(5차 QA 6번). 방벽을 치는 곰도 근접 거리 밖이면 못 친다.
func test_no_melee_over_wall() -> void:
	var sim := _make_sim()
	sim._apply_effect({"walls": 1})
	var bear := _place_raider(sim, Vector2(0, 11.5))
	sim.player.pos = Vector2(0, 9.2)
	Fixtures.run(sim, 2.0)
	check_eq(bear.target, sim.walls[0], "곰이 방벽을 친다")
	check_eq(bear.hp, bear.max_hp, "방벽 너머 근접 공격은 닿지 않는다")
