class_name Ticket
extends RefCounted
## A unit of incoming work, the corporate analogue of a 911 call.
##
## Tickets arrive during the dispatch phase (§5) with a timer. The player
## assigns employees; [code]core/resolve.gd[/code] turns the assignment into an
## outcome against [member severity]. Everything here is plain data so a ticket
## can be cloned into the next deterministic state unchanged.

var id: String = ""
var kind: String = ""           # "bug" | "release" | "client_hotfix" | "demo" | ...
var source_dept: String = ""    # which department or client filed it
var severity: int = 100         # higher = harder; opposed by effective skill (§4)
var ttl: int = 0                # ticks remaining before the ticket auto-fumbles
var reward: int = 0             # budget paid on a clean resolution
var penalty: int = 0            # budget lost on a fumble or timeout
var xp_primary: int = 10        # xp granted to primary assignees on a clean solve
var xp_backup: int = 5          # xp granted to backups
var requires_roles: PackedStringArray = PackedStringArray()  # gate: empty = any role
var state: String = "open"      # "open" | "assigned" | "clean" | "fumbled" | "expired"


static func from_dict(d: Dictionary) -> Ticket:
	var tk := Ticket.new()
	tk.id = String(d.get("id", ""))
	tk.kind = String(d.get("kind", ""))
	tk.source_dept = String(d.get("source_dept", ""))
	tk.severity = int(d.get("severity", 100))
	tk.ttl = int(d.get("ttl", 0))
	tk.reward = int(d.get("reward", 0))
	tk.penalty = int(d.get("penalty", 0))
	tk.xp_primary = int(d.get("xp_primary", 10))
	tk.xp_backup = int(d.get("xp_backup", 5))
	tk.state = String(d.get("state", "open"))
	var raw: Array = d.get("requires_roles", [])
	var arr := PackedStringArray()
	for r: Variant in raw:
		arr.append(String(r))
	tk.requires_roles = arr
	return tk


func clone() -> Ticket:
	var c := Ticket.new()
	c.id = id
	c.kind = kind
	c.source_dept = source_dept
	c.severity = severity
	c.ttl = ttl
	c.reward = reward
	c.penalty = penalty
	c.xp_primary = xp_primary
	c.xp_backup = xp_backup
	c.requires_roles = requires_roles.duplicate()
	c.state = state
	return c


func to_dict() -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"source_dept": source_dept,
		"severity": severity,
		"ttl": ttl,
		"reward": reward,
		"penalty": penalty,
		"xp_primary": xp_primary,
		"xp_backup": xp_backup,
		"requires_roles": Array(requires_roles),
		"state": state,
	}
