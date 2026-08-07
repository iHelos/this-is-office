extends RefCounted
## Balance smoke test: a full 180-day autoplay reaches the profit target.
##
## The economy was re-tuned (salary 60->35, severity_scale 1.0->0.7) specifically
## so the $500k target is reachable. This suite runs a greedy autoplay — assign
## the whole team to each open ticket, take the freelance contract daily — and
## asserts that across several seeds the median run banks at least the target.
## It does not pin an exact number (that would make the suite a balance knob,
## which is the wrong place to tune); it pins that good play can win.
##
## A failure here means the economy drifted too harsh (or too easy) and the
## balance.json knobs need adjusting, not the test.

const CAMPAIGN_DAYS := 180
const SEEDS_TO_TRY := 5


func run(t: TestCase) -> void:
	var banked: Array = []
	for seed: int in SEEDS_TRY():
		banked.append(_autoplay(seed))
	banked.sort()
	# Median across seeds. Greedy autoplay is not optimal play, so the bar is the
	# target itself: a reasonable player doing better than greedy should clear it
	# in more than half of seeds.
	var median: int = banked[banked.size() / 2]
	t.ok(median >= GameState.PROFIT_TARGET,
		"greedy autoplay median across %d seeds banks $%d (target $%d)" % [SEEDS_TO_TRY, median, GameState.PROFIT_TARGET])


# An Array literal is not a constant expression in GDScript; build it here.
func SEEDS_TRY() -> Array:
	return [101, 202, 303, 404, 505]


func _autoplay(seed_value: int) -> int:
	Game.start_new_game(seed_value)
	# Roll cutscenes forward so they don't block (mark all as seen) — the autoplay
	# cares about the economy, not the narrative.
	for raw: Variant in Game.cutscene_catalog:
		Game.mark_cutscene_seen(String((raw as Dictionary).get("id", "")))
	while not Game.campaign_over():
		# Greedy: send every employed, non-resting employee at each open ticket.
		var team: Array = []
		for e: Employee in Game.state.employees:
			if e.employed and not e.on_rest:
				team.append(e.id)
		for tk: Ticket in Game.state.tickets:
			if tk.state == "open" and not team.is_empty():
				Game.assign_ticket(tk.id, team)
		# Take the safest side contract for extra income each day.
		Game.take_contract("ct_freelance")
		# Rotate a little rest to keep fatigue manageable: rest the most-tired
		# employee every few days so the team does not burn out.
		if Game.current_day() % 3 == 0:
			_rest_tired()
		Game.end_day_with_staged_rest()
	return Game.profit_banked()


func _rest_tired() -> void:
	# Find the employed employee with the highest fatigue and rest them.
	var worst: Employee = null
	for e: Employee in Game.state.employees:
		if not e.employed:
			continue
		if worst == null or e.fatigue > worst.fatigue:
			worst = e
	if worst != null:
		Game.toggle_rest(worst.id)
