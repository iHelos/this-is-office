class_name Incident
extends RefCounted
## A multi-day investigation, the corporate analogue of a TITP evidence board.
##
## Where a ticket is a single dispatch call, an incident is a chain: clues
## accumulate over days (assigned troubleshooters gather them), then the player
## deduces a sequence and makes a closing choice (drop it / confront / sell to a
## rival). The deduction state is plain data so it clones cleanly into the next
## deterministic state.

var id: String = ""
var title: String = ""                  # display key, e.g. "incident.leak.title"
var kind: String = ""                   # "leak" | "sabotage" | "espionage"
var target_faction: String = ""         # which rival department this concerns
var severity: int = 200                 # opposed by assigned troubleshooter skill
var clues_total: int = 4                # clues needed before deduction unlocks
var clues_found: int = 0
var deduction_order: PackedStringArray = PackedStringArray()  # player's guess
var choices: Array = []                 # closing choices, each a Dictionary
var state: String = "open"              # "open" | "deducing" | "closed"


static func from_dict(d: Dictionary) -> Incident:
	var i := Incident.new()
	i.id = String(d.get("id", ""))
	i.title = String(d.get("title", ""))
	i.kind = String(d.get("kind", ""))
	i.target_faction = String(d.get("target_faction", ""))
	i.severity = int(d.get("severity", 200))
	i.clues_total = int(d.get("clues_total", 4))
	i.clues_found = int(d.get("clues_found", 0))
	i.state = String(d.get("state", "open"))
	var order: Array = d.get("deduction_order", [])
	var ord := PackedStringArray()
	for c: Variant in order:
		ord.append(String(c))
	i.deduction_order = ord
	# Choices are free-form dictionaries defined in content/incidents.json; copy
	# them by value so mutating one incident never bleeds into the template.
	var src_choices: Array = d.get("choices", [])
	var cloned := []
	for ch: Variant in src_choices:
		cloned.append((ch as Dictionary).duplicate(true))
	i.choices = cloned
	return i


func clone() -> Incident:
	var c := Incident.new()
	c.id = id
	c.title = title
	c.kind = kind
	c.target_faction = target_faction
	c.severity = severity
	c.clues_total = clues_total
	c.clues_found = clues_found
	c.deduction_order = deduction_order.duplicate()
	c.choices = []
	for ch: Dictionary in choices:
		c.choices.append(ch.duplicate(true))
	c.state = state
	return c


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"kind": kind,
		"target_faction": target_faction,
		"severity": severity,
		"clues_total": clues_total,
		"clues_found": clues_found,
		"deduction_order": Array(deduction_order),
		"choices": choices.duplicate(true),
		"state": state,
	}
