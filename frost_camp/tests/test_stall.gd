extends "res://frost_camp/tests/test_case.gd"

const Fixtures := preload("res://frost_camp/tests/fixtures.gd")


func _make_stall() -> Stall:
	return Stall.new("log", Vector2.ZERO, Vector2(0, 3), Fixtures.balance())


func test_customers_queue_up_to_max() -> void:
	var stall := _make_stall()
	for i in 5:
		stall.tick(1.0)
	check_eq(stall.queue, 3, "줄은 queue_max까지만 선다")


func test_customers_never_leave() -> void:
	var stall := _make_stall()
	for i in 63:
		stall.tick(1.0)
	check_eq(stall.queue, 3, "재고가 없어도 손님은 떠나지 않는다")


func test_queue_refills_after_sale() -> void:
	var stall := _make_stall()
	for i in 3:
		stall.tick(1.0)
	stall.stock = 1
	stall.tick(0.5)
	check_eq(stall.queue, 2, "사 간 손님은 줄에서 빠진다")
	stall.tick(1.0)
	check_eq(stall.queue, 3, "refill 간격 뒤 다음 손님이 채운다")


func test_sells_stock_to_front_customer() -> void:
	var stall := _make_stall()
	stall.stock = 2
	stall.tick(1.0)
	stall.tick(0.5)
	check_eq(stall.stock, 1, "재고 하나가 팔린다")
	check_eq(stall.cash, 5, "가격만큼 돈이 쌓인다")
	check_eq(stall.served, 1, "손님 한 명이 사 간다")
