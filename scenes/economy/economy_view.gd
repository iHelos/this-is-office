extends Control
## The economy screen and the end-of-day ledger — built in code.

var _budget_label: Label
var _target_bar: ProgressBar
var _target_label: Label
var _salaries_label: Label
var _contract_list: VBoxContainer
var _ending_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	add_child(_make_dim())
	var panel: Control = _make_panel()

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = L10n.t("economy.title")
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	_budget_label = Label.new()
	vbox.add_child(_budget_label)
	_target_label = Label.new()
	vbox.add_child(_target_label)
	_target_bar = ProgressBar.new()
	_target_bar.custom_minimum_size = Vector2(0, 24)
	_target_bar.show_percentage = false
	vbox.add_child(_target_bar)
	_salaries_label = Label.new()
	vbox.add_child(_salaries_label)

	var hdr := Label.new()
	hdr.text = L10n.t("economy.contracts")
	vbox.add_child(hdr)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_contract_list = VBoxContainer.new()
	_contract_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contract_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_contract_list)

	_ending_label = Label.new()
	_ending_label.add_theme_font_size_override("font_size", 20)
	_ending_label.visible = false
	vbox.add_child(_ending_label)

	var close_btn := Button.new()
	close_btn.text = L10n.t("economy.end")
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func() -> void: visible = false)
	vbox.add_child(close_btn)

	Game.state_changed.connect(_refresh)
	L10n.locale_changed.connect(_on_locale)


func _on_locale(_l: String) -> void:
	# Rebuild contract rows whose labels depend on locale.
	_refresh()


func _make_dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim


func _make_panel() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60.0
	panel.offset_top = 60.0
	panel.offset_right = -60.0
	panel.offset_bottom = -100.0
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	return margin


func open() -> void:
	_refresh()
	visible = true


func _refresh(_unused: Variant = null) -> void:
	if not visible or Game.state == null:
		return
	_budget_label.text = "%s: $%d" % [L10n.t("economy.budget"), Game.budget()]
	var banked: int = Game.profit_banked()
	var target: int = Game.target()
	_target_bar.max_value = maxi(target, 1)
	_target_bar.value = mini(banked, target)
	_target_label.text = "%s: $%d / $%d" % [L10n.t("economy.target"), banked, target]
	_salaries_label.text = "%s: -$%d" % [L10n.t("economy.daily_salaries"), Game.daily_salaries()]
	for c: Node in _contract_list.get_children():
		_contract_list.remove_child(c)
		c.queue_free()
	if Game.campaign_over():
		_refresh_ending()
		return
	for raw: Variant in Game.contract_catalog:
		var contract: Dictionary = raw as Dictionary
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var t := Label.new()
		t.text = L10n.t(String(contract.get("title_key", "")))
		t.custom_minimum_size = Vector2(200, 0)
		row.add_child(t)
		var d := Label.new()
		d.text = L10n.t(String(contract.get("desc_key", "")))
		d.custom_minimum_size = Vector2(320, 0)
		d.modulate = Color(0.75, 0.75, 0.75)
		row.add_child(d)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var button := Button.new()
		button.text = "+$%d" % int(contract.get("budget_delta", 0))
		var id: String = String(contract.get("id", ""))
		button.disabled = bool(contract.get("once_per_day", false)) and Game.contracts_used_today.has(id)
		button.pressed.connect(Game.take_contract.bind(id))
		row.add_child(button)
		_contract_list.add_child(row)
	_refresh_ending()


func _refresh_ending() -> void:
	if not Game.campaign_over():
		_ending_label.visible = false
		return
	_ending_label.visible = true
	var outcome: String = Game.ending_outcome()
	var ally: String = Game.allied_faction()
	var key := "ending.%s.%s" % [outcome, "allied" if not ally.is_empty() else "solo"]
	_ending_label.text = L10n.t(key)
	if not ally.is_empty():
		var faction: Faction = Game.state.faction_by_id(ally)
		var ally_name: String = L10n.t(faction.name_key) if faction != null else ally
		_ending_label.text += "\n%s %s" % [L10n.t("ending.allied"), ally_name]
