class_name GameState
extends RefCounted
## The whole world, as plain data.
##
## This is what gets cloned for the next deterministic state, what gets saved,
## and what gets diffed by tests. Every field is a value type or a collection of
## [code]clone()[/code]-able core objects, so [method clone] is a deep copy.

const CAMPAIGN_DAYS: int = 180
const STARTING_BUDGET: int = 50000
const PROFIT_TARGET: int = 500000

var seed_value: int = 0
var day: int = 1
var budget: int = STARTING_BUDGET
var target: int = PROFIT_TARGET
var profit_banked: int = 0     # cumulative profit delivered toward the target
var employees: Array = []      # Array[Employee]
var tickets: Array = []        # Array[Ticket] currently on the board
var incidents: Array = []      # Array[Incident] open investigations
var factions: Array = []       # Array[Faction], expected size 2
var flags: Dictionary = {}     # scenario flags, e.g. {"faction_choice": "sand"}
var log: Array = []            # recent events as plain Dictionaries, for the UI


static func initial(seed_value_: int, employees_json: Array, factions_json: Array) -> GameState:
	# A fresh campaign: day 1, full budget, no profit banked, scripted staff and
	# factions, no tickets or incidents yet (those spawn on the first morning).
	var s := GameState.new()
	s.seed_value = seed_value_
	s.day = 1
	s.budget = STARTING_BUDGET
	s.target = PROFIT_TARGET
	for raw: Variant in employees_json:
		s.employees.append(Employee.from_dict(raw as Dictionary))
	for raw: Variant in factions_json:
		s.factions.append(Faction.from_dict(raw as Dictionary))
	return s


func clone() -> GameState:
	var c := GameState.new()
	c.seed_value = seed_value
	c.day = day
	c.budget = budget
	c.target = target
	c.profit_banked = profit_banked
	for e: Employee in employees:
		c.employees.append(e.clone())
	for tk: Ticket in tickets:
		c.tickets.append(tk.clone())
	for i: Incident in incidents:
		c.incidents.append(i.clone())
	for f: Faction in factions:
		c.factions.append(f.clone())
	c.flags = flags.duplicate(true)
	c.log = log.duplicate(true)
	return c


func employee_by_id(id: String) -> Employee:
	for e: Employee in employees:
		if e.id == id:
			return e
	return null


func faction_by_id(id: String) -> Faction:
	for f: Faction in factions:
		if f.id == id:
			return f
	return null


func to_dict() -> Dictionary:
	var emps := []
	for e: Employee in employees:
		emps.append(e.to_dict())
	var tks := []
	for tk: Ticket in tickets:
		tks.append(tk.to_dict())
	var incs := []
	for i: Incident in incidents:
		incs.append(i.to_dict())
	var facs := []
	for f: Faction in factions:
		facs.append(f.to_dict())
	return {
		"seed_value": seed_value,
		"day": day,
		"budget": budget,
		"target": target,
		"profit_banked": profit_banked,
		"employees": emps,
		"tickets": tks,
		"incidents": incs,
		"factions": facs,
		"flags": flags.duplicate(true),
		"log": log.duplicate(true),
	}
