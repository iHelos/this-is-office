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
var tickets_per_day: int = TICKETS_PER_DAY_DEFAULT


func _ready() -> void:
	# Content is project data, not save state; load it eagerly so any missing
	# file fails loudly here, on startup, instead of mid-day.
	scenario = ContentLoader.scenario()
	ticket_catalog = ContentLoader.tickets()
	incident_catalog = ContentLoader.incidents()
	var balance: Dictionary = ContentLoader.balance()
	tickets_per_day = int(balance.get("tickets_per_day", TICKETS_PER_DAY_DEFAULT))


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
	state = Sim.advance(state, actions, Rng.new(seed_value))
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
