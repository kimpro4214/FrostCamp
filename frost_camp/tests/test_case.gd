extends RefCounted
## 테스트 스위트의 기반. test_*.gd 파일은 이 스크립트를 extends 하고 test_* 메서드를 만든다.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (기대 %s, 실제 %s)" % [message, expected, actual])
