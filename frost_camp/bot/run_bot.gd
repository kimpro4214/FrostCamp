extends SceneTree
## 탐욕 봇을 실제 데이터로 엔딩까지 여러 시드로 돌리고, 기획서 5장의 단계별 목표 시간과 비교해 playtest/에 남긴다.
## 실행: godot --headless -s res://frost_camp/bot/run_bot.gd [-- 라벨 [ignore_cold]]
## ignore_cold를 주면 봇이 추위를 무시한다.
## 결과 파일 이름은 날짜(와 라벨)로 정한다. 같은 이름이면 덮어쓴다.

const STEP := 0.05
const MAX_TIME := 45.0 * 60.0
const SAMPLE_EVERY := 10.0
const SEEDS := [1, 2, 3, 4, 5]
const OUT_DIR := "res://playtest/"
## 기획서 5장 진행표를 MVP 구매로 옮긴 것. [단계, 기준(존 id 또는 ending), 목표 시작 분, 목표 끝 분]
const MILESTONES := [
	["1 표류", "backpack", 0, 3],
	["2 사냥", "meat_stall", 3, 8],
	["2 사냥", "lumberjack", 3, 8],
	["3 자동화", "porter", 8, 15],
	["3 자동화", "cashier", 8, 15],
	["3 자동화", "stove", 8, 15],
	["3 자동화", "conveyor", 8, 15],
	["3 자동화", "hunter", 8, 15],
	["3 자동화", "wall", 8, 15],
	["4 확장", "expand_1", 15, 25],
	["4 확장", "expand_2", 15, 25],
	["4 확장", "port", 15, 25],
	["5 탈출", "ending", 25, 30],
]


func _initialize() -> void:
	var runs: Array = []
	for seed_value in SEEDS:
		runs.append(_run(seed_value))

	var stamp := Time.get_date_string_from_system()
	var label := OS.get_cmdline_user_args()
	if not label.is_empty():
		stamp += "_" + label[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_write_csv(OUT_DIR + "%s_greedy_money.csv" % stamp, runs[0].samples)
	_write_report(OUT_DIR + "%s_greedy.md" % stamp, runs)
	var endings := runs.map(func(r: Dictionary) -> String: return "%.1f" % (r.reached.get("ending", -60.0) / 60.0))
	print("봇 종료: 시드별 엔딩(분) %s" % ", ".join(endings))
	quit(0)


## 시드 하나로 엔딩(또는 시간 초과)까지 돌린다.
func _run(seed_value: int) -> Dictionary:
	var sim := FrostSim.new(GameData.load_json(GameData.BALANCE_PATH), GameData.load_json(GameData.LAYOUT_PATH), seed_value)
	var bot := GreedyBot.new(sim)
	bot.warm_up = not OS.get_cmdline_user_args().has("ignore_cold")
	# 습격 피해 기록: 부서진 횟수, 수리 횟수와 비용, 시설이 멈춰 있던 시간(시설 수 × 초)
	var raid_stats := {"broken": 0, "repairs": 0, "repair_spent": 0, "down_time": 0.0}
	sim.structure_broken.connect(func(_i: int) -> void: raid_stats.broken += 1)
	sim.structure_repaired.connect(func(i: int) -> void:
		raid_stats.repairs += 1
		raid_stats.repair_spent += int(sim.structures[i].repair.costs[0]))
	var samples: Array = []
	var next_sample := 0.0
	while bot.time < MAX_TIME and not sim.won and not bot.is_done():
		if bot.time >= next_sample:
			samples.append([bot.time, sim.money, _total_spent(sim)])
			next_sample += SAMPLE_EVERY
		bot.step(STEP)
		for structure in sim.structures:
			if structure.is_broken():
				raid_stats.down_time += STEP
	samples.append([bot.time, sim.money, _total_spent(sim)])
	var reached := {}
	for p in bot.purchases:
		if not reached.has(p[1]):
			reached[p[1]] = p[0]
	if sim.won:
		reached["ending"] = sim.time
	return {"seed": seed_value, "bot": bot, "sim": sim, "samples": samples, "reached": reached, "raid": raid_stats}


func _total_spent(sim: FrostSim) -> int:
	var spent := 0
	for zone in sim.zones:
		for i in zone.level:
			spent += int(zone.costs[i])
		spent += zone.paid
	return spent


func _write_csv(path: String, samples: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line("time_s,money,spent,earned")
	for s in samples:
		file.store_line("%.1f,%d,%d,%d" % [s[0], s[1], s[2], s[1] + s[2]])


func _write_report(path: String, runs: Array) -> void:
	var lines: PackedStringArray = []
	lines.append("# 탐욕 봇 결과 (%s)" % Time.get_datetime_string_from_system(false, true))
	lines.append("")
	lines.append("- 규칙: 살 수 있는 존 중 남은 금액이 가장 싼 것을 산다. 직선 이동, 충돌 무시. %s" % (
		"온기 20% 밑이면 불가에서 녹인다." if runs[0].bot.warm_up else "추위를 무시한다."))
	lines.append("- 시드 %s (곰 배회가 달라진다)" % ", ".join(SEEDS.map(func(s: int) -> String: return str(s))))
	lines.append("")
	lines.append("## 단계별 도달 시각과 기획서 목표")
	lines.append("")
	lines.append("| 단계 | 기준 | 목표 | 최소 | 중앙값 | 최대 | 판정 |")
	lines.append("|---|---|---|---|---|---|---|")
	for m in MILESTONES:
		var times: Array = []
		for r in runs:
			if r.reached.has(m[1]):
				times.append(r.reached[m[1]])
		times.sort()
		if times.size() < runs.size():
			lines.append("| %s | %s | %d~%d분 | - | - | - | 도달 못 한 시드 있음 |" % [m[0], m[1], m[2], m[3]])
			continue
		var median: float = times[times.size() / 2]
		var verdict := "범위 안"
		if median < m[2] * 60.0:
			verdict = "이르다"
		elif median > m[3] * 60.0:
			verdict = "늦다"
		lines.append("| %s | %s | %d~%d분 | %s | %s | %s | %s |" % [
			m[0], m[1], m[2], m[3], _clock(times[0]), _clock(median), _clock(times[-1]), verdict])
	lines.append("")
	lines.append("## 시드별 요약")
	lines.append("")
	lines.append("| 시드 | 결과 | 번 돈 | 잡은 곰 | 일꾼 | 원목 판매 | 고기 판매 |")
	lines.append("|---|---|---|---|---|---|---|")
	for r in runs:
		var sim: FrostSim = r.sim
		lines.append("| %d | %s | $%d | %d | %d | %d | %d |" % [
			r.seed, _outcome(r.bot, sim), sim.total_earned, sim.bears_killed, sim.workers.size(),
			sim.stalls[0].served, sim.stalls[1].served])
	lines.append("")
	lines.append("## 습격 피해")
	lines.append("")
	lines.append("| 시드 | 웨이브 | 부서진 횟수 | 수리 횟수 | 수리비 | 시설이 멈춘 시간 |")
	lines.append("|---|---|---|---|---|---|")
	for r in runs:
		var raid: Dictionary = r.raid
		lines.append("| %d | %d | %d | %d | $%d | %s |" % [
			r.seed, r.sim.raid.wave, raid.broken, raid.repairs, raid.repair_spent, _clock(raid.down_time)])
	lines.append("")
	lines.append("시설이 멈춘 시간은 부서져 있던 시설 수를 시간에 걸쳐 더한 값이다(두 개가 1분 부서져 있으면 2분).")
	lines.append("")
	lines.append("## 시드 %d 구매 기록" % runs[0].seed)
	lines.append("")
	lines.append("| 시각 | 구매 | 레벨 |")
	lines.append("|---|---|---|")
	for p in runs[0].bot.purchases:
		lines.append("| %s | %s | %d |" % [_clock(p[0]), p[1], p[2]])
	lines.append("")
	lines.append("시드 %d의 돈 곡선은 같은 이름의 `_greedy_money.csv`에 있다." % runs[0].seed)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")


func _outcome(bot: GreedyBot, sim: FrostSim) -> String:
	if sim.won:
		return "엔딩 %s" % _clock(sim.time)
	return "살 것이 없음" if bot.is_done() else "시간 초과"


func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
