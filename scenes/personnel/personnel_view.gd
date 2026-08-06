extends Control
## The personnel / HR screen.
##
## Lists every employee with full stats and two actions: toggle rest (recovers
## fatigue at end of day, at the cost of one fewer staff member that day) and
## fire (permanent, used to satisfy HR quotas or shed a disloyal hire). The
## unemployed stay listed but greyed, so the player sees who they let go. Reads
## through Game and refreshes on Game.state_changed.

var _rows: Dictionary = {}   # employee_id -> HBoxContainer row

@onready var list: VBoxContainer = %List
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.text = "Close"
	close_button.pressed.connect(func() -> void: visible = false)
	Game.state_changed.connect(_refresh)
	_refresh()


func open() -> void:
	_refresh()
	visible = true


func _refresh(_unused: Variant = null) -> void:
	# Rebuild on every state change. The roster is small (a dozen or two) and the
	# screen is modal, so a full rebuild is simpler than tracking row deltas.
	for c: Node in list.get_children():
		list.remove_child(c)
		c.queue_free()
	_rows.clear()
	for e: Employee in Game.state.employees:
		list.add_child(_make_row(e))


func _make_row(e: Employee) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.theme_override_constants_separation = 12
	var name := Label.new()
	name.text = "%s · %s · %s" % [e.name, e.role, e.dept]
	name.custom_minimum_size = Vector2(260, 0)
	name.add_theme_font_size_override("font_size", 14)
	row.add_child(name)
	var stat := Label.new()
	stat.text = "xp %d · fat %.0f%% · loy %+.2f" % [e.xp, e.fatigue * 100.0, e.loyalty]
	stat.custom_minimum_size = Vector2(220, 0)
	row.add_child(stat)
	var traits := Label.new()
	traits.text = ", ".join(Array(e.traits))
	traits.custom_minimum_size = Vector2(120, 0)
	traits.modulate = Color(0.7, 0.7, 0.7)
	row.add_child(traits)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var rest := Button.new()
	rest.text = "resting" if e.on_rest else "rest"
	rest.disabled = not e.employed
	rest.pressed.connect(Game.toggle_rest.bind(e.id))
	row.add_child(rest)
	var fire := Button.new()
	fire.text = "fire"
	fire.disabled = not e.employed
	fire.pressed.connect(_confirm_fire.bind(e.id, e.name))
	row.add_child(fire)
	if not e.employed:
		# Grey out the whole row; the fired employee is history, not staff.
		row.modulate = Color(0.5, 0.5, 0.5)
	_rows[e.id] = row
	return row


func _confirm_fire(employee_id: String, employee_name: String) -> void:
	# No confirmation dialog yet (Phase 3 left one unbuilt); fire is immediate.
	# The greyed-out row after refresh makes the action reversible enough for the
	# MVP, and a confirm dialog lands with the narrative phase.
	Game.fire(employee_id)
