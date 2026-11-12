class_name SimAgent
extends RefCounted
## sim이 근접 규칙을 판정하는 대상. 위치는 바깥(씬이나 봇)이 옮겨 준다.

var pos: Vector2
var stack: BackStack
var chop_timer := 0.0
var unload_timer := 0.0
var pickup_timer := 0.0
var attack_timer := 0.0
var max_hp: float
var hp: float
## 0보다 크면 곰에게 당해 멍한 상태. 싸우지 못하고 느려진다.
var dazed_left := 0.0
## 추위 게이지. 열원 밖에서 줄고 안에서 찬다. 0이면 얼어서 느려진다.
var max_warmth := 0.0
var warmth := 0.0


func _init(start_pos: Vector2, stack_capacity: int, agent_max_hp: float) -> void:
	pos = start_pos
	stack = BackStack.new(stack_capacity)
	max_hp = agent_max_hp
	hp = agent_max_hp
