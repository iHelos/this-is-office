extends Node
## Bridge between the deterministic core and the UI.
##
## The core (see [code]core/[/code]) is pure: it knows nothing about nodes,
## scenes, or the SceneTree. The UI knows nothing about how a day advances.
## This singleton is the only place they meet. Screens read [member state] and
## listen to [signal state_changed]; they never mutate the state directly,
## they ask this autoload to apply an action through the core.
##
## This file deliberately starts small and grows with the core. Right now it
## owns the seed and a placeholder day counter so the HUD and menu have
## something to render while the simulation lands in Phase 1.

signal state_changed()

const Rng := preload("res://core/rng.gd")

const CAMPAIGN_DAYS: int = 180
const STARTING_BUDGET: int = 50000
const PROFIT_TARGET: int = 500000

var seed_value: int = 0
var state: Dictionary = {}


func _ready() -> void:
	_reset_state()


func start_new_game(seed_value_: int) -> void:
	seed_value = seed_value_
	_reset_state()
	state_changed.emit()


func current_day() -> int:
	return int(state.get("day", 1))


func budget() -> int:
	return int(state.get("budget", STARTING_BUDGET))


func end_day() -> void:
	# Placeholder until Sim.advance lands in Phase 1: advance the day counter and
	# accrue salary so the loop is observable. The real implementation will call
	# into the deterministic core and emit a fully recomputed state.
	state["day"] = min(current_day() + 1, CAMPAIGN_DAYS)
	state["budget"] = budget() - 100
	state_changed.emit()


func _reset_state() -> void:
	state = {
		"day": 1,
		"budget": STARTING_BUDGET,
		"target": PROFIT_TARGET,
	}
