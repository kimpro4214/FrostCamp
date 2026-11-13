class_name RaidBear
extends RefCounted
## 습격 웨이브의 곰 한 마리. 기지의 멀쩡한 시설로 곧장 걸어가 부순다. 쓰러지면 다시 나오지 않는다.

var pos: Vector2
var max_hp: int
var hp: int
var speed: float
var attack_timer := 0.0
## 지금 노리는 시설 번호(sim.structures). 없으면 -1.
var target := -1
## 방벽을 뚫었는지. 뚫은 뒤에는 방벽을 더 노리지 않고 안쪽 시설로 간다.
var breached := false
## 이 곰이 노리는 길목 방벽 구간(시설 번호). 없으면 -1.
var gate := -1


func _init(spawn_pos: Vector2, bear_hp: int, bear_speed: float) -> void:
	pos = spawn_pos
	max_hp = bear_hp
	hp = bear_hp
	speed = bear_speed


func is_alive() -> bool:
	return hp > 0


## damage만큼 맞는다. 이번 공격으로 쓰러지면 true.
func take_hit(damage: int) -> bool:
	if not is_alive():
		return false
	hp = maxi(hp - damage, 0)
	return hp == 0
