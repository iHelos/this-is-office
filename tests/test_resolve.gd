extends RefCounted
## Pins the ticket-resolution formula (docs/design.md §4).
##
## The exact numbers are not sacred — they are tuned in content/balance.json —
## but the *shape* is: more skill raises the clean chance, fatigue lowers it,
## loyalty lowers it, an empty assignment always fails, and the chance is
## clamped to the configured floor and ceiling.

func run(t: TestCase) -> void:
	_more_skill_raises_clean_chance(t)
	_fatigue_lowers_clean_chance(t)
	_disloyalty_lowers_clean_chance(t)
	_empty_assignment_always_fumbles(t)
	_chance_clamped_to_ceiling(t)
	_clean_grants_xp_fumble_does_not(t)
	_resolved_state_labelled(t)


func _make_employee(xp: int, fatigue: float, loyalty: float) -> Employee:
	var e := Employee.new()
	e.id = "e_%d_%d_%d" % [xp, int(fatigue * 100), int((loyalty + 1) * 100)]
	e.xp = xp
	e.fatigue = fatigue
	e.loyalty = loyalty
	e.employed = true
	return e


func _more_skill_raises_clean_chance(t: TestCase) -> void:
	var r := Resolve.new()
	var weak := [_make_employee(100, 0.0, 0.0)]
	var strong := [_make_employee(1000, 0.0, 0.0)]
	t.less(r.clean_chance(weak, 200), r.clean_chance(strong, 200),
		"higher xp yields a higher clean chance against the same severity")


func _fatigue_lowers_clean_chance(t: TestCase) -> void:
	var r := Resolve.new()
	var fresh := [_make_employee(500, 0.0, 0.0)]
	var tired := [_make_employee(500, 1.0, 0.0)]
	t.less(r.clean_chance(tired, 200), r.clean_chance(fresh, 200),
		"a fully fatigued team has a lower clean chance than a fresh one")


func _disloyalty_lowers_clean_chance(t: TestCase) -> void:
	var r := Resolve.new()
	var devoted := [_make_employee(500, 0.0, 1.0)]
	var hostile := [_make_employee(500, 0.0, -1.0)]
	t.less(r.clean_chance(hostile, 200), r.clean_chance(devoted, 200),
		"a hostile team has a lower clean chance than a devoted one")


func _empty_assignment_always_fumbles(t: TestCase) -> void:
	var r := Resolve.new()
	t.eq(r.clean_chance([], 200), 0.0, "an empty assignment has zero clean chance")
	var ticket := Ticket.new()
	ticket.id = "t_empty"
	ticket.severity = 100
	var rng := Rng.new(1)
	var result: Dictionary = r.resolve_ticket(ticket, [], rng)
	t.ok(not bool(result["clean"]), "an empty assignment always fumbles")


func _chance_clamped_to_ceiling(t: TestCase) -> void:
	var r := Resolve.new()
	# Overwhelming skill against trivial severity must hit the ceiling, not 1.0.
	var overwhelming := [_make_employee(100000, 0.0, 1.0)]
	var chance: float = r.clean_chance(overwhelming, 1)
	t.ok(chance <= r.var_ceil_chance + 1e-6, "clean chance respects the ceiling")
	t.ok(chance > 0.9, "overwhelming skill gets near-certain success")


func _clean_grants_xp_fumble_does_not(t: TestCase) -> void:
	var r := Resolve.new()
	var primary := _make_employee(100, 0.0, 0.0)
	var backup := _make_employee(100, 0.0, 0.0)
	# Two assignees: the first is primary (team size 2 -> half = 1 primary).
	var ticket := Ticket.new()
	ticket.id = "t_xp"
	ticket.severity = 1   # trivial severity so the roll is overwhelmingly clean
	# Roll many times; at least one clean should occur at severity 1 with two
	# decently-skilled assignees, exercising the xp award path.
	var any_xp := false
	for seed: int in 100:
		var rng := Rng.new(seed)
		var result: Dictionary = r.resolve_ticket(ticket, [primary, backup], rng)
		if bool(result["clean"]):
			var awards: Dictionary = result["xp_awards"]
			t.ok(awards.has(primary.id) or awards.has(backup.id), "a clean solve awards xp to an assignee")
			any_xp = true
			break
	# Fumble case: severity far above skill should fumble and award no xp.
	var hard := Ticket.new()
	hard.id = "t_hard"
	hard.severity = 100000
	var rng2 := Rng.new(1)
	var fumble: Dictionary = r.resolve_ticket(hard, [primary], rng2)
	if not bool(fumble["clean"]):
		t.eq((fumble["xp_awards"] as Dictionary).size(), 0, "a fumble awards no xp")
	if any_xp:
		t.ok(true, "clean-solve xp path was exercised")
	else:
		t.ok(false, "expected at least one clean solve in 100 seeds at trivial severity")


func _resolved_state_labelled(t: TestCase) -> void:
	var r := Resolve.new()
	var ticket := Ticket.new()
	ticket.id = "t_label"
	ticket.severity = 100000
	var rng := Rng.new(1)
	var result: Dictionary = r.resolve_ticket(ticket, [_make_employee(10, 0.0, 0.0)], rng)
	# Hard severity with weak skill: fumbled. State string must match the label.
	var state: String = String(result["final_state"])
	t.ok(state == "clean" or state == "fumbled", "final_state is clean or fumbled")
