class_name Economy
extends RefCounted
## Pure budget arithmetic, kept separate from the rest of the core so the
## balance of money is testable in isolation.
##
## Nothing here touches a node or rolls its own randomness; any stochastic side
## effects of money (side contracts, audits) are decided by the caller with the
## RNG and handed in as numbers. This keeps [code]Economy[/code] a pure function
## of its inputs.

# Defaults mirror docs/design.md. content/balance.json overrides these at load,
# so tuning never edits code.
const DEFAULT_SALARY_PER_EMPLOYEE: int = 60
const DEFAULT_REST_RECOVERY: float = 0.6


var salary_per_employee: int = DEFAULT_SALARY_PER_EMPLOYEE
var rest_recovery: float = DEFAULT_REST_RECOVERY


func apply_balance(d: Dictionary) -> void:
	# Loaded from content/balance.json by the caller; missing keys keep defaults.
	salary_per_employee = int(d.get("salary_per_employee", DEFAULT_SALARY_PER_EMPLOYEE))
	rest_recovery = float(d.get("rest_recovery", DEFAULT_REST_RECOVERY))


## Total salary accrued by the current staff for one day.
func daily_salaries(employees: Array) -> int:
	var total := 0
	for e: Employee in employees:
		if e.employed:
			total += salary_per_employee
	return total


## Apply revenue/penalty to a budget integer. Negative amounts subtract.
func settle(budget: int, delta: int) -> int:
	return maxi(budget + delta, 0)


## Recover fatigue for any employee flagged on_rest. Mutates the array's
## employees in place, which is fine because the caller passes a cloned state.
func apply_rest(employees: Array) -> void:
	for e: Employee in employees:
		if e.employed and e.on_rest:
			e.fatigue = clampf(e.fatigue - rest_recovery, 0.0, 1.0)
			e.on_rest = false
