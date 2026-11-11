class_name GameData
extends RefCounted
## data/ 폴더의 JSON 로더. 노드에 의존하지 않아서 게임과 봇이 같은 데이터를 읽는다.

const BALANCE_PATH := "res://frost_camp/data/balance.json"
const LAYOUT_PATH := "res://frost_camp/data/layout.json"


static func load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("데이터 파일을 읽을 수 없음: %s" % path)
		return {}
	return data
