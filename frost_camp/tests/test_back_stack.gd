extends "res://frost_camp/tests/test_case.gd"


func test_push_stops_at_capacity() -> void:
	var stack := BackStack.new(2)
	check(stack.push("log"), "빈 칸이 있으면 쌓인다")
	check(stack.push("log"), "빈 칸이 있으면 쌓인다")
	check(not stack.push("log"), "가득 차면 더 쌓이지 않는다")
	check_eq(stack.items.size(), 2, "용량만큼만 들고 있다")
	check_eq(stack.free_space(), 0, "남은 칸")


func test_take_removes_topmost_matching_item() -> void:
	var stack := BackStack.new(5)
	stack.push("log")
	stack.push("meat")
	stack.push("log")
	stack.push("meat")
	check(stack.take("log"), "같은 종류가 있으면 꺼낸다")
	check_eq(stack.items, ["log", "meat", "meat"] as Array[String], "가장 위의 원목이 빠진다")
	check(not stack.take("hide"), "없는 종류는 꺼낼 수 없다")
