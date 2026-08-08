extends Control
## The dispatch board — the core gameplay loop. Built in code.
##
## Three columns: the open ticket queue (left), the active ticket with its
## assembled team and the live success chance (centre), and the employee pool
## (right). Click an open ticket to make it active; click an employee to toggle
## them onto the active team; Send resolves the ticket through Game.assign_ticket
## and the board refreshes on Game.state_changed. Resolved tickets stay on the
## board coloured by outcome so the player sees what just happened.

var active_ticket_id: String = ""
var assigned_ids: Array = []

var _ticket_list: VBoxContainer
var _employee_list: VBoxContainer
var _active_label: Label
var _chance_label: Label
var _send_button: Button


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

	# Left: tickets.
	var tickets_col := _labeled_column("Tickets")
	_ticket_list = tickets_col.find_child("List", true)
	columns.add_child(tickets_col)

	# Centre: active ticket + actions.
	var active_col := VBoxContainer.new()
	active_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_active_label = Label.new()
	_active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_col.add_child(_active_label)
	_chance_label = Label.new()
	_chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_col.add_child(_chance_label)
	_send_button = Button.new()
	_send_button.text = "Send team"
	_send_button.custom_minimum_size = Vector2(0, 44)
	_send_button.disabled = true
	_send_button.pressed.connect(_on_send)
	active_col.add_child(_send_button)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func() -> void: visible = false)
	active_col.add_child(close_btn)
	columns.add_child(active_col)

	# Right: employee pool.
	var pool_col := _labeled_column("Available staff")
	_employee_list = pool_col.find_child("List", true)
	columns.add_child(pool_col)

	Game.state_changed.connect(_refresh)


func _make_dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim


func _make_panel() -> Control:
	# Builds the modal PanelContainer with inner margins, attaches it to the
	# screen, and returns the inner MarginContainer (where callers put content).
	# Returning the inner node lets callers stay agnostic of the wrapper.
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
	scroll.custom_minimum_size = Vector2(280, 0)
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return col


func open() -> void:
	active_ticket_id = ""
	assigned_ids.clear()
	_refresh()
	visible = true


func _on_send() -> void:
	if active_ticket_id.is_empty() or assigned_ids.is_empty():
		return
	Game.assign_ticket(active_ticket_id, assigned_ids.duplicate())
	active_ticket_id = ""
	assigned_ids.clear()


func _refresh(_unused: Variant = null) -> void:
	if not visible:
		return
	_clear(_ticket_list)
	_clear(_employee_list)
	for tk: Ticket in Game.state.tickets:
		var btn := Button.new()
		btn.text = "%s · %s\nsev %d · +$%d / -$%d · [%s]" % [tk.kind, tk.source_dept, tk.severity, tk.reward, tk.penalty, tk.state]
		btn.disabled = tk.state != "open"
		btn.custom_minimum_size = Vector2(0, 56)
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		# Tint by outcome.
		match tk.state:
			"clean": btn.modulate = Color(0.6, 0.9, 0.6)
			"fumbled", "expired": btn.modulate = Color(0.9, 0.5, 0.5)
		btn.pressed.connect(_on_ticket_selected.bind(tk.id))
		if tk.id == active_ticket_id:
			btn.modulate = Color(1.3, 1.3, 0.7)
		_ticket_list.add_child(btn)
	for e: Employee in Game.state.employees:
		if not e.employed:
			continue
		var btn := Button.new()
		btn.text = "%s · %s\nxp %d · fat %.0f%% · loy %+.1f" % [e.name, e.role, e.xp, e.fatigue * 100.0, e.loyalty]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.disabled = e.on_rest
		btn.pressed.connect(_on_employee_toggled.bind(e.id))
		if assigned_ids.has(e.id):
			btn.modulate = Color(0.6, 0.9, 0.6)
		_employee_list.add_child(btn)
	_refresh_active()


func _refresh_active() -> void:
	if active_ticket_id.is_empty():
		_active_label.text = "(select a ticket)"
		_chance_label.text = ""
		_send_button.disabled = true
		return
	var ticket: Ticket = _find_ticket(active_ticket_id)
	if ticket == null:
		active_ticket_id = ""
		_refresh_active()
		return
	var team: Array = []
	for id: String in assigned_ids:
		var e: Employee = Game.state.employee_by_id(id)
		if e != null:
			team.append(e)
	var resolve := Resolve.new()
	resolve.apply_balance(ContentLoader.balance())
	var chance: float = resolve.clean_chance(team, ticket.severity)
	_active_label.text = "%s · sev %d · team %d" % [ticket.kind, ticket.severity, team.size()]
	_chance_label.text = "clean chance: %d%%" % [int(chance * 100)]
	_send_button.disabled = team.is_empty() or ticket.state != "open"


func _on_ticket_selected(id: String) -> void:
	active_ticket_id = id
	_refresh()


func _on_employee_toggled(id: String) -> void:
	if assigned_ids.has(id):
		assigned_ids.erase(id)
	else:
		assigned_ids.append(id)
	_refresh()


func _find_ticket(id: String) -> Ticket:
	for tk: Ticket in Game.state.tickets:
		if tk.id == id:
			return tk
	return null


func _clear(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()
