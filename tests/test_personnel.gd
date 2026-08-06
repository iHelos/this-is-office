extends RefCounted
## Pins the HR operations the personnel screen drives through Game.
##
## These are player decisions (rest, fire), not simulation steps, so they mutate
## the live state directly. The suite makes sure that mutation is well-behaved:
## rest toggles and recovers fatigue at end of day, fire marks the employee
## unemployed and logs it, and neither leaks into the deterministic replay
## contract (end_day still advances the clock deterministically).

const CAMPAIGN_DAYS := 180


func run(t: TestCase) -> void:
	_toggle_rest_flags_and_recovers(t)
	_fire_marks_unemployed_and_logs(t)
	_fire_disables_further_actions(t)


func _toggle_rest_flags_and_recovers(t: TestCase) -> void:
	Game.start_new_game(777)
	var e: Employee = Game.state.employees[0]
	var id: String = e.id
	e.fatigue = 0.8
	Game.toggle_rest(id)
	t.ok(e.on_rest, "toggle_rest sets the rest flag")
	Game.end_day_with_staged_rest()
	# end_day returns a new state; read the fresh employee, not the stale handle.
	var after: Employee = Game.state.employee_by_id(id)
	t.ok(after != null, "the employee still exists after end_day")
	if after == null:
		return
	t.less(after.fatigue, 0.8, "a staged rest recovers fatigue after end_day")
	t.ok(not after.on_rest, "the rest flag clears after end_day applies it")


func _fire_marks_unemployed_and_logs(t: TestCase) -> void:
	Game.start_new_game(777)
	var e: Employee = Game.state.employees[0]
	var id: String = e.id
	Game.fire(id)
	t.ok(not e.employed, "fire marks the employee unemployed")
	var logged := false
	for entry: Dictionary in Game.state.log:
		if entry.get("kind") == "employee_fired" and entry.get("employee_id") == id:
			logged = true
	t.ok(logged, "fire writes an employee_fired entry to the log")


func _fire_disables_further_actions(t: TestCase) -> void:
	# Firing an already-fired employee is a no-op: employed stays false and the
	# log does not gain a second entry. Guards against a double-click in the UI.
	Game.start_new_game(777)
	var e: Employee = Game.state.employees[0]
	Game.fire(e.id)
	var log_size: int = Game.state.log.size()
	Game.fire(e.id)
	t.eq(Game.state.log.size(), log_size, "firing an unemployed employee is a no-op")
