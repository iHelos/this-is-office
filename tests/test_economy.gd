extends RefCounted
## Pins the budget arithmetic in isolation.
##
## Economy is deliberately a thin, pure layer (no randomness, no nodes) so its
## behaviour can be pinned with exact integers. These checks guard against
## sign-flip bugs (a penalty that pays you, a salary that bills the unemployed)
## that would otherwise hide inside the larger Sim step.

func run(t: TestCase) -> void:
	_daily_salaries_skip_unemployed(t)
	_settle_never_goes_negative(t)
	_settle_applies_signs(t)
	_apply_rest_recovers_fatigue_and_clears_flag(t)
	_apply_balance_overrides_defaults(t)


func _daily_salaries_skip_unemployed(t: TestCase) -> void:
	var e := Economy.new()
	var a := _emp(true)
	var b := _emp(true)
	var c := _emp(false)   # unemployed
	var total: int = e.daily_salaries([a, b, c])
	t.eq(total, e.salary_per_employee * 2, "only employed employees accrue salary")


func _settle_never_goes_negative(t: TestCase) -> void:
	var e := Economy.new()
	t.eq(e.settle(10, -100), 0, "a penalty larger than the budget floors at zero")
	t.eq(e.settle(0, 50), 50, "revenue from a zero budget is the revenue")


func _settle_applies_signs(t: TestCase) -> void:
	var e := Economy.new()
	t.eq(e.settle(100, 30), 130, "positive delta adds")
	t.eq(e.settle(100, -30), 70, "negative delta subtracts")


func _apply_rest_recovers_fatigue_and_clears_flag(t: TestCase) -> void:
	var e := Economy.new()
	var emp := _emp(true)
	emp.fatigue = 0.8
	emp.on_rest = true
	e.apply_rest([emp])
	t.less(emp.fatigue, 0.8, "rest reduces fatigue")
	t.ok(not emp.on_rest, "rest clears the on_rest flag")


func _apply_balance_overrides_defaults(t: TestCase) -> void:
	var e := Economy.new()
	e.apply_balance({"salary_per_employee": 99, "rest_recovery": 0.25})
	t.eq(e.salary_per_employee, 99, "apply_balance overrides salary")
	t.approx(e.rest_recovery, 0.25, 1e-6, "apply_balance overrides recovery")


func _emp(employed: bool) -> Employee:
	var e := Employee.new()
	e.employed = employed
	return e
