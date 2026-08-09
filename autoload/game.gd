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
var chapter_catalog: Array = []
var cutscene_catalog: Array = []
var tickets_per_day: int = TICKETS_PER_DAY_DEFAULT
# Contracts flagged once_per_day are tracked here so they cannot be farmed; the
# set clears on every end_day. Lives on the autoload (not the state) because it
# is UI-session bookkeeping, not part of the deterministic world.
var contracts_used_today: Dictionary = {}
# Cutscene ids already shown this campaign. A cutscene plays at most once; the
# flag persists across days so re-entering a chapter's day range does not replay
# its prologue. Lives on the autoload for the same reason contracts_used_today.
var seen_cutscenes: Dictionary = {}


func _ready() -> void:
	# Content is project data, not save state; load it eagerly so any missing
	# file fails loudly here, on startup, instead of mid-day.
	scenario = ContentLoader.scenario()
	ticket_catalog = ContentLoader.tickets()
	incident_catalog = ContentLoader.incidents()
	contract_catalog = ContentLoader.contracts()
	chapter_catalog = ContentLoader.chapters()
	cutscene_catalog = ContentLoader.cutscenes()
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
## Resolve a ticket assignment. The assignees are flagged on_assignment for a
## brief beat so the office view shows them leaving their desks; then the ticket
## is resolved and the flag clears. Emits state_changed at each transition so
## both the office and the dispatch board refresh.
func assign_ticket(ticket_id: String, employee_ids: Array) -> void:
	if state == null:
		return
	var ticket: Ticket = _find_ticket(ticket_id)
	if ticket == null or ticket.state != "open":
		return
	# Mark the assignees as away from their desks; the office view hides them.
	for id: String in employee_ids:
		var e: Employee = state.employee_by_id(id)
		if e != null:
			e.on_assignment = true
	state_changed.emit()
	# Brief beat so the player sees the desks empty before the result lands.
	await _wait_brief()
	Sim.resolve_assignment(state, ticket, employee_ids, Rng.new(seed_value).fork("day_%d" % state.day))
	for id: String in employee_ids:
		var e: Employee = state.employee_by_id(id)
		if e != null:
			e.on_assignment = false
	state_changed.emit()


## Duration of the on-assignment visual beat. The real game wants ~0.8s so the
## player sees desks empty and refill; tests set this to 0 to skip the wait.
var brief_duration: float = 0.8


## Await a short real-time beat. Centralised so the duration is one knob and so
## tests can zero it out.
func _wait_brief() -> void:
	if brief_duration <= 0.0:
		return
	await get_tree().create_timer(brief_duration).timeout


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


## Apply a narrative choice that sets a flag and bumps a faction's standing. Used
## by the day-12 faction-allegiance prompt; generic enough for later decisions.
func apply_narrative_choice(flag_key: String, flag_value: String, faction_id: String, standing_delta: float) -> void:
	if state == null:
		return
	state.flags[flag_key] = flag_value
	var faction: Faction = state.faction_by_id(faction_id)
	if faction != null:
		faction.standing = clampf(faction.standing + standing_delta, -1.0, 1.0)
	state.log.append({"kind": "narrative_choice", "flag_key": flag_key, "flag_value": flag_value, "day": state.day})
	state_changed.emit()


## The id of the faction the player allied with on day 12, or "" if none.
func allied_faction() -> String:
	if state == null:
		return ""
	return String(state.flags.get("faction_choice", ""))


# --- Cutscenes ---------------------------------------------------------------
#
# The campaign drives cutscenes in two ways. Day-scripted cutscenes play on the
# first morning of the chapter that names them (see content/chapters.json).
# Reactive cutscenes (with a non-empty trigger block in cutscenes.json) play the
# first morning their trigger evaluates true against the live state. In both
# cases a cutscene id tracked in seen_cutscenes never repeats.

## The chapter that owns [param day], or null if none covers it.
func chapter_for_day(day: int) -> Chapter:
	for raw: Variant in chapter_catalog:
		var ch: Chapter = Chapter.from_dict(raw as Dictionary)
		if ch.contains_day(day):
			return ch
	return null


## The cutscene to play this morning, or null. A cutscene plays at most once: a
## scripted one fires on the first day of its chapter, a reactive one fires as
## soon as its trigger is true. The caller (the day scene) checks this every
## morning and opens cutscene_view when it returns non-null.
func pending_cutscene() -> Cutscene:
	if state == null:
		return null
	# Scripted path: the chapter owning today names a cutscene we have not seen.
	var chapter: Chapter = chapter_for_day(state.day)
	if chapter != null and not chapter.cutscene_id.is_empty() and not seen_cutscenes.has(chapter.cutscene_id):
		var scripted: Cutscene = _cutscene_by_id(chapter.cutscene_id)
		if scripted != null:
			return scripted
	# Reactive path: any cutscene whose trigger is true and we have not seen.
	# Triggers are evaluated against live state, so e.g. a mutiny cutscene can
	# fire the morning loyalty collapses.
	for raw: Variant in cutscene_catalog:
		var cs: Cutscene = Cutscene.from_dict(raw as Dictionary)
		if seen_cutscenes.has(cs.id):
			continue
		if cs.trigger.is_empty():
			continue
		if Triggers.evaluate(state, cs.trigger):
			return cs
	return null


## Apply the effects of a cutscene choice and return the next node id (or "" if
## the choice ends the cutscene). Effects are a list of small dicts so they stay
## authorable in JSON; each kind maps to one state mutation here.
func apply_cutscene_choice(cutscene_id: String, node_id: String, choice: Dictionary) -> String:
	if state == null:
		return ""
	mark_cutscene_seen(cutscene_id)
	for effect: Variant in choice.get("effects", []):
		_apply_cutscene_effect(effect as Dictionary)
	state.log.append({"kind": "cutscene_choice", "cutscene_id": cutscene_id, "node_id": node_id, "day": state.day})
	state_changed.emit()
	return String(choice.get("next", ""))


func mark_cutscene_seen(cutscene_id: String) -> void:
	if cutscene_id.is_empty():
		return
	seen_cutscenes[cutscene_id] = true


func _apply_cutscene_effect(effect: Dictionary) -> void:
	# Each effect is one key -> argument. Unknown effects are ignored with a
	# warning so a typo never crashes a cutscene mid-line.
	if effect.has("set_flag"):
		var args: Array = effect["set_flag"]
		state.flags[String(args[0])] = args[1]
	elif effect.has("budget"):
		var economy := Economy.new()
		var delta: int = int(effect["budget"])
		state.budget = economy.settle(state.budget, delta)
		if delta > 0:
			state.profit_banked += delta
	elif effect.has("loyalty"):
		var delta: float = float(effect["loyalty"])
		for e: Employee in state.employees:
			if e.employed:
				e.loyalty = clampf(e.loyalty + delta, -1.0, 1.0)
	elif effect.has("faction_standing"):
		var args: Array = effect["faction_standing"]
		var faction: Faction = state.faction_by_id(String(args[0]))
		if faction != null:
			faction.standing = clampf(faction.standing + float(args[1]), -1.0, 1.0)
	else:
		push_warning("Game: unknown cutscene effect %s" % str(effect.keys()))


func _cutscene_by_id(cutscene_id: String) -> Cutscene:
	for raw: Variant in cutscene_catalog:
		var cs: Cutscene = Cutscene.from_dict(raw as Dictionary)
		if cs.id == cutscene_id:
			return cs
	return null


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
