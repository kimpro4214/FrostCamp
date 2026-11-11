class_name Worker
extends SimAgent
## 고용한 일꾼. 역할(lumberjack, porter, cashier)에 따라 worker_brain이 목표를 정한다.
## 플레이어처럼 위치는 바깥이 옮기고, 근접 규칙은 sim이 판정한다.

var role: String
var speed: float
var damage: int
## 이번 프레임에 가려는 곳. {"kind": String, "pos": Vector2, "stop": float}
var target := {}
## 짐을 다 내릴 때까지 배달 중인지
var delivering := false


func _init(worker_role: String, start_pos: Vector2, config: Dictionary) -> void:
	super(start_pos, int(config.get("capacity", 0)), 1.0)
	role = worker_role
	speed = float(config.speed)
	damage = int(config.get("damage", 0))
	target = {"kind": "idle", "pos": start_pos, "stop": 0.0}
