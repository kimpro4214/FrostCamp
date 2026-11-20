extends RefCounted
## 최고 기록(8차 QA 다음 개발). 탈출한 판마다 가장 빠른 탈출 시간과 탈출 횟수를 user://에 남긴다.



## {"best_time": 초(없으면 0), "clears": 탈출 횟수}
static func read() -> Dictionary:
	var records := {"best_time": 0.0, "clears": 0}
	if not FileAccess.file_exists(_path()):
		return records
	var file := FileAccess.open(_path(), FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if data is Dictionary:
		records.merge(data, true)
	return records


## 탈출 시간을 더한다. 처음이거나 지난 최고보다 빠르면 true(새 기록).
static func add_clear(seconds: float) -> bool:
	var records := read()
	var best: float = records.best_time
	var is_new := best <= 0.0 or seconds < best
	if is_new:
		records.best_time = seconds
	records.clears = int(records.clears) + 1
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(records))
	return is_new


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


## 스테이지마다 기록 파일을 따로 둔다(프로스트는 예전 이름 그대로 user://frost_records.json).
static func _path() -> String:
	return "user://%s_records.json" % GameData.stage
