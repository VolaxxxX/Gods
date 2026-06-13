extends RefCounted
## Tiny assertion base for headless tests. Subclasses implement run() and call
## check(). No external test framework (keeps the project dependency-free).

var total: int = 0
var failed: int = 0

func check(condition: bool, message: String) -> void:
	total += 1
	if condition:
		print("  ok   - %s" % message)
	else:
		failed += 1
		print("  FAIL - %s" % message)

func result() -> Dictionary:
	return {"total": total, "failed": failed}
