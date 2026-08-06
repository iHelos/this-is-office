class_name TestCase
extends RefCounted
## A test framework small enough to read in one sitting.
##
## No third-party dependency on purpose: this repo will be built in CI on three
## platforms and the one thing that must never be the reason a build breaks is
## the test harness. Suites are plain scripts with a [code]run(t)[/code] method,
## the runner is a scene, and the whole thing is about a hundred lines.
##
## Note that autoloads (`Palette`, `Slots`) do NOT exist when Godot is invoked
## with [code]--script[/code]; the runner is therefore a scene. See tests/README.

var checks: int = 0
var failures: PackedStringArray = PackedStringArray()
var _suite: String = ""


func begin(suite_name: String) -> void:
	_suite = suite_name


func fail(message: String) -> void:
	failures.append("%s: %s" % [_suite, message])


func ok(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		fail(message)
	return condition


func eq(actual: Variant, expected: Variant, message: String) -> bool:
	return ok(actual == expected, "%s (got %s, expected %s)" % [message, actual, expected])


func ne(actual: Variant, unexpected: Variant, message: String) -> bool:
	return ok(actual != unexpected, "%s (got %s, which it should not be)" % [message, actual])


func approx(actual: float, expected: float, epsilon: float, message: String) -> bool:
	return ok(absf(actual - expected) <= epsilon,
		"%s (got %.6f, expected %.6f +/- %.6f)" % [message, actual, expected, epsilon])


func less(a: float, b: float, message: String) -> bool:
	return ok(a < b, "%s (%.6f is not less than %.6f)" % [message, a, b])


func finite(v: Variant, message: String) -> bool:
	if v is Vector2:
		var p: Vector2 = v
		return ok(is_finite(p.x) and is_finite(p.y), "%s (got %s)" % [message, p])
	return ok(is_finite(float(v)), "%s (got %s)" % [message, v])
