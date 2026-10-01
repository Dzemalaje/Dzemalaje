extends SceneTree
## Headless test runner:
##   godot --headless --path sugarfall -s res://tests/test_runner.gd
## Exits with code 1 if any test fails.

const TESTS := [
	"res://tests/test_match_finder.gd",
	"res://tests/test_board_resolver.gd",
	"res://tests/test_obstacles.gd",
]


func _initialize() -> void:
	var total := 0
	var failed := 0
	for path in TESTS:
		var t = load(path).new()
		for m in t.get_method_list():
			var method: String = m.name
			if not method.begins_with("test_"):
				continue
			t.current = "%s::%s" % [path.get_file(), method]
			var before: int = t.failures.size()
			t.call(method)
			total += 1
			if t.failures.size() > before:
				failed += 1
		for f in t.failures:
			printerr("FAIL " + f)
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
