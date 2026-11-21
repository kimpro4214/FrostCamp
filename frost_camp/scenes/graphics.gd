extends Node
## 그래픽 품질 상·중·하. 사양이 낮은 기기에서도 돌아가게 단계별로 모델과 효과를 줄인다.
## - 상: 모든 모델이 원래(고폴리) 모델이다.
## - 중: 여럿이 한꺼번에 보이는 일꾼·손님·포탑은 저폴리 모델(theme.json의 low)로 바꾼다. 주인공과 가방은 원래 모델이다.
## - 하: 저폴리 모델이 있으면 모두 바꾸고, 그림자를 가까이(20m)만 작은 그림자 맵으로 그리고, 눈을 줄이고, 3D 해상도를 낮춘다.
##   (이 렌더러에서는 그림자를 아예 끄면 화면이 회색으로 어두워져서 끄지 않는다.)
## 모델을 쓰는 화면은 "graphics_models" 그룹에 들어가 refresh_models()로 단계가 바뀐 것을 받는다.
## 고른 적이 없으면, 게임이 흐르기 시작하고 잠시 뒤 프레임을 재서 낮으면 저절로 "하"로 바꾼다.
## 고른 값(또는 저절로 바뀐 값)은 user://에 남아 다음 판에도 쓴다.

signal changed(level: int)
## 프레임이 낮아 저절로 "하"로 바꿨다
signal auto_lowered

enum { LOW, MID, HIGH }
const NAMES := ["하", "중", "상"]
const PATH := "user://frost_settings.json"
const GROUP := "graphics_models"
## 시작하고 이만큼 지난 뒤부터 CHECK_TIME초 동안 프레임을 잰다
const CHECK_DELAY := 3.0
const CHECK_TIME := 5.0
## 평균 프레임이 이보다 낮으면 "하"로 바꾼다
const LOW_FPS := 40.0
const SNOW_AMOUNT := 400
const LOW_SNOW_AMOUNT := 120
const LOW_3D_SCALE := 0.75
const SHADOW_DISTANCE := 40.0
const LOW_SHADOW_DISTANCE := 20.0
const SHADOW_MAP := 2048
const LOW_SHADOW_MAP := 1024

## 지금 단계. 모델을 고르는 화면이 model()로 읽는다.
static var level := MID

var _main: Node3D
## 사람이 고른 적이 있거나 이미 한 번 쟀으면 true(다시 재지 않는다)
var _decided := false
var _wait := 0.0
var _frames := 0
var _check_start := 0


## 지금 단계에서 쓸 모델 경로. lead는 주인공처럼 하나뿐인 모델로, "하"에서만 저폴리로 바꾼다.
static func model(path: String, lead: bool = false) -> String:
	var low: Dictionary = GameData.theme().get("low", {})
	if not low.has(path) or level == HIGH or (level == MID and lead):
		return path
	return low[path]


func setup(main: Node3D) -> void:
	_main = main
	var saved := _read()
	_decided = saved.get("decided", false)
	# 예전 설정(보통/낮음)은 중/하로 읽는다.
	var saved_level: int = saved.get("level", LOW if saved.get("low", false) else MID)
	_apply(clampi(saved_level, LOW, HIGH))


func set_level(value: int) -> void:
	_decided = true
	_apply(value)
	_write()


func _apply(value: int) -> void:
	var models_changed := value != level
	level = value
	var low := level == LOW
	var sun: DirectionalLight3D = _main.get_node("Sun")
	sun.directional_shadow_max_distance = LOW_SHADOW_DISTANCE if low else SHADOW_DISTANCE
	RenderingServer.directional_shadow_atlas_set_size(LOW_SHADOW_MAP if low else SHADOW_MAP, true)
	var snow: CPUParticles3D = _main.get_node("Snow")
	snow.amount = LOW_SNOW_AMOUNT if low else SNOW_AMOUNT
	_main.get_viewport().scaling_3d_scale = LOW_3D_SCALE if low else 1.0
	if models_changed:
		get_tree().call_group(GROUP, "refresh_models")
	changed.emit(level)


func _process(delta: float) -> void:
	if _decided or not _main.started or get_tree().paused:
		return
	_wait += delta
	if _wait < CHECK_DELAY:
		return
	if _frames == 0:
		_check_start = Time.get_ticks_msec()
	_frames += 1
	var elapsed := (Time.get_ticks_msec() - _check_start) / 1000.0
	if elapsed < CHECK_TIME:
		return
	_decided = true
	if _frames / elapsed < LOW_FPS and level != LOW:
		_apply(LOW)
		auto_lowered.emit()
	_write()


func _read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text()) if file else null
	return data if data is Dictionary else {}


func _write() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"level": level, "decided": _decided}))
