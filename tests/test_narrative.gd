extends RefCounted
## Pins the narrative choice path and the faction-aware ending.
##
## The day-12 faction allegiance is the campaign's hinge decision: it sets a
## flag the ending screen reads and shifts the chosen faction's standing. This
## suite drives the autoload directly (the UI prompt just routes here) to assert
## the flag is set, the standing moves, allied_faction() reports it, and the
## ending key resolves to the allied variant.

func run(t: TestCase) -> void:
	_faction_choice_sets_flag_and_standing(t)
	_allied_faction_reports_choice(t)
	_ending_key_reflects_alliance(t)


func _faction_choice_sets_flag_and_standing(t: TestCase) -> void:
	Game.start_new_game(5)
	var meridian: Faction = Game.state.faction_by_id("meridian")
	var before: float = meridian.standing
	Game.apply_narrative_choice("faction_choice", "meridian", "meridian", 0.5)
	t.eq(Game.state.flags.get("faction_choice", ""), "meridian", "the faction_choice flag is set")
	t.ok(meridian.standing > before, "the chosen faction's standing rises")


func _allied_faction_reports_choice(t: TestCase) -> void:
	Game.start_new_game(5)
	t.eq(Game.allied_faction(), "", "no ally before a choice is made")
	Game.apply_narrative_choice("faction_choice", "vertex", "vertex", 0.5)
	t.eq(Game.allied_faction(), "vertex", "allied_faction reports the chosen faction")


func _ending_key_reflects_alliance(t: TestCase) -> void:
	# The ending screen composes its i18n key from outcome + allied/solo. We
	# cannot read the label from the scene here, but we can pin the inputs the
	# label is built from, which is what keeps the four endings distinct.
	Game.start_new_game(5)
	t.eq(Game.ending_outcome(), "target_missed", "fresh game: target not yet hit")
	t.eq(Game.allied_faction(), "", "fresh game: no ally")
	Game.apply_narrative_choice("faction_choice", "meridian", "meridian", 0.5)
	Game.state.profit_banked = Game.state.target + 1
	t.eq(Game.ending_outcome(), "target_hit", "after banking profit: target hit")
	t.eq(Game.allied_faction(), "meridian", "after choosing: ally is meridian")
	# The composed key the economy screen builds:
	var key: String = "ending.%s.%s" % [Game.ending_outcome(), "allied" if not Game.allied_faction().is_empty() else "solo"]
	t.eq(key, "ending.target_hit.allied", "the composed ending key is target_hit.allied")
