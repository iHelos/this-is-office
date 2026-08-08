extends Control
## The root of a gameplay day — UI assembled in code.
##
## Hosts the office backdrop, the day/chapter banner, the HUD, and the modal
## management screens. Everything is built in _ready() with Control.new() and
## scene instantiation, so there is no hand-written .tscn node tree to go wrong
## (the earlier silent bugs all lived in such trees). The HUD's open-screen
## signals are routed to the corresponding views' open().

const HUD_SCENE := preload("res://scenes/hud/hud.tscn")
const DISPATCH_SCENE := preload("res://scenes/dispatch/dispatch_view.tscn")
const PERSONNEL_SCENE := preload("res://scenes/personnel/personnel_view.tscn")
const ECONOMY_SCENE := preload("res://scenes/economy/economy_view.tscn")
const INVESTIGATIONS_SCENE := preload("res://scenes/investigations/investigations_view.tscn")
const CUTSCENE_SCENE := preload("res://scenes/cutscene/cutscene_view.tscn")

var _hud: Control
var _notice: Label
var _dispatch_view: Control
var _personnel_view: Control
var _economy_view: Control
var _investigations_view: Control
var _cutscene_view: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Office backdrop (flat colour until the isometric art lands).
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.16, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Placeholder marker for where the isometric office view will go.
	var placeholder := Label.new()
	placeholder.text = "[ isometric office view — coming ]"
	placeholder.set_anchors_preset(Control.PRESET_CENTER)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.modulate = Color(0.6, 0.6, 0.6, 1)
	add_child(placeholder)

	# Day/chapter banner, sits above the HUD.
	_notice = Label.new()
	_notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice.offset_top = -170.0
	_notice.offset_bottom = -110.0
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notice)

	# The HUD bar across the bottom.
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)

	# Modal management screens — created hidden, shown by open().
	_dispatch_view = DISPATCH_SCENE.instantiate()
	add_child(_dispatch_view)
	_personnel_view = PERSONNEL_SCENE.instantiate()
	add_child(_personnel_view)
	_economy_view = ECONOMY_SCENE.instantiate()
	add_child(_economy_view)
	_investigations_view = INVESTIGATIONS_SCENE.instantiate()
	add_child(_investigations_view)
	_cutscene_view = CUTSCENE_SCENE.instantiate()
	add_child(_cutscene_view)

	_hud.open_dispatch.connect(_open_dispatch)
	_hud.open_personnel.connect(_open_personnel)
	_hud.open_investigations.connect(_open_investigations)
	_hud.open_economy.connect(_open_economy)
	_hud.end_day_requested.connect(_on_end_day)

	_show_morning(Game.current_day())


func _open_dispatch() -> void:
	_dispatch_view.open()


func _open_personnel() -> void:
	_personnel_view.open()


func _open_investigations() -> void:
	_investigations_view.open()


func _open_economy() -> void:
	_economy_view.open()


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
		_notice.text = "%s — %s" % [L10n.t(chapter.act_title_key), L10n.t(chapter.title_key)]
	else:
		_notice.text = ""
	var pending: Cutscene = Game.pending_cutscene()
	if pending != null:
		_cutscene_view.play(pending)
