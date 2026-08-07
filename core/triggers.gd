class_name Triggers
extends RefCounted
## Reactive cutscene condition evaluation.
##
## Most cutscenes are scripted by day (the chapter system drives them). A
## cutscene that also carries a [code]trigger[/code] block only fires when its
## predicates evaluate true against the live state — e.g. a mutiny cutscene that
## plays once the team's average loyalty drops below a threshold.
##
## Predicates are intentionally a small, declarative set so they can be authored
## in JSON and asserted in tests without a scripting engine:
##
## [codeblock]
## "trigger": {
##   "all": [
##     {"flag_eq": ["review_done", true]},
##     {"avg_loyalty_below": -0.4}
##   ]
## }
## [/codeblock]

const Employee := preload("res://core/employee.gd")


## Evaluate a trigger dictionary against a GameState. An empty trigger fires
## unconditionally (the scripted-day path); a missing trigger is the same.
static func evaluate(state: Variant, trigger: Dictionary) -> bool:
	if trigger.is_empty():
		return true
	return _eval_node(state, trigger)


static func _eval_node(state: Variant, node: Variant) -> bool:
	# A node is either a combinator dict ({all: [...]} / {any: [...]}) or a
	# single predicate dict ({flag_eq: [k, v]}). This keeps the format uniform.
	var d: Dictionary = node as Dictionary
	if d.has("all"):
		for child: Variant in d["all"]:
			if not _eval_node(state, child):
				return false
		return true
	if d.has("any"):
		for child: Variant in d["any"]:
			if _eval_node(state, child):
				return true
		return false
	if d.has("not"):
		return not _eval_node(state, d["not"])
	return _eval_predicate(state, d)


static func _eval_predicate(state: Variant, pred: Dictionary) -> bool:
	# Each predicate is one key mapping to its argument list. Unknown predicates
	# fail closed (return false) so a typo never silently fires a cutscene.
	if pred.has("flag_eq"):
		var args: Array = pred["flag_eq"]
		var key: String = String(args[0])
		var want: Variant = args[1]
		return state.flags.get(key, null) == want
	if pred.has("flag_set"):
		return state.flags.has(String(pred["flag_set"]))
	if pred.has("avg_loyalty_below"):
		return _avg_loyalty(state) < float(pred["avg_loyalty_below"])
	if pred.has("avg_loyalty_above"):
		return _avg_loyalty(state) > float(pred["avg_loyalty_above"])
	if pred.has("budget_below"):
		return state.budget < int(pred["budget_below"])
	if pred.has("budget_above"):
		return state.budget > int(pred["budget_above"])
	if pred.has("profit_banked_above"):
		return state.profit_banked > int(pred["profit_banked_above"])
	push_warning("Triggers: unknown predicate %s" % str(pred.keys()))
	return false


static func _avg_loyalty(state: Variant) -> float:
	# Average loyalty across employed staff only; fired/unemployed do not vote.
	var sum := 0.0
	var count := 0
	for e: Employee in state.employees:
		if e.employed:
			sum += e.loyalty
			count += 1
	if count == 0:
		return 0.0
	return sum / float(count)
