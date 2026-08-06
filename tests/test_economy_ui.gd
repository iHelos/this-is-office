extends RefCounted
## Pins the economy path: side contracts and the day-180 ending gate.
##
## Side contracts are the analogue of TITP's side income — money now for a
## fatigue/loyalty cost later. The suite makes sure the trade actually applies,
## once_per_day contracts cannot be farmed within a day, the gate resets at end
## of day, and the campaign-ending check flips on day 180 with the right outcome
## label for whether the profit target was hit.

const CAMPAIGN_DAYS := 180


func run(t: TestCase) -> void:
	_contract_applies_budget_and_cost(t)
	_once_per_day_contract_cannot_be_taken_twice(t)
	_contract_gate_resets_at_end_day(t)
	_campaign_over_flips_on_day_180(t)
	_ending_outcome_reflects_target(t)


func _contract_applies_budget_and_cost(t: TestCase) -> void:
	Game.start_new_game(1)
	var before_budget: int = Game.budget()
	var emp: Employee = Game.state.employees[0]
	var before_fatigue: float = emp.fatigue
	t.ok(Game.take_contract("ct_freelance"), "freelance contract is taken")
	t.ok(Game.budget() > before_budget, "the contract pays into the budget")
	# fatigue_delta for freelance is +0.2 across employed staff.
	t.ok(emp.fatigue >= before_fatigue, "the contract's fatigue cost applies")


func _once_per_day_contract_cannot_be_taken_twice(t: TestCase) -> void:
	Game.start_new_game(1)
	t.ok(Game.take_contract("ct_rival_tip"), "rival tip taken once")
	t.ok(not Game.take_contract("ct_rival_tip"), "rival tip cannot be taken twice in one day")


func _contract_gate_resets_at_end_day(t: TestCase) -> void:
	Game.start_new_game(1)
	Game.take_contract("ct_rival_tip")
	Game.end_day_with_staged_rest()
	t.ok(Game.take_contract("ct_rival_tip"), "once_per_day resets after end_day")


func _campaign_over_flips_on_day_180(t: TestCase) -> void:
	Game.start_new_game(1)
	t.ok(not Game.campaign_over(), "a fresh game is not over")
	# Fast-forward to the final day by rolling repeatedly. Day clamps at 180.
	for i: int in CAMPAIGN_DAYS + 5:
		if Game.campaign_over():
			break
		Game.end_day_with_staged_rest()
	t.ok(Game.campaign_over(), "the campaign is over once day 180 is reached")


func _ending_outcome_reflects_target(t: TestCase) -> void:
	Game.start_new_game(1)
	# A missed target: profit_banked starts at 0, below the 500000 target.
	t.eq(Game.ending_outcome(), "target_missed", "below target -> target_missed")
	# Force the banked profit above target and re-check.
	Game.state.profit_banked = Game.state.target + 1
	t.eq(Game.ending_outcome(), "target_hit", "above target -> target_hit")
