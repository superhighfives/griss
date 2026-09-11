extends SceneTree

## Headless test runner. Collects every res://tests/test_*.gd script, runs each
## func test_*() on it, prints failures, and exits non-zero if any failed.
## Run with:
##   godot --headless --path . --script res://tests/run_tests.gd


func _initialize() -> void:
	var test_dir_path: String = "res://tests"
	var dir: DirAccess = DirAccess.open(test_dir_path)
	if dir == null:
		push_error("Could not open tests directory")
		quit(1)
		return

	var test_files: Array[String] = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			test_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	test_files.sort()

	var total_passed: int = 0
	var total_failed: int = 0
	var failures: Array[String] = []

	for file_name_iter in test_files:
		var script: GDScript = load("%s/%s" % [test_dir_path, file_name_iter])
		var instance: Object = script.new()
		for method in instance.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var full_name: String = "%s::%s" % [file_name_iter, method_name]
			var error: String = ""
			if instance.has_method("before_each"):
				instance.call("before_each")
			var ok: bool = instance.callv(method_name, [])
			if ok == null:
				ok = true
			if ok:
				total_passed += 1
			else:
				total_failed += 1
				error = instance.get("last_error") if instance.get("last_error") != null else "assertion failed"
				failures.append("%s: %s" % [full_name, error])

	print("Passed: %d, Failed: %d" % [total_passed, total_failed])
	if not failures.is_empty():
		print("Failures:")
		for failure in failures:
			print("  - %s" % failure)
		quit(1)
	else:
		quit(0)
