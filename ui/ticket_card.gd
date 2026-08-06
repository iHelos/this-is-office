extends PanelContainer
## A single ticket on the dispatch board.
##
## Shows the ticket's kind, source, severity, reward/penalty, and current state.
## Emits [signal selected] when clicked so the dispatch screen can mark it as
## the active assignment target. State colouring makes a resolved ticket read at
## a glance: open is neutral, clean is green, fumbled/expired is red.

signal selected()

var ticket: Ticket = null

@onready var kind_label: Label = %KindLabel
@onready var detail_label: Label = %DetailLabel
@onready var state_label: Label = %StateLabel


func setup(ticket_: Ticket) -> void:
	# Built before the node is in the tree, so stash and apply in _ready.
	ticket = ticket_


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if ticket == null:
		return
	_refresh()


func _on_gui_input(event: InputEvent) -> void:
	# Only open tickets are selectable; resolved ones are read-only history.
	if ticket == null or ticket.state != "open":
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		selected.emit()


func _refresh() -> void:
	kind_label.text = "%s · %s" % [ticket.kind, ticket.source_dept]
	detail_label.text = "sev %d · +$%d / -$%d · ttl %d" % [ticket.severity, ticket.reward, ticket.penalty, ticket.ttl]
	state_label.text = ticket.state
	# Tint by outcome so the board reads without reading labels.
	var tint := Color.WHITE
	match ticket.state:
		"clean": tint = Color(0.3, 0.6, 0.35)
		"fumbled", "expired": tint = Color(0.7, 0.3, 0.3)
		"open": tint = Color(0.85, 0.82, 0.6)
		_: tint = Color.WHITE
	state_label.modulate = tint
