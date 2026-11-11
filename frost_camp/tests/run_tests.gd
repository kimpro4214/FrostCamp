extends SceneTree
## 헤드리스 테스트 러너. 하나라도 실패하면 exit 1.
## 실행: godot --headless -s res://frost_camp/tests/run_tests.gd

const TEST_DIR := "res://frost_camp/tests/"


func _initialize() -> void:
	var total := 0
	var failed := 0
	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var suite: Object = load(TEST_DIR + file).new()
		for method in suite.get_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			total += 1
			suite.failures.clear()
			suite.call(test_name)
			if suite.failures.is_empty():
				print("  ok    %s::%s" % [file, test_name])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [file, test_name])
				for message in suite.failures:
					print("        - " + message)
	print("%d개 중 %d개 통과" % [total, total - failed])
	quit(1 if failed > 0 else 0)
