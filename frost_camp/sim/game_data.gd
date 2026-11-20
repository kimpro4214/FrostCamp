class_name GameData
extends RefCounted
## data/ 폴더의 JSON 로더. 노드에 의존하지 않아서 게임과 봇이 같은 데이터를 읽는다.
## 스테이지마다 data/stages/<스테이지>/ 아래에 balance·layout·text.json을 둔다. 규칙(sim)은 모든 스테이지가 같다.

## 지금 판의 스테이지
static var stage := "frost"


## 지금 스테이지의 데이터 파일 경로. file은 "balance", "layout", "text".
static func path(file: String) -> String:
	return "res://frost_camp/data/stages/%s/%s.json" % [stage, file]


static func load_json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("데이터 파일을 읽을 수 없음: %s" % path)
		return {}
	return data
