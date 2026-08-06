class_name Sim
extends RefCounted
## The deterministic simulation step.
##
## [method advance] is a pure function: it clones the incoming state, applies
## the player's actions, rolls the day's outcomes through the provided RNG, and
## returns the new state. Nothing here touches the SceneTree, the filesystem, or
## global state. Replaying the same (seed, state, actions) reproduces the same
## next state — that property is pinned by tests/test_sim.gd and is the reason
## the core exists as a separate layer from the UI.

const TICKETS_PER_DAY: int = 4


## Resolve a single ticket assignment against a cloned state, in place. Used
## both by [method advance] (for the end-of-day batch) and directly by the UI
## when a ticket is sent out during dispatch.
static func resolve_assignment(state: GameState, ticket: Ticket, assigned_ids: Array, rng: Rng) -> Dictionary:
	var resolve := Resolve.new()
	var assigned: Array = []
	for id: String in assigned_ids:
		var e: Employee = state.employee_by_id(id)
		if e != null and e.employed:
			assigned.append(e)
	var result: Dictionary = resolve.resolve_ticket(ticket, assigned, rng)
	# Apply the outcome to the cloned state.
	state.budget = Economy.new().settle(state.budget, int(result["budget_delta"]))
	if bool(result["clean"]):
		state.profit_banked += int(result["budget_delta"])
	var xp_awards: Dictionary = result["xp_awards"]
	for emp_id: String in xp_awards:
		var e: Employee = state.employee_by_id(emp_id)
		if e != null:
			e.xp += int(xp_awards[emp_id])
	var fatigue: float = float(result["fatigue_added"])
	for e: Employee in assigned:
		e.fatigue = clampf(e.fatigue + fatigue, 0.0, 1.0)
	ticket.state = String(result["final_state"])
	state.log.append({
		"kind": "ticket_resolved",
		"ticket_id": ticket.id,
		"clean": bool(result["clean"]),
		"budget_delta": int(result["budget_delta"]),
		"day": state.day,
	})
	return result


## Advance one day. [param actions] is a Dictionary the UI builds; supported
## keys are documented inline below. Returns a *new* GameState; the caller is
## responsible for storing it.
static func advance(state: GameState, actions: Dictionary, rng: Rng) -> GameState:
	var next: GameState = state.clone()
	var economy := Economy.new()
	var day_rng := rng.fork("day_%d" % next.day)

	# --- Apply player actions -------------------------------------------------
	# actions = {
	#   "assignments": [{"ticket_id": "...", "employee_ids": ["..."]}, ...],
	#   "rest": ["employee_id", ...],
	#   "flag": {"key": "faction_choice", "value": "sand"},
	# }
	for emp_id: String in actions.get("rest", []):
		var e: Employee = next.employee_by_id(emp_id)
		if e != null:
			e.on_rest = true
	if actions.has("flag"):
		var flag: Dictionary = actions["flag"]
		next.flags[String(flag["key"])] = flag["value"]

	# Resolve assignments against the cloned state.
	for entry: Variant in actions.get("assignments", []):
		var d: Dictionary = entry as Dictionary
		var ticket_id: String = String(d["ticket_id"])
		var ids: Array = d["employee_ids"]
		var ticket: Ticket = _find_ticket(next, ticket_id)
		if ticket == null or ticket.state != "open":
			continue
		resolve_assignment(next, ticket, ids, day_rng)

	# --- End of day -----------------------------------------------------------
	# Expire any open ticket whose ttl hit zero; the player paid the penalty.
	for tk: Ticket in next.tickets:
		if tk.state == "open":
			tk.ttl -= 1
			if tk.ttl <= 0:
				tk.state = "expired"
				next.budget = economy.settle(next.budget, -tk.penalty)
				next.log.append({"kind": "ticket_expired", "ticket_id": tk.id, "day": next.day})

	# Resting employees recover fatigue; salaries accrue for everyone employed.
	economy.apply_rest(next.employees)
	next.budget = economy.settle(next.budget, -economy.daily_salaries(next.employees))

	# Advance the clock. Resolved/expired tickets stay on the board as
	# yesterday's record; the next morning's Events.tickets_for_day replaces them
	# when the UI spawns a new queue. Clearing here would erase the outcome the
	# player just saw.
	next.day += 1
	if next.day > GameState.CAMPAIGN_DAYS:
		next.day = GameState.CAMPAIGN_DAYS  # clamp at the restructuring day
	return next


static func _find_ticket(state: GameState, id: String) -> Ticket:
	for tk: Ticket in state.tickets:
		if tk.id == id:
			return tk
	return null
