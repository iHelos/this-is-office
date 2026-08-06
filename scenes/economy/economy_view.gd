extends Control
## The economy screen and the end-of-day ledger.
##
## Shows budget, progress toward the profit target, daily salaries, and the side
## contracts (the analogue of TITP's side income — money now for fatigue or
## loyalty later). On day 180 it flips into the ending readout instead, so the
## player sees how the campaign landed without a separate scene.

@onready var title_label: Label = %TitleLabel
@onready var budget_label: Label = %BudgetLabel
@onready var target_bar: ProgressBar = %TargetBar
@onready var target_label: Label = %TargetLabel
@onready var salaries_label: Label = %SalariesLabel
@onready var contract_list: VBoxContainer = %ContractList
@onready var ending_label: Label = %EndingLabel
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.text = L10n.t("economy.end")
	close_button.pressed.connect(func() -> void: visible = false)
	Game.state_changed.connect(_refresh)
	L10n.locale_changed.connect(_refresh_labels)
	_refresh_labels()


func open() -> void:
	_refresh()
	visible = true


func _refresh_labels(_locale: String = "") -> void:
	title_label.text = L10n.t("economy.title")
	close_button.text = L10n.t("economy.end")
	_refresh()


func _refresh(_unused: Variant = null) -> void:
	if Game.state == null:
		return
	budget_label.text = "%s: $%d" % [L10n.t("economy.budget"), Game.budget()]
	var banked: int = Game.profit_banked()
	var target: int = Game.target()
	target_bar.max_value = maxi(target, 1)
	target_bar.value = mini(banked, target)
	target_label.text = "%s: $%d / $%d" % [L10n.t("economy.target"), banked, target]
	salaries_label.text = "%s: -$%d" % [L10n.t("economy.daily_salaries"), Game.daily_salaries()]
	_populate_contracts()
	_refresh_ending()


func _populate_contracts() -> void:
	for c: Node in contract_list.get_children():
		contract_list.remove_child(c)
		c.queue_free()
	if Game.campaign_over():
		return
	for raw: Variant in Game.contract_catalog:
		var contract: Dictionary = raw as Dictionary
		var row := HBoxContainer.new()
		row.theme_override_constants_separation = 12
		var title := Label.new()
		title.text = L10n.t(String(contract.get("title_key", "")))
		title.custom_minimum_size = Vector2(200, 0)
		row.add_child(title)
		var desc := Label.new()
		desc.text = L10n.t(String(contract.get("desc_key", "")))
		desc.custom_minimum_size = Vector2(320, 0)
		desc.modulate = Color(0.75, 0.75, 0.75)
		row.add_child(desc)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var button := Button.new()
		button.text = "+$%d" % int(contract.get("budget_delta", 0))
		var id: String = String(contract.get("id", ""))
		button.disabled = bool(contract.get("once_per_day", false)) and Game.contracts_used_today.has(id)
		button.pressed.connect(Game.take_contract.bind(id))
		row.add_child(button)
		contract_list.add_child(row)


func _refresh_ending() -> void:
	if not Game.campaign_over():
		ending_label.visible = false
		return
	ending_label.visible = true
	# The ending is shaped by both whether the target was hit and whether the
	# player allied with a faction on day 12. Four combinations, four texts.
	var outcome: String = Game.ending_outcome()
	var ally: String = Game.allied_faction()
	var has_ally := not ally.is_empty()
	var key := "ending.%s.%s" % [outcome, "allied" if has_ally else "solo"]
	ending_label.text = L10n.t(key)
	if has_ally:
		var faction: Faction = Game.state.faction_by_id(ally)
		var ally_name: String = L10n.t(faction.name_key) if faction != null else ally
		ending_label.text += "\n%s %s" % [L10n.t("ending.allied"), ally_name]
	ending_label.add_theme_font_size_override("font_size", 20)
