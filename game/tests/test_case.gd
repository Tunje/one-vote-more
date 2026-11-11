class_name TestCase
extends RefCounted
## Minimal test base. Methods named test_* are run by tests/run_tests.gd, each on a fresh instance.

var failures: Array = []


## Per-process save path. user:// is shared by every concurrent test run (three sessions run the suite in
## parallel), so tests must never share files across processes.
static func save_path(file_name: String) -> String:
	return "user://test_saves/%d/%s" % [OS.get_process_id(), file_name]


func check(cond: bool, msg: String = "check failed") -> void:
	if not cond:
		failures.append(msg)


func check_eq(a, b, msg: String = "") -> void:
	if typeof(a) != typeof(b) or a != b:
		failures.append("%s expected <%s> got <%s>" % [msg, str(b), str(a)])
