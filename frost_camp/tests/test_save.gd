extends "res://frost_camp/tests/test_case.gd"
## 이어하기(8차 QA 다음 개발): 저장한 sim을 새 sim에 되살리면 같은 상태가 되고, 이어서 돌려도 같게 흐른다.

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _real_sim() -> FrostSim:
	return FrostSim.new(GameData.load_json(GameData.BALANCE_PATH), GameData.load_json(GameData.LAYOUT_PATH), 3)


## 봇으로 seconds만큼 진행하고, 저장할 수 있는 때까지 조금 더 간다.
func _played(seconds: float) -> FrostSim:
	var sim := _real_sim()
	var bot := GreedyBot.new(sim)
	while bot.time < seconds or not SaveGame.can_save(sim):
		bot.step(0.1)
	return sim


## 파일에 쓰고 읽는 것과 같은 변환을 거쳐 새 sim에 되살린다.
func _reloaded(sim: FrostSim) -> FrostSim:
	var data: Dictionary = bytes_to_var(var_to_bytes(SaveGame.capture(sim)))
	var copy := _real_sim()
	SaveGame.restore(copy, data)
	return copy


func test_restore_matches_saved_state() -> void:
	var sim := _played(720.0)
	var copy := _reloaded(sim)
	check(sim.workers.size() > 3, "일꾼을 고용한 판이다")
	check_eq(copy.money, sim.money, "돈")
	check_eq(copy.time, sim.time, "시간")
	check_eq(copy.workers.size(), sim.workers.size(), "일꾼 수")
	check_eq(copy.bears.size(), sim.bears.size(), "사냥 곰 수")
	check_eq(var_to_str(SaveGame.capture(copy)), var_to_str(SaveGame.capture(sim)), "저장 내용 전체가 같다")


func test_restored_game_runs_the_same() -> void:
	var sim := _played(600.0)
	var copy := _reloaded(sim)
	Fixtures.run_with_workers(sim, 60.0, 0.1)
	Fixtures.run_with_workers(copy, 60.0, 0.1)
	check_eq(copy.money, sim.money, "60초 뒤 돈이 같다")
	check_eq(var_to_str(SaveGame.capture(copy)), var_to_str(SaveGame.capture(sim)), "60초 뒤 상태 전체가 같다")


func test_no_save_during_raids_or_after_ending() -> void:
	var sim := _real_sim()
	check(SaveGame.can_save(sim), "평소에는 저장한다")
	sim.raid.state = Raid.State.ATTACKING
	check(not SaveGame.can_save(sim), "습격이 쳐들어온 중에는 저장하지 않는다")
	sim.raid.state = Raid.State.WAITING
	sim.boss_raid.active = true
	check(not SaveGame.can_save(sim), "곰왕 레이드 중에는 저장하지 않는다")
	sim.boss_raid.active = false
	sim.won = true
	check(not SaveGame.can_save(sim), "엔딩 뒤에는 저장하지 않는다")
