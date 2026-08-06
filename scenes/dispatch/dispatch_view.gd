extends Control
## The dispatch board — the core gameplay loop.
##
## Three columns: the open ticket queue (left), the active ticket with its
## assembled team and the live success chance (centre), and the employee pool
## (right). Click an open ticket to make it active; click an employee to toggle
## them onto the active team; Send resolves the ticket through Game.assign_ticket
## and the board refreshes on Game.state_changed. Resolved tickets stay on the
## board coloured by outcome so the player sees what just happened.

const TicketCard := preload("res://ui/ticket_card.tscn")
const EmployeeCard := preload("res://ui/employee_card.tscn")

var active_ticket_id: String = ""
var assigned_ids: Array = []

@onready var ticket_list: VBoxContainer = %TicketList
@onready var employee_list: VBoxContainer = %EmployeeList
@onready var active_label: Label = %ActiveLabel
@onready var chance_label: Label = %ChanceLabel
@onready var send_button: Button = %SendButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	send_button.pressed.connect(_on_send)
	close_button.pressed.connect(_on_close)
	send_button.text = "Send team"
	close_button.text = "Close"
	Game.state_changed.connect(_refresh)
	_refresh()


func open() -> void:
	# Called by the gameplay scene when the Dispatch button is pressed. Resets
	# the in-progress assignment so re-opening the board does not keep a stale
	# team against a ticket that may have expired.
	active_ticket_id = ""
	assigned_ids.clear()
	_refresh()
	visible = true


func _on_close() -> void:
	visible = false


func _on_send() -> void:
	if active_ticket_id.is_empty() or assigned_ids.is_empty():
		return
	Game.assign_ticket(active_ticket_id, assigned_ids.duplicate())
	# Clear the assignment; the refresh will show the ticket's new state.
	active_ticket_id = ""
	assigned_ids.clear()


func _refresh(_unused: Variant = null) -> void:
	_clear_children(ticket_list)
	_clear_children(employee_list)
	for tk: Ticket in Game.state.tickets:
		var card: PanelContainer = TicketCard.instantiate()
		ticket_list.add_child(card)
		card.setup(tk)
		card.selected.connect(_on_ticket_selected.bind(tk.id))
		if tk.id == active_ticket_id:
			card.modulate = Color(1.2, 1.2, 0.8)
	for e: Employee in Game.state.employees:
		var card: PanelContainer = EmployeeCard.instantiate()
		employee_list.add_child(card)
		card.setup(e)
		card.toggled.connect(_on_employee_toggled.bind(e.id))
		if assigned_ids.has(e.id):
			card.modulate = Color(0.7, 1.0, 0.7)
	_refresh_active_panel()


func _refresh_active_panel() -> void:
	if active_ticket_id.is_empty():
		active_label.text = "(select a ticket)"
		chance_label.text = ""
		send_button.disabled = true
		return
	var ticket: Ticket = _find_ticket(active_ticket_id)
	if ticket == null:
		active_ticket_id = ""
		_refresh_active_panel()
		return
	var team: Array = []
	for id: String in assigned_ids:
		var e: Employee = Game.state.employee_by_id(id)
		if e != null:
			team.append(e)
	var resolve := Resolve.new()
	resolve.apply_balance(ContentLoader.balance())
	var chance: float = resolve.clean_chance(team, ticket.severity)
	active_label.text = "%s · sev %d · team %d" % [ticket.kind, ticket.severity, team.size()]
	chance_label.text = "clean chance: %d%%" % [int(chance * 100)]
	send_button.disabled = team.is_empty() or ticket.state != "open"


func _on_ticket_selected(id: String) -> void:
	# Switching active ticket keeps the assembled team — the player often wants
	# to compare chances across tickets before committing.
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


func _clear_children(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()
