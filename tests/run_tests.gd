extends SceneTree
## Headless test runner:  godot --headless --path . -s tests/run_tests.gd
## Exits 1 if any test fails or a test function aborts.

const TEST_FILES: Array[String] = [
	"res://tests/test_sim.gd",
	"res://tests/test_hunter.gd",
]

var passed := 0
var failed := 0
var _done := false


func _initialize() -> void:
	for path in TEST_FILES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed += 1
			push_error("FAIL %s: does not load (parse error?)" % path)
			continue
		var suite: Object = script.new()
		suite.set("runner", self)
		for m: Dictionary in suite.get_method_list():
			var test_name: String = m.name
			if not test_name.begins_with("test_"):
				continue
			if suite.call(test_name) != true:
				failed += 1
				push_error("FAIL %s: did not finish (runtime error?)" % test_name)
	print("Results: %d passed, %d failed" % [passed, failed])
	_done = true
	quit(1 if failed > 0 else 0)


## Only reached when _initialize stopped on an error: fail rather than hang.
func _process(_delta: float) -> bool:
	if not _done:
		push_error("FAIL: the test run stopped early (script error above)")
		quit(1)
	return false


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)
