extends Control
## The incident board — the investigations screen. Built in code.

var active_incident_id: String = ""
var assigned_ids: Array = []

var _incident_list: VBoxContainer
var _detail_label: Label
var _progress_label: Label
var _gather_button: Button
var _choices_box: VBoxContainer
var _troubleshooter_list: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	add_child(_make_dim())
	var panel: Control = _make_panel()

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(columns)

	var inc_col := _labeled_column("Incidents")
	_incident_list = inc_col.find_child("List", true)
	columns.add_child(inc_col)

	var detail_col := VBoxContainer.new()
	detail_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_col.add_child(_detail_label)
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_col.add_child(_progress_label)
	_gather_button = Button.new()
	_gather_button.text = "Gather clues"
	_gather_button.custom_minimum_size = Vector2(0, 44)
	_gather_button.disabled = true
	_gather_button.pressed.connect(_on_gather)
	detail_col.add_child(_gather_button)
	_choices_box = VBoxContainer.new()
	_choices_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices_box.add_theme_constant_override("separation", 6)
	detail_col.add_child(_choices_box)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func() -> void: visible = false)
	detail_col.add_child(close_btn)
	columns.add_child(detail_col)

	var pool_col := _labeled_column("Troubleshooters")
	_troubleshooter_list = pool_col.find_child("List", true)
	columns.add_child(pool_col)

	Game.state_changed.connect(_refresh)


func _make_dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim


func _make_panel() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40.0
	panel.offset_top = 40.0
	panel.offset_right = -40.0
	panel.offset_bottom = -100.0
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	return margin


func _labeled_column(title: String) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = title
	col.add_child(lbl)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(260, 0)
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return col


func open() -> void:
	active_incident_id = ""
	assigned_ids.clear()
	_refresh()
	visible = true


func _refresh(_unused: Variant = null) -> void:
	if not visible:
		return
	_clear(_incident_list)
	_clear(_troubleshooter_list)
	_clear(_choices_box)
	for inc: Incident in Game.state.incidents:
		var btn := Button.new()
		btn.text = "%s [%s] — %d/%d" % [L10n.t(inc.title), inc.state, inc.clues_found, inc.clues_total]
		btn.disabled = inc.state == "closed"
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(_on_incident_selected.bind(inc.id))
		if inc.id == active_incident_id:
			btn.modulate = Color(1.3, 1.3, 0.7)
		_incident_list.add_child(btn)
	for e: Employee in Game.state.employees:
		if e.role != "troubleshooter" or not e.employed:
			continue
		var btn := Button.new()
		btn.text = "%s · xp %d · fat %.0f%%" % [e.name, e.xp, e.fatigue * 100.0]
		btn.custom_minimum_size = Vector2(0, 44)
		btn.disabled = e.on_rest
		btn.pressed.connect(_on_troubleshooter_toggled.bind(e.id))
		if assigned_ids.has(e.id):
			btn.modulate = Color(0.6, 0.9, 0.6)
		_troubleshooter_list.add_child(btn)
	_refresh_detail()


func _refresh_detail() -> void:
	if active_incident_id.is_empty():
		_detail_label.text = "(select an incident)"
		_progress_label.text = ""
		_gather_button.disabled = true
		return
	var inc: Incident = _find_incident(active_incident_id)
	if inc == null:
		active_incident_id = ""
		_refresh_detail()
		return
	_detail_label.text = "%s · %s · sev %d" % [L10n.t(inc.title), inc.kind, inc.severity]
	_progress_label.text = "clues %d / %d" % [inc.clues_found, inc.clues_total]
	_gather_button.disabled = inc.state != "open" or assigned_ids.is_empty()
	if inc.state == "deducing":
		var prompt := Label.new()
		prompt.text = "Choose how to close:"
		_choices_box.add_child(prompt)
		for raw: Variant in inc.choices:
			var choice: Dictionary = raw as Dictionary
			var btn := Button.new()
			btn.text = "%s  (+$%d, standing %+.1f, power %+d)" % [
				String(choice.get("id", "")),
				int(choice.get("budget_delta", 0)),
				float(choice.get("standing_delta", 0.0)),
				int(choice.get("faction_power_delta", 0)),
			]
			btn.custom_minimum_size = Vector2(0, 40)
			btn.pressed.connect(Game.close_incident.bind(inc.id, String(choice.get("id", ""))))
			_choices_box.add_child(btn)


func _on_incident_selected(id: String) -> void:
	active_incident_id = id
	assigned_ids.clear()
	_refresh()


func _on_troubleshooter_toggled(id: String) -> void:
	if assigned_ids.has(id):
		assigned_ids.erase(id)
	else:
		assigned_ids.append(id)
	_refresh()


func _on_gather() -> void:
	if active_incident_id.is_empty():
		return
	Game.assign_troubleshooters(active_incident_id, assigned_ids.duplicate())


func _find_incident(id: String) -> Incident:
	for inc: Incident in Game.state.incidents:
		if inc.id == id:
			return inc
	return null


func _clear(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()
