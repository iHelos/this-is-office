extends Control
## The root of a gameplay day.
##
## Hosts the office backdrop and the HUD, and routes the HUD's open-screen
## signals to the right management view. For Phase 3 only End Day is wired to a
## real effect (it rolls the simulation forward); the screen buttons print a
## placeholder until their views land in Phases 4-7. The office backdrop is a
## flat colour for now — the isometric office view replaces it in Phase 4.

@onready var hud: Control = $HUD
@onready var notice: Label = %Notice
@onready var dispatch_view: Control = $DispatchView
@onready var personnel_view: Control = $PersonnelView
@onready var economy_view: Control = $EconomyView
@onready var investigations_view: Control = $InvestigationsView
@onready var narrative_view: Control = $NarrativeView
@onready var cutscene_view: Control = $CutsceneView


func _ready() -> void:
	hud.open_dispatch.connect(_open_dispatch)
	hud.open_personnel.connect(_open_personnel)
	hud.open_investigations.connect(_open_investigations)
	hud.open_economy.connect(_open_economy)
	hud.end_day_requested.connect(_on_end_day)
	narrative_view.chosen.connect(_on_narrative_choice)
	_show_morning(Game.current_day())


func _open_dispatch() -> void:
	dispatch_view.open()


func _open_personnel() -> void:
	personnel_view.open()


func _open_investigations() -> void:
	investigations_view.open()


func _open_economy() -> void:
	economy_view.open()


func _on_end_day() -> void:
	# Collect any rest the player staged in the personnel screen, then roll. This
	# keeps the one canonical end-of-day path and applies rest deterministically.
	Game.end_day_with_staged_rest()
	_show_morning(Game.current_day())


func _show_morning(day: int) -> void:
	# Each morning: show the chapter banner (act + title) as the day's framing
	# text, then play any cutscene the chapter system or a reactive trigger has
	# queued. The intro-text hack from the scenario is superseded by chapters.
	var chapter: Chapter = Game.chapter_for_day(day)
	if chapter != null:
		notice.text = "%s — %s" % [L10n.t(chapter.act_title_key), L10n.t(chapter.title_key)]
	else:
		notice.text = ""
	var pending: Cutscene = Game.pending_cutscene()
	if pending != null:
		cutscene_view.play(pending)


func _on_narrative_choice(_option_id: String, _flag_key: String, _flag_value: String) -> void:
	# Retained hook for the legacy narrative_view; the faction choice now flows
	# through the cutscene system (cs_faction_choice on chapter ch_faction_choice).
	# Keep the connection so the narrative_view still compiles if reused later.
	pass


func _show_notice(screen: String) -> void:
	# Phase 3 placeholder: the management screens are built in Phases 4-7. Until
	# then the buttons confirm they are wired and which screen they represent.
	notice.text = "(%s — coming in a later phase)" % screen
