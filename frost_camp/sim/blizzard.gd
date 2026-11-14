class_name Blizzard
extends RefCounted
## 눈보라 이벤트(8차 QA 다음 개발). 모닥불(start_after 존)을 산 뒤 start_delay초가 지나면 interval초마다
## warning초 경고 뒤 duration초 동안 눈보라가 분다. 그동안 플레이어 추위가 cold_mult배 빨리 온다.
## 설정이 비어 있으면(테스트 지형 등) 오지 않는다.

enum State { DORMANT, WAITING, WARNING, ACTIVE }

var config: Dictionary
var state := State.DORMANT
## 다음 단계까지 남은 시간(대기 중이면 경고까지, 경고 중이면 시작까지, 부는 중이면 끝까지)
var time_left := 0.0


func _init(blizzard_config: Dictionary) -> void:
	config = blizzard_config


## ready는 시작 조건(모닥불을 샀는지). 상태가 바뀌면 "warning", "started", "ended"를 돌려준다.
func tick(delta: float, ready: bool) -> String:
	match state:
		State.DORMANT:
			if ready and not config.is_empty():
				state = State.WAITING
				time_left = float(config.start_delay)
		State.WAITING:
			time_left -= delta
			if time_left <= 0.0:
				state = State.WARNING
				time_left = float(config.warning)
				return "warning"
		State.WARNING:
			time_left -= delta
			if time_left <= 0.0:
				state = State.ACTIVE
				time_left = float(config.duration)
				return "started"
		State.ACTIVE:
			time_left -= delta
			if time_left <= 0.0:
				state = State.WAITING
				time_left = float(config.interval)
				return "ended"
	return ""


## 지금 추위가 빨라지는 배수(부는 중이 아니면 1)
func cold_mult() -> float:
	return float(config.cold_mult) if state == State.ACTIVE else 1.0
