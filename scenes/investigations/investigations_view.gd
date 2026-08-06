extends Control
## The incident board — the investigations screen.
##
## Lists open incidents. Selecting one shows its clue progress and a pool of
## troubleshooters (role 'troubleshooter'); assigning them gathers clues over
## time (one action = one clue-gathering pass). Once clues_found reaches the
## total, the incident enters 'deducing' and the closing choices (drop /
## confront / sell) become available — each trades budget, faction standing,
## and faction power differently.

const EmployeeCard := preload("res://ui/employee_card.tscn")

var active_incident_id: String = ""
var assigned_ids: Array = []

@onready var incident_list: VBoxContainer = %IncidentList
@onready var detail_label: Label = %DetailLabel
@onready var progress_label: Label = %ProgressLabel
@onready var gather_button: Button = %GatherButton
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var troubleshooter_list: VBoxContainer = %TroubleshooterList
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	gather_button.text = "Gather clues"
	close_button.text = "Close"
	gather_button.pressed.connect(_on_gather)
	close_button.pressed.connect(func() -> void: visible = false)
	Game.state_changed.connect(_refresh)
	_refresh()


func open() -> void:
	active_incident_id = ""
	assigned_ids.clear()
	_refresh()
	visible = true


func _refresh(_unused: Variant = null) -> void:
	_clear_children(incident_list)
	_clear_children(troubleshooter_list)
	_clear_children(choices_box)
	# Incident cards.
	for inc: Incident in Game.state.incidents:
		var btn := Button.new()
		btn.text = "%s [%s] — %d/%d" % [L10n.t(inc.title), inc.state, inc.clues_found, inc.clues_total]
		btn.disabled = inc.state == "closed"
		btn.pressed.connect(_on_incident_selected.bind(inc.id))
		if inc.id == active_incident_id:
			btn.modulate = Color(1.2, 1.2, 0.8)
		incident_list.add_child(btn)
	# Troubleshooter pool — only the troubleshooter role works incidents.
	for e: Employee in Game.state.employees:
		if e.role != "troubleshooter" or not e.employed:
			continue
		var card: PanelContainer = EmployeeCard.instantiate()
		troubleshooter_list.add_child(card)
		card.setup(e)
		card.toggled.connect(_on_troubleshooter_toggled.bind(e.id))
		if assigned_ids.has(e.id):
			card.modulate = Color(0.7, 1.0, 0.7)
	_refresh_detail()


func _refresh_detail() -> void:
	if active_incident_id.is_empty():
		detail_label.text = "(select an incident)"
		progress_label.text = ""
		gather_button.disabled = true
		return
	var inc: Incident = _find_incident(active_incident_id)
	if inc == null:
		active_incident_id = ""
		_refresh_detail()
		return
	detail_label.text = "%s · %s · sev %d" % [L10n.t(inc.title), inc.kind, inc.severity]
	progress_label.text = "clues %d / %d" % [inc.clues_found, inc.clues_total]
	gather_button.disabled = inc.state != "open" or assigned_ids.is_empty()
	# Closing choices appear only once the incident is fully deduced.
	if inc.state == "deducing":
		var prompt := Label.new()
		prompt.text = "Choose how to close:"
		choices_box.add_child(prompt)
		for raw: Variant in inc.choices:
			var choice: Dictionary = raw as Dictionary
			var btn := Button.new()
			btn.text = "%s  (+$%d, standing %+.1f, power %+d)" % [
				String(choice.get("id", "")),
				int(choice.get("budget_delta", 0)),
				float(choice.get("standing_delta", 0.0)),
				int(choice.get("faction_power_delta", 0)),
			]
			btn.pressed.connect(Game.close_incident.bind(inc.id, String(choice.get("id", ""))))
			choices_box.add_child(btn)


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
	# Keep the assignment for repeated gathering until the player switches
	# incidents; the refresh reflects the new clue count.


func _find_incident(id: String) -> Incident:
	for inc: Incident in Game.state.incidents:
		if inc.id == id:
			return inc
	return null


func _clear_children(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()
