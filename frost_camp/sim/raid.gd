class_name Raid
extends RefCounted
## 습격 웨이브 진행. 서식지를 연 뒤 start_delay초가 지나면 interval초마다 경고가 뜨고,
## warning초 뒤 곰 무리가 스폰 지점 하나에서 나온다. 무리를 다 잡아야 다음 웨이브 시계가 돈다.

enum State { DORMANT, WAITING, WARNING, ATTACKING }

var config: Dictionary
var spawns: Array[Vector2] = []
var state := State.DORMANT
## 다음 단계까지 남은 시간(대기 중이면 경고까지, 경고 중이면 습격까지)
var time_left := 0.0
## 지금까지 시작된 웨이브 수. 첫 웨이브가 1이다.
var wave := 0
var spawn_pos := Vector2.ZERO
var bears: Array[RaidBear] = []


func _init(raid_config: Dictionary, spawn_points: Array[Vector2]) -> void:
	config = raid_config
	spawns = spawn_points


## 서식지를 열면 부른다. 첫 경고까지 시계가 돌기 시작한다.
func activate() -> void:
	if state == State.DORMANT:
		state = State.WAITING
		time_left = float(config.start_delay)


func alive_count() -> int:
	var count := 0
	for bear in bears:
		if bear.is_alive():
			count += 1
	return count


## 웨이브 n에 나올 곰 수와 체력
func wave_count(n: int) -> int:
	return mini(int(config.count_base) + int(config.count_growth) * (n - 1), int(config.count_max))


func wave_hp(n: int) -> int:
	return int(config.hp_base) + int(config.hp_growth) * (n - 1)


## 상태가 바뀌면 그 이름을 돌려준다("warning", "attack", "cleared"). 아니면 빈 문자열.
func tick(delta: float, rng: RandomNumberGenerator) -> String:
	match state:
		State.WAITING:
			time_left -= delta
			if time_left <= 0.0:
				state = State.WARNING
				time_left = float(config.warning)
				spawn_pos = spawns[rng.randi() % spawns.size()]
				return "warning"
		State.WARNING:
			time_left -= delta
			if time_left <= 0.0:
				wave += 1
				state = State.ATTACKING
				bears.clear()
				for i in wave_count(wave):
					var offset := Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
					bears.append(RaidBear.new(spawn_pos + offset, wave_hp(wave), float(config.speed)))
				return "attack"
		State.ATTACKING:
			if alive_count() == 0:
				state = State.WAITING
				time_left = float(config.interval)
				return "cleared"
	return ""
