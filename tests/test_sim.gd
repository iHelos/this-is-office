extends RefCounted
## Pins the load-bearing property of the whole project: determinism.
##
## The same seed and the same actions must produce the same next state, always,
## everywhere. If any of these fail, the core has become impure (a stray
## randf(), a wall-clock read, a mutation of the input state) and every replay
## the game promises is broken.

func run(t: TestCase) -> void:
	_same_seed_same_actions_same_state(t)
	_advance_does_not_mutate_input(t)
	_advance_increments_day(t)
	_advance_accrues_salaries(t)
	_assignment_with_no_skill_fumbles_and_penalizes(t)
	_rest_reduces_fatigue_next_day(t)
	_expired_ticket_penalizes(t)


func _fresh_state() -> GameState:
	# Two employees, one ticket on the board. Minimal, deterministic fixture.
	var s := GameState.initial(42, [
		{"id": "e1", "name": "Ann", "dept": "eng", "role": "dev", "xp": 300},
		{"id": "e2", "name": "Bob", "dept": "eng", "role": "dev", "xp": 50},
	], [
		{"id": "sand", "name_key": "faction.sand.name", "agenda": "faction.sand.agenda"},
		{"id": "varga", "name_key": "faction.varga.name", "agenda": "faction.varga.agenda"},
	])
	var tk := Ticket.new()
	tk.id = "t1"
	tk.kind = "bug"
	tk.severity = 200
	tk.reward = 500
	tk.penalty = 200
	tk.ttl = 1
	s.tickets.append(tk)
	return s


func _same_seed_same_actions_same_state(t: TestCase) -> void:
	var actions := {"assignments": [{"ticket_id": "t1", "employee_ids": ["e1", "e2"]}]}
	var a: Dictionary = Sim.advance(_fresh_state(), actions, Rng.new(42)).to_dict()
	var b: Dictionary = Sim.advance(_fresh_state(), actions, Rng.new(42)).to_dict()
	t.eq(a, b, "same seed + same actions produce identical next states")


func _advance_does_not_mutate_input(t: TestCase) -> void:
	# The input state must be untouched: Sim.advance returns a new state, it does
	# not patch in place. If this fails, replay and save/undo all break.
	var original := _fresh_state()
	var before: int = original.budget
	var before_day: int = original.day
	var before_ticket_state: String = (original.tickets[0] as Ticket).state
	# Discard the result on purpose: the point of this test is that advance does
	# not mutate the input, so we do not need the returned state.
	Sim.advance(original, {"assignments": []}, Rng.new(7))
	t.eq(original.budget, before, "input budget is unchanged after advance")
	t.eq(original.day, before_day, "input day is unchanged after advance")
	t.eq((original.tickets[0] as Ticket).state, before_ticket_state,
		"input ticket state is unchanged after advance")


func _advance_increments_day(t: TestCase) -> void:
	var next: GameState = Sim.advance(_fresh_state(), {}, Rng.new(1))
	t.eq(next.day, 2, "advance moves from day 1 to day 2")


func _advance_accrues_salaries(t: TestCase) -> void:
	# Give the on-board ticket a long ttl so it does not expire and confound the
	# salary check with its penalty. We are asserting salaries only here.
	var start := _fresh_state()
	(start.tickets[0] as Ticket).ttl = 99
	var next: GameState = Sim.advance(start, {}, Rng.new(1))
	# Two employed employees at the default salary per day.
	var expected: int = start.budget - (2 * 60)
	t.eq(next.budget, expected, "salaries for two employees are deducted at end of day")


func _assignment_with_no_skill_fumbles_and_penalizes(t: TestCase) -> void:
	# A ticket far above the assignees' skill fumbles almost always. The clean
	# chance floors at 5%, so we assert a *majority* across many seeds, not a
	# single roll — pinning one seed would make the test flaky against a balance
	# knob change, which is the opposite of what the suite is for.
	var fumbles := 0
	var trials := 40
	for seed: int in trials:
		var s := _fresh_state()
		(s.tickets[0] as Ticket).severity = 100000
		var actions := {"assignments": [{"ticket_id": "t1", "employee_ids": ["e2"]}]}
		var next: GameState = Sim.advance(s, actions, Rng.new(seed))
		if (next.tickets[0] as Ticket).state == "fumbled":
			fumbles += 1
	t.ok(fumbles >= trials - trials / 4, "over-hard ticket fumbles in the large majority of trials (%d/%d)" % [fumbles, trials])


func _rest_reduces_fatigue_next_day(t: TestCase) -> void:
	var s := _fresh_state()
	(s.employees[0] as Employee).fatigue = 0.9
	var next: GameState = Sim.advance(s, {"rest": ["e1"]}, Rng.new(1))
	t.less((next.employees[0] as Employee).fatigue, 0.9,
		"an employee flagged for rest recovers fatigue by the next day")


func _expired_ticket_penalizes(t: TestCase) -> void:
	# A ticket left open with ttl 1 expires at end of day and subtracts its
	# penalty, on top of salaries.
	var s := _fresh_state()
	var start_budget: int = s.budget
	var next: GameState = Sim.advance(s, {}, Rng.new(1))
	var expected: int = start_budget - 200 - (2 * 60)
	t.eq(next.budget, expected, "an expired ticket subtracts its penalty plus salaries")
