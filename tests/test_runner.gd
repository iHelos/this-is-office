extends Node
## Runs every suite and exits non-zero on failure, so CI can gate on it.
##
## Run with:
## [codeblock]
## godot --headless --path . res://tests/test_runner.tscn
## [/codeblock]
## A scene, not a [code]--script[/code] entry point, because GDScript does not
## resolve autoload identifiers in the latter and several suites lean on the
## autoloaded contracts.

const SUITES := [
	"res://tests/test_rng.gd",
	"res://tests/test_l10n.gd",
	"res://tests/test_resolve.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_sim.gd",
	"res://tests/test_scenario.gd",
	"res://tests/test_game.gd",
	"res://tests/test_personnel.gd",
	"res://tests/test_economy_ui.gd",
	"res://tests/test_investigations.gd",
	"res://tests/test_narrative.gd",
	"res://tests/test_cutscenes.gd",
	"res://tests/test_chapters.gd",
]


func _ready() -> void:
	# Let SceneTree finish attaching the runner before suites execute. Most unit
	# tests do not care, but playable-scene smoke tests must be allowed to add a
	# temporary scene to the root without hitting "parent is busy".
	await get_tree().process_frame
	var t := TestCase.new()
	var started := Time.get_ticks_msec()
	for path: String in SUITES:
		t.begin(path.get_file().get_basename())
		var script: GDScript = load(path)
		# A suite with a parse error still loads as a non-null GDScript whose
		# new() fails, so both have to be checked or the runner dies instead of
		# reporting.
		if script == null or not script.can_instantiate():
			t.fail("suite failed to compile")
			continue
		var suite: Object = script.new()
		if suite == null:
			t.fail("suite could not be instantiated")
			continue
		suite.call("run", t)

	var elapsed := Time.get_ticks_msec() - started
	if t.failures.is_empty():
		print("PASS  %d checks in %d suites (%d ms)" % [t.checks, SUITES.size(), elapsed])
		get_tree().quit(0)
		return
	for f: String in t.failures:
		printerr("FAIL  %s" % f)
	printerr("FAIL  %d of %d checks failed" % [t.failures.size(), t.checks])
	get_tree().quit(1)
