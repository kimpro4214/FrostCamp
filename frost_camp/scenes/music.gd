extends AudioStreamPlayer
## 배경음. Music 버스로 한 곡을 반복해서 튼다. 습격 중에는 조금 크고 빠르게, 끝나면 원래대로 돌아간다.
## 곡 파일이 없으면 조용히 아무것도 하지 않는다. 반복은 가져오기 설정(edit/loop_mode)이 맡는다.

const TRACK := "res://frost_camp/assets/music/bgm.wav"
const CALM_DB := -10.0
const RAID_DB := -6.0
const RAID_PITCH := 1.06
const BLEND_TIME := 1.2

var sim: FrostSim
var _raiding := false


func setup(frost_sim: FrostSim) -> void:
	sim = frost_sim
	bus = &"Music"
	if not ResourceLoader.exists(TRACK):
		return
	var track: AudioStream = load(TRACK)
	stream = track
	volume_db = CALM_DB
	play()


func _process(_delta: float) -> void:
	if stream == null:
		return
	var raiding := sim.raid.state == Raid.State.ATTACKING
	if raiding == _raiding:
		return
	_raiding = raiding
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "volume_db", RAID_DB if raiding else CALM_DB, BLEND_TIME)
	tween.tween_property(self, "pitch_scale", RAID_PITCH if raiding else 1.0, BLEND_TIME)
