extends Control
## The persistent heads-up display during a day — built in code.
##
## Shows the day counter, budget, progress toward the profit target, and the
## buttons that open the management screens. Reads the live state through the
## Game autoload and refreshes on every state_changed. Buttons emit signals
## rather than opening screens directly, so the parent scene decides navigation.

signal open_dispatch()
signal open_personnel()
signal open_investigations()
signal open_economy()
signal end_day_requested()

var _day_label: Label
var _budget_label: Label
var _target_label: Label
var _dispatch_button: Button
var _personnel_button: Button
var _investigations_button: Button
var _economy_button: Button
var _end_day_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Let clicks pass through everywhere except the bar itself.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# A bottom-anchored panel holding the whole HUD.
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -70.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	# Pad the bar contents a little so labels do not touch the panel edges.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.add_child(hbox)
	bar.add_child(margin)

	_day_label = Label.new()
	hbox.add_child(_day_label)
	_budget_label = Label.new()
	hbox.add_child(_budget_label)
	_target_label = Label.new()
	hbox.add_child(_target_label)

	# Flexible spacer pushes the screen buttons to the right.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_dispatch_button = Button.new()
	hbox.add_child(_dispatch_button)
	_personnel_button = Button.new()
	hbox.add_child(_personnel_button)
	_investigations_button = Button.new()
	hbox.add_child(_investigations_button)
	_economy_button = Button.new()
	hbox.add_child(_economy_button)
	_end_day_button = Button.new()
	hbox.add_child(_end_day_button)

	_dispatch_button.pressed.connect(func() -> void: open_dispatch.emit())
	_personnel_button.pressed.connect(func() -> void: open_personnel.emit())
	_investigations_button.pressed.connect(func() -> void: open_investigations.emit())
	_economy_button.pressed.connect(func() -> void: open_economy.emit())
	_end_day_button.pressed.connect(func() -> void: end_day_requested.emit())

	Game.state_changed.connect(_refresh)
	L10n.locale_changed.connect(_refresh_labels)
	_refresh_labels()


func _refresh(_unused: Variant = null) -> void:
	if Game.state == null:
		return
	_day_label.text = "%s %d/%d" % [L10n.t("hud.day"), Game.current_day(), GameState.CAMPAIGN_DAYS]
	_budget_label.text = "%s: %d" % [L10n.t("hud.money"), Game.budget()]
	_target_label.text = "%s: %d / %d" % [L10n.t("hud.target"), Game.profit_banked(), Game.target()]


func _refresh_labels(_locale: String = "") -> void:
	_dispatch_button.text = L10n.t("hud.dispatch")
	_personnel_button.text = L10n.t("hud.personnel")
	_investigations_button.text = L10n.t("hud.investigations")
	_economy_button.text = L10n.t("hud.economy")
	_end_day_button.text = L10n.t("hud.end_day")
	_refresh()
