class_name Faction
extends RefCounted
## A rival department, the corporate analogue of a crime family.
##
## Two of these exist per campaign (the Sand / Varga analogue, see design.md
## §2). [member standing] is the player's relation with the faction: rising it
## unlocks favours and side income; letting the *other* faction pull ahead for
# too long (§6, day 13) ends the run. [member power] tracks faction-vs-faction
## balance for the war check.

var id: String = ""
var name_key: String = ""       # i18n key, e.g. "faction.sand.name"
var agenda: String = ""         # short description key
var standing: float = 0.0       # -1..+1, the player's relation with this faction
var power: int = 0              # relative strength vs the other faction


static func from_dict(d: Dictionary) -> Faction:
	var f := Faction.new()
	f.id = String(d.get("id", ""))
	f.name_key = String(d.get("name_key", ""))
	f.agenda = String(d.get("agenda", ""))
	f.standing = float(d.get("standing", 0.0))
	f.power = int(d.get("power", 0))
	return f


func clone() -> Faction:
	var c := Faction.new()
	c.id = id
	c.name_key = name_key
	c.agenda = agenda
	c.standing = standing
	c.power = power
	return c


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name_key": name_key,
		"agenda": agenda,
		"standing": standing,
		"power": power,
	}
