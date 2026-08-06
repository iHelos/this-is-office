extends RefCounted
## Pins the investigations path: clue gathering and incident closure.
##
## Incidents are spawned by the scenario (day 4 onward); troubleshooters gather
## clues against the incident severity, and once clues reach the total the
## incident opens to closing choices that trade budget/standing/power. The suite
## forces the state forward so it does not depend on a lucky roll: it assigns a
## senior troubleshooter repeatedly until the incident is deducing, then closes
## it and checks the consequences landed.

func run(t: TestCase) -> void:
	_incident_spawns_on_day_4(t)
	_gather_clues_advances_deduction(t)
	_close_incident_applies_choice_and_marks_closed(t)


func _reach_day_4() -> void:
	Game.start_new_game(42)
	# Roll forward to the morning of day 4, where the scenario spawns the first
	# incident (see content/scenario.json).
	while Game.current_day() < 4:
		Game.end_day_with_staged_rest()


func _incident_spawns_on_day_4(t: TestCase) -> void:
	_reach_day_4()
	t.ok(not Game.state.incidents.is_empty(), "day 4 spawns at least one incident")
	var inc: Incident = Game.state.incidents[0]
	t.eq(inc.state, "open", "a fresh incident starts open")
	t.eq(inc.clues_found, 0, "a fresh incident starts with no clues")


func _gather_clues_advances_deduction(t: TestCase) -> void:
	_reach_day_4()
	var inc: Incident = Game.state.incidents[0]
	# Find a troubleshooter in the roster; the starter crew has two.
	var ts_ids: Array = []
	for e: Employee in Game.state.employees:
		if e.role == "troubleshooter" and e.employed:
			ts_ids.append(e.id)
	t.ok(not ts_ids.is_empty(), "the roster has at least one troubleshooter")
	# Gather repeatedly (across many days, since each action is one pass) until
	# the incident flips to deducing. Bound the loop so a logic bug fails fast
	# instead of hanging.
	var safety := 200
	while inc.state == "open" and safety > 0:
		Game.assign_troubleshooters(inc.id, ts_ids)
		if inc.clues_found >= inc.clues_total:
			break
		# advance the day so the per-day RNG fork moves and clues keep coming
		Game.end_day_with_staged_rest()
		# the incident object identity may change after end_day clones state
		inc = _first_open_incident()
		if inc == null:
			break
		safety -= 1
	t.ok(inc != null and inc.state == "deducing", "gathering enough clues flips the incident to deducing")


func _close_incident_applies_choice_and_marks_closed(t: TestCase) -> void:
	_reach_day_4()
	var inc: Incident = _force_to_deducing()
	t.ok(inc != null, "an incident was forced to deducing")
	if inc == null:
		return
	var budget_before: int = Game.budget()
	# 'sell' pays the most and shifts standing; pick it and assert money landed.
	t.ok(Game.close_incident(inc.id, "sell"), "close_incident with 'sell' succeeds")
	t.eq(inc.state, "closed", "the incident is closed after a choice")
	t.ok(Game.budget() > budget_before, "the 'sell' choice pays into the budget")
	# Closing again is a no-op: the incident is no longer deducing.
	t.ok(not Game.close_incident(inc.id, "sell"), "closing a closed incident is rejected")


func _force_to_deducing() -> Incident:
	var ts_ids: Array = []
	for e: Employee in Game.state.employees:
		if e.role == "troubleshooter" and e.employed:
			ts_ids.append(e.id)
	var safety := 200
	while safety > 0:
		var inc: Incident = _first_open_incident()
		if inc == null:
			return _first_deducing_incident()
		Game.assign_troubleshooters(inc.id, ts_ids)
		if inc.state == "deducing":
			return inc
		Game.end_day_with_staged_rest()
		safety -= 1
	return _first_deducing_incident()


func _first_open_incident() -> Incident:
	for inc: Incident in Game.state.incidents:
		if inc.state == "open":
			return inc
	return null


func _first_deducing_incident() -> Incident:
	for inc: Incident in Game.state.incidents:
		if inc.state == "deducing":
			return inc
	return null
