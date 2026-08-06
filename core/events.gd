class_name Events
extends RefCounted
## Deterministic daily event generation.
##
## Each day's tickets and incidents come from two sources: scripted beats in
## content/scenario.json (the milestones that give the campaign its shape, §6)
## and procedural fillers drawn from content/tickets.json. Both are rolled with
## an RNG forked by day, so the same seed replays the same day forever.
##
## This class never touches the filesystem or the SceneTree; the caller loads
## the JSON and hands it in, which keeps the core pure and testable.

## Returns the scripted entry for [param day], or an empty Dictionary if the
## day has no scripted beat. The scenario is a Dictionary keyed by day-as-string
## so JSON stays readable; missing days are normal and expected.
func scripted_for_day(scenario: Dictionary, day: int) -> Dictionary:
	var key := str(day)
	if not scenario.has(key):
		return {}
	return scenario[key] as Dictionary


## Build the day's ticket queue. Scripted tickets come first (in declared
## order); procedural tickets fill the rest up to [param target_count]. Each
## procedural ticket is cloned from a random template in [param ticket_catalog]
## and given a fresh id derived from the day, so two runs from the same seed
## produce the same queue.
func tickets_for_day(scenario: Dictionary, ticket_catalog: Array, day: int, rng: Rng, target_count: int) -> Array:
	var day_rng := rng.fork("day_%d" % day)
	var out: Array = []
	var scripted: Dictionary = scripted_for_day(scenario, day)
	var scripted_tickets: Array = scripted.get("tickets", [])
	for raw: Variant in scripted_tickets:
		out.append(_ticket_from_template(raw as Dictionary, day, day_rng, true, 0))
	var remaining: int = maxi(0, target_count - out.size())
	if ticket_catalog.is_empty():
		return out
	for i: int in remaining:
		var template: Dictionary = day_rng.pick(ticket_catalog) as Dictionary
		out.append(_ticket_from_template(template, day, day_rng, false, i))
	return out


## Build the day's incidents. Scripted incidents spawn on their declared day;
## there is no procedural incident spawning, because investigations are meant to
## be rare and authored (§6).
func incidents_for_day(scenario: Dictionary, incident_catalog: Array, day: int, rng: Rng) -> Array:
	var day_rng := rng.fork("day_%d_incidents" % day)
	var out: Array = []
	var scripted: Dictionary = scripted_for_day(scenario, day)
	var scripted_incidents: Array = scripted.get("incidents", [])
	for raw: Variant in scripted_incidents:
		# The scenario lists incidents by id string (see content/scenario.json,
		# e.g. "incidents": ["inc_leak_meridian"]). Accept a bare string or a
		# {"id": ...} dict so the format stays forgiving.
		var id: String = String(raw) if raw is String else String((raw as Dictionary).get("id", ""))
		var template: Dictionary = _lookup_incident_template(incident_catalog, id)
		if template.is_empty():
			# An incident referenced in the scenario but missing from the catalog
			# is a content bug; surface it rather than silently skipping.
			push_error("Events: incident '%s' scripted for day %d but not in catalog" % [id, day])
			continue
		out.append(Incident.from_dict(template))
	return out


func _ticket_from_template(template: Dictionary, day: int, rng: Rng, scripted: bool, suffix: int = 0) -> Ticket:
	# Clone the template so the catalog stays pristine across days.
	var d: Dictionary = template.duplicate(true)
	# Severity and reward jitter deterministically per-spawn, so the same template
	# yields varied-but-replayable tickets across the day.
	var roll := rng.fork("spawn_%d_%d" % [day, suffix])
	if not scripted:
		d["severity"] = int(d.get("severity", 100)) * int(roll.next_float_range(0.8, 1.25))
	# Ids must be unique within a day; the scripted/procedural flag keeps them
	# human-readable in save files and logs.
	var prefix := "s" if scripted else "p"
	d["id"] = "%s_d%d_%d" % [prefix, day, suffix]
	# Fresh tickets always start open regardless of what the template said.
	d["state"] = "open"
	return Ticket.from_dict(d)


func _lookup_incident_template(catalog: Array, id: String) -> Dictionary:
	for entry: Variant in catalog:
		var d: Dictionary = entry as Dictionary
		if String(d.get("id", "")) == id:
			return d
	return {}
