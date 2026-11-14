extends Node
## 그래픽 품질. "낮음"은 그림자를 가까이(20m)만 작은 그림자 맵으로 그리고, 눈을 줄이고, 3D 해상도를 낮춘다.
## (이 렌더러에서는 그림자를 아예 끄면 화면이 회색으로 어두워져서 끄지 않는다.)
## 고른 적이 없으면, 게임이 흐르기 시작하고 잠시 뒤 프레임을 재서 낮으면 저절로 "낮음"으로 바꾼다.
## 고른 값(또는 저절로 바뀐 값)은 user://에 남아 다음 판에도 쓴다.

signal changed(low: bool)
## 프레임이 낮아 저절로 "낮음"으로 바꿨다
signal auto_lowered

const PATH := "user://frost_settings.json"
## 시작하고 이만큼 지난 뒤부터 CHECK_TIME초 동안 프레임을 잰다
const CHECK_DELAY := 3.0
const CHECK_TIME := 5.0
## 평균 프레임이 이보다 낮으면 "낮음"으로 바꾼다
const LOW_FPS := 40.0
const SNOW_AMOUNT := 400
const LOW_SNOW_AMOUNT := 120
const LOW_3D_SCALE := 0.75
const SHADOW_DISTANCE := 40.0
const LOW_SHADOW_DISTANCE := 20.0
const SHADOW_MAP := 2048
const LOW_SHADOW_MAP := 1024

var low := false
var _main: Node3D
## 사람이 고른 적이 있거나 이미 한 번 쟀으면 true(다시 재지 않는다)
var _decided := false
var _wait := 0.0
var _frames := 0
var _check_start := 0


func setup(main: Node3D) -> void:
	_main = main
	var saved := _read()
	_decided = saved.get("decided", false)
	_apply(saved.get("low", false))


func set_low(value: bool) -> void:
	_decided = true
	_apply(value)
	_write()


func _apply(value: bool) -> void:
	low = value
	var sun: DirectionalLight3D = _main.get_node("Sun")
	sun.directional_shadow_max_distance = LOW_SHADOW_DISTANCE if low else SHADOW_DISTANCE
	RenderingServer.directional_shadow_atlas_set_size(LOW_SHADOW_MAP if low else SHADOW_MAP, true)
	var snow: CPUParticles3D = _main.get_node("Snow")
	snow.amount = LOW_SNOW_AMOUNT if low else SNOW_AMOUNT
	_main.get_viewport().scaling_3d_scale = LOW_3D_SCALE if low else 1.0
	changed.emit(low)


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
	if _frames / elapsed < LOW_FPS:
		_apply(true)
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
		file.store_string(JSON.stringify({"low": low, "decided": _decided}))
