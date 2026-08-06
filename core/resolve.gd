class_name Resolve
extends RefCounted
## Turns an assignment into an outcome. This is the heart of dispatch (§4).
##
## All randomness flows through the [code]Rng[/code] handed in by the caller, so
## a replay from the same seed reproduces the same outcomes byte-for-byte. The
## balance knobs live in [member balance] and are loaded from
## content/balance.json, so tuning never edits code.

const DEFAULT_SEVERITY_SCALE: float = 1.0
const DEFAULT_FLOOR: float = 0.05
const DEFAULT_CEIL: float = 0.97
const FATIGUE_PENALTY: float = 0.5     # a fully tired employee contributes half
const LOYALTY_FLOOR: float = 0.5       # a hostile employee still works, at half weight
const CLEAN_XP_PRIMARY: int = 10
const CLEAN_XP_BACKUP: int = 5
const FATIGUE_PER_ASSIGNMENT: float = 0.15


var severity_scale: float = DEFAULT_SEVERITY_SCALE
var floor_chance: float = DEFAULT_FLOOR
var var_ceil_chance: float = DEFAULT_CEIL


func apply_balance(d: Dictionary) -> void:
	severity_scale = float(d.get("severity_scale", DEFAULT_SEVERITY_SCALE))
	floor_chance = float(d.get("floor_chance", DEFAULT_FLOOR))
	var_ceil_chance = float(d.get("ceil_chance", DEFAULT_CEIL))


## Effective skill a team brings to a ticket. Fatigue halves contribution at the
## top end; loyalty ranges the per-employee weight from LOYALTY_FLOOR (hostile)
## to 1.0 (devoted). The formula is documented in docs/design.md §4.
func effective_skill(assigned: Array) -> float:
	var total := 0.0
	for e: Employee in assigned:
		if not e.employed:
			continue
		var fatigue_factor: float = 1.0 - FATIGUE_PENALTY * e.fatigue
		var loyalty_factor: float = LOYALTY_FLOOR + (1.0 - LOYALTY_FLOOR) * (e.loyalty + 1.0) * 0.5
		total += float(e.xp) * fatigue_factor * loyalty_factor
	return total


## Probability of a clean resolution, clamped to [floor, ceil]. The logistic
## shape means throwing more skill at a ticket has diminishing returns, which is
## what makes "send everyone" a poor default and "split your team" interesting.
func clean_chance(assigned: Array, severity: int) -> float:
	if assigned.is_empty():
		return 0.0
	var skill: float = effective_skill(assigned)
	var denom: float = skill + float(severity) * severity_scale
	if denom <= 0.0:
		return floor_chance
	var odds: float = skill / denom
	return clampf(odds, floor_chance, var_ceil_chance)


## Resolve a ticket. Returns a Dictionary with the outcome and the deltas to
## apply; the caller (Sim) applies them to a cloned state, never to the live one.
##
## Keys: [code]clean[/code] (bool), [code]budget_delta[/code] (int),
## [code]xp_awards[/code] (Dictionary employee_id -> int),
## [code]fatigue_added[/code] (float, applied to every assignee).
func resolve_ticket(ticket: Ticket, assigned: Array, rng: Rng) -> Dictionary:
	var chance: float = clean_chance(assigned, ticket.severity)
	var clean: bool = rng.fork("ticket_%s" % ticket.id).chance(chance)
	var budget_delta: int = ticket.reward if clean else -ticket.penalty
	var xp_awards: Dictionary = {}
	for i: int in assigned.size():
		var e: Employee = assigned[i]
		# Primary assignees are the first half of the team, the rest are backup.
		var is_primary: bool = i < maxi(1, assigned.size() / 2)
		var xp: int = 0
		if clean:
			xp = ticket.xp_primary if is_primary else ticket.xp_backup
		if xp > 0:
			xp_awards[e.id] = xp
	return {
		"clean": clean,
		"budget_delta": budget_delta,
		"xp_awards": xp_awards,
		"fatigue_added": FATIGUE_PER_ASSIGNMENT,
		"final_state": "clean" if clean else "fumbled",
	}
