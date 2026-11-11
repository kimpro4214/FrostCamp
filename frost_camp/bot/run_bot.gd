extends SceneTree
## 탐욕 봇을 실제 데이터로 돌리고 결과를 playtest/에 남긴다.
## 실행: godot --headless -s res://frost_camp/bot/run_bot.gd

const STEP := 0.05
const MAX_TIME := 45.0 * 60.0
const SAMPLE_EVERY := 10.0
const OUT_DIR := "res://playtest/"


func _initialize() -> void:
	var sim := FrostSim.new(GameData.load_json(GameData.BALANCE_PATH), GameData.load_json(GameData.LAYOUT_PATH))
	var bot := GreedyBot.new(sim)
	var samples: Array = []
	var next_sample := 0.0
	while bot.time < MAX_TIME and not bot.is_done():
		if bot.time >= next_sample:
			samples.append([bot.time, sim.money, _total_spent(sim)])
			next_sample += SAMPLE_EVERY
		bot.step(STEP)
	samples.append([bot.time, sim.money, _total_spent(sim)])

	var stamp := Time.get_date_string_from_system()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_write_csv(OUT_DIR + "%s_greedy_money.csv" % stamp, samples)
	_write_report(OUT_DIR + "%s_greedy.md" % stamp, bot, sim, samples)
	print("봇 종료: %s, %.1f분" % ["모든 존 구매" if bot.is_done() else "시간 초과", bot.time / 60.0])
	quit(0)


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


func _write_report(path: String, bot: GreedyBot, sim: FrostSim, samples: Array) -> void:
	var lines: PackedStringArray = []
	lines.append("# 탐욕 봇 결과 (%s)" % Time.get_datetime_string_from_system(false, true))
	lines.append("")
	lines.append("- 규칙: 살 수 있는 존 중 남은 금액이 가장 싼 것을 산다. 직선 이동, 충돌 무시.")
	lines.append("- 결과: %s, 시뮬레이션 %.1f분" % ["모든 존 구매" if bot.is_done() else "시간 초과", bot.time / 60.0])
	lines.append("- 번 돈 합계: $%d" % (samples[-1][1] + samples[-1][2]))
	lines.append("")
	lines.append("| 시각 | 구매 | 레벨 |")
	lines.append("|---|---|---|")
	for p in bot.purchases:
		lines.append("| %s | %s | %d |" % [_clock(p[0]), p[1], p[2]])
	lines.append("")
	lines.append("판매대별 손님: " + ", ".join(sim.stalls.map(
		func(s: Stall) -> String: return "%s 판매 %d / 화내고 떠남 %d" % [s.item, s.served, s.left_angry])))
	lines.append("")
	lines.append("돈 곡선은 같은 날짜의 `_greedy_money.csv`에 있다.")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")


func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
