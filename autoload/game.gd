extends Node
## Bridge between the deterministic core and the UI.
##
## The core (core/*.gd) is pure: it knows nothing about nodes, scenes, or the
## SceneTree. The UI knows nothing about how a day advances. This singleton is
## the only place they meet. Screens read [member state] and listen to
## [signal state_changed]; they never mutate the state directly, they ask this
## autoload to apply an action through the core, which keeps the simulation
## deterministic and replayable.

signal state_changed()

const TICKETS_PER_DAY_DEFAULT: int = 4

var seed_value: int = 0
var state: GameState = null
# The cached content is read-only; loading it once at game start is enough and
# keeps FileAccess calls out of the per-day hot path.
var scenario: Dictionary = {}
var ticket_catalog: Array = []
var incident_catalog: Array = []
var contract_catalog: Array = []
var tickets_per_day: int = TICKETS_PER_DAY_DEFAULT
# Contracts flagged once_per_day are tracked here so they cannot be farmed; the
# set clears on every end_day. Lives on the autoload (not the state) because it
# is UI-session bookkeeping, not part of the deterministic world.
var contracts_used_today: Dictionary = {}


func _ready() -> void:
	# Content is project data, not save state; load it eagerly so any missing
	# file fails loudly here, on startup, instead of mid-day.
	scenario = ContentLoader.scenario()
	ticket_catalog = ContentLoader.tickets()
	incident_catalog = ContentLoader.incidents()
	contract_catalog = ContentLoader.contracts()
	var balance: Dictionary = ContentLoader.balance()
	tickets_per_day = int(balance.get("tickets_per_day", TICKETS_PER_DAY_DEFAULT))


func daily_salaries() -> int:
	# Surfaces the economy calculation for the economy screen without the UI
	# reaching into the core classes directly.
	if state == null:
		return 0
	var economy := Economy.new()
	economy.apply_balance(ContentLoader.balance())
	return economy.daily_salaries(state.employees)


## Start a fresh campaign from [param seed_value_]. Loads the scripted roster
## and factions, then spawns the first morning's board.
func start_new_game(seed_value_: int) -> void:
	seed_value = seed_value_
	state = GameState.initial(seed_value_, ContentLoader.employees(), ContentLoader.factions())
	_apply_balance()
	_spawn_morning()
	state_changed.emit()


func current_day() -> int:
	return state.day if state != null else 1


func budget() -> int:
	return state.budget if state != null else 0


func profit_banked() -> int:
	return state.profit_banked if state != null else 0


func target() -> int:
	return state.target if state != null else 0


## Resolve a ticket assignment immediately (during dispatch). Emits
## [signal state_changed] so the dispatch screen can refresh.
func assign_ticket(ticket_id: String, employee_ids: Array) -> void:
	if state == null:
		return
	var ticket: Ticket = _find_ticket(ticket_id)
	if ticket == null or ticket.state != "open":
		return
	Sim.resolve_assignment(state, ticket, employee_ids, Rng.new(seed_value).fork("day_%d" % state.day))
	state_changed.emit()


## Apply the player's end-of-day actions and roll the day forward. The actions
## dictionary matches the contract documented on [code]Sim.advance[/code].
func end_day(actions: Dictionary = {}) -> void:
	if state == null:
		return
	# Apply any scripted flags for the day we are leaving (the scenario's flag_set
	# fires at end of that day, so e.g. day 12's faction_choice_due is set as day
	# 12 closes and is visible on the morning of day 13).
	var leaving_entry: Dictionary = scenario.get(str(state.day), {})
	for flag: String in leaving_entry.get("flag_set", {}):
		state.flags[flag] = (leaving_entry["flag_set"] as Dictionary)[flag]
	state = Sim.advance(state, actions, Rng.new(seed_value))
	contracts_used_today.clear()
	_spawn_morning()
	state_changed.emit()


## Toggle an employee's rest flag for the coming night. Rest is applied at end of
## day through Sim.advance, so this only stages the intent — the employee still
## appears in the pool until the day rolls.
func toggle_rest(employee_id: String) -> void:
	if state == null:
		return
	var e: Employee = state.employee_by_id(employee_id)
	if e == null or not e.employed:
		return
	e.on_rest = not e.on_rest
	state_changed.emit()


## Fire an employee immediately. This is a player decision, not a simulation
## step, so it mutates the live state directly. The unemployed employee stays in
## the roster (marked) so the log can still reference them.
func fire(employee_id: String) -> void:
	if state == null:
		return
	var e: Employee = state.employee_by_id(employee_id)
	if e == null or not e.employed:
		return
	e.employed = false
	e.on_rest = false
	state.log.append({"kind": "employee_fired", "employee_id": employee_id, "day": state.day})
	state_changed.emit()


## Build the end-of-day actions from any rest flags the player staged during the
## day, then roll forward. This is the path the HUD's End Day button takes.
func end_day_with_staged_rest() -> void:
	var rest_ids: Array = []
	for e: Employee in state.employees:
		if e.employed and e.on_rest:
			rest_ids.append(e.id)
	end_day({"rest": rest_ids})


## Take a side contract: budget now, fatigue/loyalty cost applied across the
## employed staff. once_per_day contracts are gated by [member contracts_used_today].
## Returns true if the contract was applied.
func take_contract(contract_id: String) -> bool:
	if state == null:
		return false
	var contract: Dictionary = _find_contract(contract_id)
	if contract.is_empty():
		return false
	if bool(contract.get("once_per_day", false)) and contracts_used_today.has(contract_id):
		return false
	var budget_delta: int = int(contract.get("budget_delta", 0))
	var fatigue_delta: float = float(contract.get("fatigue_delta", 0.0))
	var loyalty_delta: float = float(contract.get("loyalty_delta", 0.0))
	var economy := Economy.new()
	state.budget = economy.settle(state.budget, budget_delta)
	if budget_delta > 0:
		state.profit_banked += budget_delta
	for e: Employee in state.employees:
		if not e.employed:
			continue
		e.fatigue = clampf(e.fatigue + fatigue_delta, 0.0, 1.0)
		e.loyalty = clampf(e.loyalty + loyalty_delta, -1.0, 1.0)
	if bool(contract.get("once_per_day", false)):
		contracts_used_today[contract_id] = true
	state.log.append({"kind": "contract_taken", "contract_id": contract_id, "budget_delta": budget_delta, "day": state.day})
	state_changed.emit()
	return true


## True when the campaign has reached its final day and the ending should play.
func campaign_over() -> bool:
	return state != null and state.day >= GameState.CAMPAIGN_DAYS


## A coarse outcome label for the ending screen: did the player hit the target?
func ending_outcome() -> String:
	if state == null:
		return "incomplete"
	if state.profit_banked >= state.target:
		return "target_hit"
	return "target_missed"


func _find_contract(id: String) -> Dictionary:
	for c: Variant in contract_catalog:
		var d: Dictionary = c as Dictionary
		if String(d.get("id", "")) == id:
			return d
	return {}


## Gather clues on an incident. Each troubleshooter contributes clues
## proportional to their xp against the incident's severity, rolled through a
## day-forked RNG so the result is deterministic. Returns the number of new
## clues found this action.
func assign_troubleshooters(incident_id: String, employee_ids: Array) -> int:
	if state == null:
		return 0
	var incident: Incident = _find_incident(incident_id)
	if incident == null or incident.state != "open":
		return 0
	var team: Array = []
	for id: String in employee_ids:
		var e: Employee = state.employee_by_id(id)
		if e != null and e.employed:
			team.append(e)
	var rng := Rng.new(seed_value).fork("incident_%s_day_%d" % [incident_id, state.day])
	var resolve := Resolve.new()
	resolve.apply_balance(ContentLoader.balance())
	var found := 0
	for e: Employee in team:
		# One clue per troubleshooter whose clean-chance roll succeeds; high-xp
		# staff are near-certain, rookies are a gamble. Fatigue/loyalty still
		# apply through clean_chance, so burning out your auditors costs you here.
		var chance: float = resolve.clean_chance([e], incident.severity)
		if rng.fork(e.id).chance(chance):
			found += 1
		e.fatigue = clampf(e.fatigue + 0.1, 0.0, 1.0)
	incident.clues_found = mini(incident.clues_found + found, incident.clues_total)
	if incident.clues_found >= incident.clues_total:
		incident.state = "deducing"
	state.log.append({"kind": "clues_gathered", "incident_id": incident_id, "found": found, "day": state.day})
	state_changed.emit()
	return found


## Close an incident with a chosen option. Looks up the choice's deltas and
## applies them: budget, faction standing, faction power. The incident is then
## marked closed and cannot be worked further.
func close_incident(incident_id: String, choice_id: String) -> bool:
	if state == null:
		return false
	var incident: Incident = _find_incident(incident_id)
	if incident == null or incident.state != "deducing":
		return false
	var choice: Dictionary = _find_choice(incident, choice_id)
	if choice.is_empty():
		return false
	var economy := Economy.new()
	var budget_delta: int = int(choice.get("budget_delta", 0))
	state.budget = economy.settle(state.budget, budget_delta)
	if budget_delta > 0:
		state.profit_banked += budget_delta
	var standing_delta: float = float(choice.get("standing_delta", 0.0))
	var power_delta: int = int(choice.get("faction_power_delta", 0))
	var faction: Faction = state.faction_by_id(incident.target_faction)
	if faction != null:
		faction.standing = clampf(faction.standing + standing_delta, -1.0, 1.0)
		faction.power = maxi(0, faction.power + power_delta)
	incident.state = "closed"
	state.log.append({"kind": "incident_closed", "incident_id": incident_id, "choice": choice_id, "day": state.day})
	state_changed.emit()
	return true


func _find_incident(id: String) -> Incident:
	for i: Incident in state.incidents:
		if i.id == id:
			return i
	return null


func _find_choice(incident: Incident, choice_id: String) -> Dictionary:
	for c: Variant in incident.choices:
		var d: Dictionary = c as Dictionary
		if String(d.get("id", "")) == choice_id:
			return d
	return {}


func _spawn_morning() -> void:
	# The morning board is generated deterministically from the seed + day, so a
	# replay lands on the same tickets. We mutate state.tickets in place because
	# this runs right after advance() returned a fresh, owned state.
	var events := Events.new()
	state.tickets = events.tickets_for_day(scenario, ticket_catalog, state.day, Rng.new(seed_value), tickets_per_day)
	var new_incidents: Array = events.incidents_for_day(scenario, incident_catalog, state.day, Rng.new(seed_value))
	for inc: Incident in new_incidents:
		state.incidents.append(inc)


func _apply_balance() -> void:
	# The resolve/economy formulas read their knobs from a balance dictionary;
	# both are constructed fresh where they run, so we only need the data here.
	# (The knobs themselves are applied inside those classes when constructed
	# per-call; storing the balance on Game is enough for the UI to display it.)
	pass


func _find_ticket(id: String) -> Ticket:
	for tk: Ticket in state.tickets:
		if tk.id == id:
			return tk
	return null
