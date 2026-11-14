extends "res://frost_camp/tests/test_case.gd"
## 보스 레이드(6차 QA 4, 6, 7번): 입구로 출발, 클릭 사격, 내려찍기, 용병, 보상.

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")
const PORTAL := Vector2(-15, 5)


func _make_sim() -> FrostSim:
	var balance := Fixtures.balance()
	balance.boss = {
		"portal_delay": 1.0, "hp": 30, "hp_growth": 0.5, "radius": 1.5, "speed": 0.0,
		"contact_radius": 2.0, "contact_interval": 1.0, "contact_damage": 2,
		"slam_interval": 100.0, "slam_count": 1, "slam_radius": 2.0, "slam_warning": 1.0, "slam_damage": 4,
		"summon_interval": 100.0, "summon_count": 1, "minion_hp": 4, "minion_speed": 0.0, "minion_damage": 1,
		"reward": 100, "reward_growth": 0.5, "gems": 2,
	}
	balance.weapons = {
		"harpoon": {"cooldown": 0.5, "damage": [3, 5], "range": 12.0},
		"spread": {"cooldown": 0.5, "damage": 2, "shots": 3, "angle": 0.3, "range": 9.0},
		"cannon": {"cooldown": 1.0, "damage": 10, "range": 14.0, "splash": 2.5},
	}
	balance.mercs = {"damage": 2, "interval": 0.5, "range": 9.0, "speed": 3.0, "keep_distance": 4.0}
	balance.workers.merc = {"speed": 3.0, "hp": 6}
	balance.zones.merc = {"costs": [10, 10], "effect": {"hire": "merc"}, "optional": true}
	balance.zones.weapon_spread = {"costs": [10], "effect": {"unlock": "weapon_spread"}, "optional": true}
	balance.items.gem = {"price": 120}
	balance.gun = {"interval": 0.8, "range": [5.5, 7.0], "damage": [2, 3]}
	var layout := Fixtures.layout()
	layout.raid_arena = {"portal": [PORTAL.x, PORTAL.y], "center": [-60, 40], "radius": 10, "player_start": [-60, 46], "boss_start": [-60, 34]}
	layout.zones.merc = [-12, 8]
	layout.zones.weapon_spread = [-18, 8]
	return FrostSim.new(balance, layout)


func _start(sim: FrostSim) -> void:
	sim._apply_effect({"gun": 1})
	sim.player.pos = PORTAL
	Fixtures.run(sim, 1.1)


func test_portal_needs_gun_and_starts_raid() -> void:
	var sim := _make_sim()
	sim.player.pos = PORTAL
	Fixtures.run(sim, 1.5)
	check(not sim.boss_raid.active, "작살총이 없으면 출발하지 않는다")
	_start(sim)
	check(sim.boss_raid.active, "입구에 서 있으면 출발한다")
	check_eq(sim.player.pos, Vector2(-60, 46), "플레이어가 레이드 영역으로 옮겨진다")
	check_eq(sim.boss_raid.boss.hp, 30, "곰왕 체력")


func test_click_shot_hits_boss_with_cooldown() -> void:
	var sim := _make_sim()
	_start(sim)
	var raid := sim.boss_raid
	check(raid.shoot(raid.boss.pos), "쏜다")
	check_eq(raid.boss.hp, 27, "작살총 1단계 피해 3")
	check(not raid.shoot(raid.boss.pos), "쿨다운 중에는 못 쏜다")
	Fixtures.run(sim, 0.55)
	raid.shoot(sim.player.pos + Vector2(10, 0))
	check_eq(raid.boss.hp, 27, "빗나가면 피해가 없다")


func test_spread_needs_purchase() -> void:
	var sim := _make_sim()
	_start(sim)
	var raid := sim.boss_raid
	raid.select_weapon("spread")
	check_eq(raid.weapon, "harpoon", "사지 않은 무기는 고를 수 없다")
	sim.find_zone("weapon_spread").level = 1
	raid.select_weapon("spread")
	check_eq(raid.weapon, "spread", "산 무기는 고른다")


func test_slam_hurts_only_after_warning() -> void:
	var sim := _make_sim()
	_start(sim)
	var raid := sim.boss_raid
	raid.boss.pos = Vector2(-60, 30)
	raid._warn_slams()
	Fixtures.run(sim, 0.5)
	check_eq(sim.player.hp, sim.player.max_hp, "경고 중에는 다치지 않는다")
	Fixtures.run(sim, 0.6)
	check_eq(sim.player.hp, sim.player.max_hp - 4, "경고가 끝나면 원 안의 사람이 다친다")


func test_win_gives_reward_and_grows_boss() -> void:
	var sim := _make_sim()
	_start(sim)
	var raid := sim.boss_raid
	raid.boss.hp = 1
	raid.shoot(raid.boss.pos)
	Fixtures.run(sim, 0.05)
	check(not raid.active, "곰왕을 쓰러뜨리면 끝난다")
	check_eq(sim.money, 100, "보상 돈")
	check_eq(sim.player.stack.items.count("gem"), 2, "보석 2개")
	check(sim.player.pos.distance_to(PORTAL) < 3.0, "입구 옆으로 돌아온다")
	_start(sim)
	check_eq(raid.boss.max_hp, 45, "이길 때마다 강해진다")


func test_lose_when_player_falls() -> void:
	var sim := _make_sim()
	_start(sim)
	sim.player.hp = 0.0
	Fixtures.run(sim, 0.05)
	check(not sim.boss_raid.active, "플레이어가 쓰러지면 끝난다")
	check_eq(sim.money, 0, "빈손")


func test_merc_follows_and_dies() -> void:
	var sim := _make_sim()
	sim._apply_effect({"hire": "merc"})
	sim.workers[0].zone_id = "merc"
	sim.find_zone("merc").level = 1
	_start(sim)
	var merc := sim.workers[0]
	check(merc.pos.distance_to(Vector2(-60, 46)) < 3.0, "용병도 함께 옮겨진다")
	Fixtures.run(sim, 3.0)
	check(sim.boss_raid.boss.hp < 30, "용병이 곰왕을 쏜다")
	sim.boss_raid._hurt_merc(0, 99.0)
	check(merc.dead, "용병도 쓰러진다")
	check_eq(sim.find_zone("merc").level, 0, "용병 존 단계가 내려간다")


## 기지 용병은 입구 북쪽 한 줄에 서고, 습격 중에는 곰 쪽으로 나간다(7차 QA 4, 5번).
func test_merc_posts_and_sortie() -> void:
	var sim := _make_sim()
	for k in 3:
		sim._apply_effect({"hire": "merc"})
	for w in sim.workers:
		var post: Vector2 = WorkerBrain.choose(sim, w).pos
		check(post.y < PORTAL.y, "용병 대기 자리는 입구 북쪽(기지 안쪽)이다 (%s)" % post)
	var bear := RaidBear.new(Vector2(-15, -10), 100, 0.0)
	sim.raid.state = Raid.State.ATTACKING
	sim.raid.bears.append(bear)
	var goal: Vector2 = WorkerBrain.choose(sim, sim.workers[0]).pos
	check(absf(goal.distance_to(bear.pos) - 4.0) < 0.01, "습격 중에는 곰에게서 4m 떨어진 자리로 나간다")
