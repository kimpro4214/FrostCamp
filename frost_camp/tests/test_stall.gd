extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_stall() -> Stall:
	return Stall.new("log", Vector2.ZERO, Vector2(0, 3), Fixtures.balance())


func test_customers_queue_up_to_max() -> void:
	var stall := _make_stall()
	for i in 4:
		stall.tick(1.0)
	check_eq(stall.queue.size(), 3, "줄은 queue_max까지만 선다")


func test_customer_leaves_when_patience_runs_out() -> void:
	var stall := _make_stall()
	stall.tick(1.0)
	check_eq(stall.queue.size(), 1, "손님 한 명이 온다")
	stall.queue_max = 1
	for i in 5:
		stall.tick(1.0)
	check_eq(stall.left_angry, 1, "재고 없이 인내심이 다하면 화내고 떠난다")


func test_sells_stock_to_front_customer() -> void:
	var stall := _make_stall()
	stall.stock = 2
	stall.tick(1.0)
	stall.tick(0.5)
	check_eq(stall.stock, 1, "재고 하나가 팔린다")
	check_eq(stall.cash, 5, "가격만큼 돈이 쌓인다")
	check_eq(stall.served, 1, "손님 한 명이 사 간다")
