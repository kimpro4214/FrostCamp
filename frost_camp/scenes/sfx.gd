extends Node
## 효과음 재생기. 이름별로 여러 소리를 준비해 두고 무작위로 골라 피치를 조금씩 바꿔 튼다.
## 쿼터뷰라 위치 소리 대신, 플레이어와의 거리로 볼륨을 줄이고 멀면 아예 틀지 않는다.

const DIR := "res://frost_camp/assets/sounds/"
## 이름 → [소리 파일들, 기본 볼륨(dB), 같은 소리 최소 간격(초)]
const SOUNDS := {
	"chop": [["impact/impactWood_medium_000", "impact/impactWood_medium_001", "impact/impactWood_medium_002",
		"impact/impactWood_medium_003", "impact/impactWood_medium_004", "rpg/chop"], -2.0, 0.05],
	"fell": [["impact/impactWood_heavy_000", "impact/impactWood_heavy_001", "impact/impactWood_heavy_002"], 2.0, 0.1],
	"punch": [["impact/impactPunch_medium_000", "impact/impactPunch_medium_001", "impact/impactPunch_medium_002",
		"impact/impactPunch_medium_003", "impact/impactPunch_medium_004"], -2.0, 0.05],
	"punch_heavy": [["impact/impactPunch_heavy_000", "impact/impactPunch_heavy_001", "impact/impactPunch_heavy_002"], 2.0, 0.1],
	"pickup": [["impact/impactPlank_medium_000", "impact/impactPlank_medium_001", "impact/impactPlank_medium_002"], -10.0, 0.07],
	"drop": [["interface/drop_001", "interface/drop_002", "interface/drop_003", "interface/drop_004"], -6.0, 0.07],
	"coins": [["rpg/handleCoins", "rpg/handleCoins2"], 0.0, 0.1],
	"pay": [["interface/tick_001", "interface/tick_002"], -10.0, 0.09],
	"purchase": [["interface/confirmation_001", "interface/confirmation_002"], 0.0, 0.1],
	"hire": [["jingles/jingles_PIZZI02"], -2.0, 0.5],
	"step": [["impact/footstep_snow_000", "impact/footstep_snow_001", "impact/footstep_snow_002",
		"impact/footstep_snow_003", "impact/footstep_snow_004"], -14.0, 0.15],
	"win": [["jingles/jingles_SAX01"], 0.0, 1.0],
	"crack": [["impact/impactPlank_medium_000", "impact/impactPlank_medium_001", "impact/impactPlank_medium_002"], 0.0, 0.06],
	"break": [["impact/impactWood_heavy_000", "impact/impactWood_heavy_001", "impact/impactWood_heavy_002"], 5.0, 0.2],
}
const VOICES := 16
const PITCH_JITTER := 0.08
## 이 거리(m)를 넘으면 들리지 않는다. 가까울수록 크게 들린다.
const HEAR_RADIUS := 16.0
const FAR_DB := -14.0

var sim: FrostSim
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played := {}


func setup(frost_sim: FrostSim) -> void:
	sim = frost_sim
	for sound_name in SOUNDS:
		var list: Array[AudioStream] = []
		for path in SOUNDS[sound_name][0]:
			list.append(load(DIR + path + ".ogg"))
		_streams[sound_name] = list
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)


## 플레이어 곁에서 나는 소리(UI, 내 행동).
func play(sound_name: String, extra_db := 0.0) -> void:
	var config: Array = SOUNDS[sound_name]
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(sound_name, -10.0) < config[2]:
		return
	_last_played[sound_name] = now
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	var list: Array = _streams[sound_name]
	player.stream = list[randi() % list.size()]
	player.volume_db = config[1] + extra_db
	player.pitch_scale = 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)
	player.play()


## 월드 어딘가에서 나는 소리. 플레이어에서 멀수록 작아지고, 너무 멀면 틀지 않는다.
func play_at(sound_name: String, pos: Vector2, extra_db := 0.0) -> void:
	var dist := pos.distance_to(sim.player.pos)
	if dist > HEAR_RADIUS:
		return
	play(sound_name, extra_db + FAR_DB * dist / HEAR_RADIUS)
