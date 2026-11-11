class_name Balance
extends RefCounted
## balance.json 로더. 노드에 의존하지 않아서 게임과 봇이 같은 수치를 읽는다.

const DEFAULT_PATH := "res://frost_camp/data/balance.json"


static func load_file(path: String = DEFAULT_PATH) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("balance 파일을 읽을 수 없음: %s" % path)
		return {}
	return data
