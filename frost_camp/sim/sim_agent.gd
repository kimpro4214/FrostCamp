class_name SimAgent
extends RefCounted
## sim이 근접 규칙을 판정하는 대상. 위치는 바깥(씬이나 봇)이 옮겨 준다.

var pos: Vector2
var stack: BackStack
var chop_timer := 0.0
var unload_timer := 0.0


func _init(start_pos: Vector2, stack_capacity: int) -> void:
	pos = start_pos
	stack = BackStack.new(stack_capacity)
