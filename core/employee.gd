class_name Employee
extends RefCounted
## One member of staff.
##
## The corporate analogue of a This Is the Police officer. The fields mirror
## the design doc (§3): xp drives outcomes, fatigue dampens them, loyalty gates
## whether the employee will do what you ask at all. Everything is plain data so
## the whole object can be cloned for the next deterministic state.

# Departments are strings, not an enum, so content/scenario.json can introduce a
# department without recompiling. The known set lives in content/factions.json.
var id: String = ""
var name: String = ""
var dept: String = ""
var role: String = "dev"        # "dev" | "analyst" | "designer" | "troubleshooter" | "architect"
var xp: int = 0                 # 0..~1500, grows only on clean resolutions (§3)
var fatigue: float = 0.0        # 0..1, accumulates per assignment, recovered on rest
var loyalty: float = 0.0        # -1..+1, disposition toward the player
var employed: bool = true
var on_rest: bool = false       # set when given the day off; recovers fatigue
var on_assignment: bool = false # transient: on a ticket right now (visual link to the office)
var traits: PackedStringArray = PackedStringArray()


static func from_dict(d: Dictionary) -> Employee:
	var e := Employee.new()
	e.id = String(d.get("id", ""))
	e.name = String(d.get("name", ""))
	e.dept = String(d.get("dept", ""))
	e.role = String(d.get("role", "dev"))
	e.xp = int(d.get("xp", 0))
	e.fatigue = float(d.get("fatigue", 0.0))
	e.loyalty = float(d.get("loyalty", 0.0))
	e.employed = bool(d.get("employed", true))
	e.on_rest = bool(d.get("on_rest", false))
	e.on_assignment = bool(d.get("on_assignment", false))
	var raw_traits: Array = d.get("traits", [])
	var arr := PackedStringArray()
	for tr: Variant in raw_traits:
		arr.append(String(tr))
	e.traits = arr
	return e


func clone() -> Employee:
	var c := Employee.new()
	c.id = id
	c.name = name
	c.dept = dept
	c.role = role
	c.xp = xp
	c.fatigue = fatigue
	c.loyalty = loyalty
	c.employed = employed
	c.on_rest = on_rest
	c.on_assignment = on_assignment
	c.traits = traits.duplicate()
	return c


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"dept": dept,
		"role": role,
		"xp": xp,
		"fatigue": fatigue,
		"loyalty": loyalty,
		"employed": employed,
		"on_rest": on_rest,
		"on_assignment": on_assignment,
		"traits": Array(traits),
	}
