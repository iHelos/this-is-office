extends RefCounted
## Validates content integrity.
##
## The scenario and catalogs are hand-written JSON, which means a typo there
## (a day key that isn't a number, an incident referenced from the scenario but
## missing from the catalog, a faction count other than two) can crash the game
## at runtime in a way that looks like a code bug. This suite pins the contract
## between content and core so those failures surface here, in the test run,
## before any player sees them.

const ContentLoader := preload("res://core/content_loader.gd")


func run(t: TestCase) -> void:
	_scenario_day_keys_are_in_range(t)
	_scenario_incidents_exist_in_catalog(t)
	_scenario_tickets_have_required_fields(t)
	_exactly_two_factions(t)
	_catalog_tickets_have_required_fields(t)
	_catalog_incidents_have_required_fields(t)
	_balance_keys_present(t)


func _scenario_day_keys_are_in_range(t: TestCase) -> void:
	var scenario: Dictionary = ContentLoader.scenario()
	for key: String in scenario:
		var day: int = int(key)
		t.ok(day >= 1 and day <= 180, "scenario day key '%s' is in 1..180" % key)


func _scenario_incidents_exist_in_catalog(t: TestCase) -> void:
	var scenario: Dictionary = ContentLoader.scenario()
	var catalog_ids: PackedStringArray = _incident_ids()
	for day_key: String in scenario:
		var entry: Dictionary = scenario[day_key]
		for inc_id: Variant in entry.get("incidents", []):
			t.ok(catalog_ids.has(String(inc_id)),
				"scenario day %s references incident '%s' which exists in the catalog" % [day_key, inc_id])


func _scenario_tickets_have_required_fields(t: TestCase) -> void:
	var scenario: Dictionary = ContentLoader.scenario()
	for day_key: String in scenario:
		var entry: Dictionary = scenario[day_key]
		for raw: Variant in entry.get("tickets", []):
			var tk: Dictionary = raw as Dictionary
			_assert_ticket_fields(t, tk, "scenario day %s ticket" % day_key)


func _exactly_two_factions(t: TestCase) -> void:
	# Two factions is a design invariant (the Sand/Varga analogue). A third would
	# silently break the war-balance logic in Sim.
	var factions: Array = ContentLoader.factions()
	t.eq(factions.size(), 2, "exactly two factions exist")
	var ids: PackedStringArray = PackedStringArray()
	for f: Variant in factions:
		ids.append(String((f as Dictionary).get("id", "")))
	t.ne(ids[0], ids[1], "the two factions have distinct ids")


func _catalog_tickets_have_required_fields(t: TestCase) -> void:
	var tickets: Array = ContentLoader.tickets()
	t.ok(not tickets.is_empty(), "ticket catalog is not empty")
	for raw: Variant in tickets:
		_assert_ticket_fields(t, raw as Dictionary, "catalog ticket")


func _catalog_incidents_have_required_fields(t: TestCase) -> void:
	var incidents: Array = ContentLoader.incidents()
	t.ok(not incidents.is_empty(), "incident catalog is not empty")
	for raw: Variant in incidents:
		var i: Dictionary = raw as Dictionary
		# choices is required because the deduction-closing screen reads it.
		for field: String in ["id", "title", "kind", "target_faction", "severity", "clues_total", "choices"]:
			t.ok(i.has(field), "incident has field '%s'" % field)
		t.ok((i.get("choices") as Array).size() > 0, "incident '%s' has at least one choice" % String(i.get("id", "")))


func _balance_keys_present(t: TestCase) -> void:
	var b: Dictionary = ContentLoader.balance()
	for field: String in ["severity_scale", "floor_chance", "ceil_chance", "salary_per_employee", "rest_recovery", "tickets_per_day"]:
		t.ok(b.has(field), "balance.json has key '%s'" % field)


func _assert_ticket_fields(t: TestCase, tk: Dictionary, label: String) -> void:
	for field: String in ["kind", "source_dept", "severity", "ttl", "reward", "penalty"]:
		t.ok(tk.has(field), "%s has field '%s'" % [label, field])


func _incident_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for raw: Variant in ContentLoader.incidents():
		out.append(String((raw as Dictionary).get("id", "")))
	return out
