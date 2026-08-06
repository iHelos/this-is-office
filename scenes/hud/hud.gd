extends Control
## The persistent heads-up display during a day.
##
## Shows the day counter, budget, progress toward the profit target, and the
## buttons that open the management screens (Dispatch, Personnel, Investigations,
## Economy). It reads the live state through the Game autoload and refreshes on
## every [signal Game.state_changed]. Buttons emit signals rather than opening
## screens directly, so the parent scene decides what "open" means.

signal open_dispatch()
signal open_personnel()
signal open_investigations()
signal open_economy()
signal end_day_requested()

@onready var day_label: Label = %DayLabel
@onready var budget_label: Label = %BudgetLabel
@onready var target_label: Label = %TargetLabel
@onready var dispatch_button: Button = %DispatchButton
@onready var personnel_button: Button = %PersonnelButton
@onready var investigations_button: Button = %InvestigationsButton
@onready var economy_button: Button = %EconomyButton
@onready var end_day_button: Button = %EndDayButton


func _ready() -> void:
	dispatch_button.pressed.connect(func() -> void: open_dispatch.emit())
	personnel_button.pressed.connect(func() -> void: open_personnel.emit())
	investigations_button.pressed.connect(func() -> void: open_investigations.emit())
	economy_button.pressed.connect(func() -> void: open_economy.emit())
	end_day_button.pressed.connect(func() -> void: end_day_requested.emit())
	Game.state_changed.connect(_refresh)
	L10n.locale_changed.connect(_refresh_labels)
	_refresh_labels()
	_refresh()


func _refresh(_unused: Variant = null) -> void:
	if Game.state == null:
		return
	day_label.text = "%s %d/%d" % [L10n.t("hud.day"), Game.current_day(), GameState.CAMPAIGN_DAYS]
	budget_label.text = "%s: %d" % [L10n.t("hud.money"), Game.budget()]
	target_label.text = "%s: %d / %d" % [L10n.t("hud.target"), Game.profit_banked(), Game.target()]


func _refresh_labels(_locale: String = "") -> void:
	dispatch_button.text = L10n.t("hud.dispatch")
	personnel_button.text = L10n.t("hud.personnel")
	investigations_button.text = L10n.t("hud.investigations")
	economy_button.text = L10n.t("hud.economy")
	end_day_button.text = L10n.t("hud.end_day")
	_refresh()
