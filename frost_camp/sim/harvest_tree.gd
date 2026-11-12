class_name HarvestTree
extends RefCounted
## 나무 한 그루. 정해진 타수를 채우면 쓰러지고, 시간이 지나면 다시 자란다.

var pos: Vector2
var hits_to_fell: int
var respawn_time: float
var hits := 0
var respawn_left := 0.0
## 비어 있지 않으면 이 이름이 해금되어야 벨 수 있다(확장 땅의 숲).
var unlock := ""


func _init(tree_pos: Vector2, config: Dictionary) -> void:
	pos = tree_pos
	hits_to_fell = int(config.hits_to_fell)
	respawn_time = float(config.respawn_time)


func is_standing() -> bool:
	return respawn_left <= 0.0


## damage만큼 친다. 이번 타격으로 쓰러지면 true.
func hit(damage: int = 1) -> bool:
	hits += damage
	if hits < hits_to_fell:
		return false
	hits = 0
	respawn_left = respawn_time
	return true


func tick(delta: float) -> void:
	respawn_left = maxf(respawn_left - delta, 0.0)
