class_name HarvestBear
extends RefCounted
## 북극곰 한 마리. 서식지 안을 배회하고, 체력이 다하면 쓰러졌다가 스폰 지점에서 다시 나타난다.
## 서식지 안에는 장애물이 없어서 길찾기 없이 sim이 직접 움직인다.

var spawn: Vector2
var area: Rect2
var pos: Vector2
var max_hp: int
var hp: int
var speed: float
var respawn_time: float
var respawn_left := 0.0
var attack_timer := 0.0
var _wander_target: Vector2


func _init(spawn_pos: Vector2, home_area: Rect2, config: Dictionary) -> void:
	spawn = spawn_pos
	area = home_area
	pos = spawn_pos
	_wander_target = spawn_pos
	max_hp = int(config.hp)
	hp = max_hp
	speed = float(config.wander_speed)
	respawn_time = float(config.respawn_time)


func is_alive() -> bool:
	return respawn_left <= 0.0


## damage만큼 맞는다. 이번 공격으로 쓰러지면 true.
func take_hit(damage: int) -> bool:
	hp -= damage
	if hp > 0:
		return false
	respawn_left = respawn_time
	attack_timer = 0.0
	return true


## 싸우는 중이 아니면 배회한다. 쓰러져 있으면 리스폰을 기다린다.
func tick(delta: float, fighting: bool, rng: RandomNumberGenerator) -> void:
	if not is_alive():
		respawn_left -= delta
		if respawn_left <= 0.0:
			respawn_left = 0.0
			hp = max_hp
			pos = spawn
			_wander_target = spawn
		return
	if fighting:
		return
	attack_timer = 0.0
	if pos.distance_to(_wander_target) < 0.1:
		_wander_target = Vector2(
			rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y, area.end.y))
	pos = pos.move_toward(_wander_target, speed * delta)
