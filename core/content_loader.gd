class_name ContentLoader
extends RefCounted
## Reads the JSON content files into the dictionaries the core expects.
##
## One place that knows the file layout, so the rest of the core stays free of
## [code]FileAccess[/code] boilerplate. JSON is parsed with
## [method JSON.parse_string] because [code].json[/code] is not a Godot resource
## and must be read as text (the same convention zpg uses). Every loader returns
## the inner collection, not the wrapper object, so callers do not have to know
## the top-level key.

const PATH_BALANCE := "res://content/balance.json"
const PATH_FACTIONS := "res://content/factions.json"
const PATH_EMPLOYEES := "res://content/employees.json"
const PATH_TICKETS := "res://content/tickets.json"
const PATH_INCIDENTS := "res://content/incidents.json"
const PATH_SCENARIO := "res://content/scenario.json"


static func _read(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	# An empty file is almost always a path typo, not an intentional empty
	# catalog. Surface it loudly rather than returning null downstream.
	assert(not text.is_empty(), "ContentLoader: %s is empty or missing" % path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed != null, "ContentLoader: %s failed to parse as JSON" % path)
	return parsed


static func balance() -> Dictionary:
	return (_read(PATH_BALANCE) as Dictionary)


static func factions() -> Array:
	return (_read(PATH_FACTIONS) as Dictionary).get("factions", []) as Array


static func employees() -> Array:
	return (_read(PATH_EMPLOYEES) as Dictionary).get("employees", []) as Array


static func tickets() -> Array:
	return (_read(PATH_TICKETS) as Dictionary).get("tickets", []) as Array


static func incidents() -> Array:
	return (_read(PATH_INCIDENTS) as Dictionary).get("incidents", []) as Array


static func scenario() -> Dictionary:
	return (_read(PATH_SCENARIO) as Dictionary)
