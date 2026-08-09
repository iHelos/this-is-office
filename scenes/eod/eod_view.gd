extends Control
## End-of-day ledger — built in code.
##
## Shown after the day rolls over. Reads the just-finished day's events from the
## state log and presents a short summary: budget delta, tickets resolved vs
## fumbled/expired, salaries, and who is tired or was fired. A single button
## closes the screen; the day scene then runs the next morning (and any cutscene
## the chapter system queued).

var _title_label: Label
var _body_label: Label
var _next_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300.0
	panel.offset_top = -260.0
	panel.offset_right = 300.0
	panel.offset_bottom = 200.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_body_label)

	_next_button = Button.new()
	_next_button.text = "To the next day"
	_next_button.custom_minimum_size = Vector2(0, 44)
	_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next_button.pressed.connect(func() -> void: visible = false)
	vbox.add_child(_next_button)


## Build the ledger for the day that just ended.
## [param finished_day] is the day number that was just rolled over FROM.
## [param budget_before] is the budget at the start of that day's end-of-day.
func show_summary(finished_day: int, budget_before: int) -> void:
	var after: int = Game.budget()
	var delta: int = after - budget_before
	var sign: String = "+" if delta >= 0 else ""
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Budget: $%d  (%s$%d)" % [after, sign, delta])
	# Tally ticket outcomes from the log for this day.
	var clean := 0
	var fumbled := 0
	var expired := 0
	var fired := 0
	for entry: Dictionary in Game.state.log:
		if int(entry.get("day", -1)) != finished_day:
			continue
		match String(entry.get("kind", "")):
			"ticket_resolved":
				if bool(entry.get("clean", false)):
					clean += 1
				else:
					fumbled += 1
			"ticket_expired":
				expired += 1
			"employee_fired":
				fired += 1
	lines.append("Tickets: %d clean · %d fumbled · %d expired" % [clean, fumbled, expired])
	lines.append("Salaries paid: -$%d" % Game.daily_salaries())
	if fired > 0:
		lines.append("Let go: %d" % fired)
	# Who is dangerously tired going into the next day.
	var tired_names: Array = []
	for e: Employee in Game.state.employees:
		if e.employed and e.fatigue > 0.6:
			tired_names.append(e.name)
	if not tired_names.is_empty():
		lines.append("Exhausted: %s" % ", ".join(tired_names))
	# Progress to target.
	lines.append("Profit banked: $%d / $%d" % [Game.profit_banked(), Game.target()])
	_title_label.text = "Day %d complete" % finished_day
	_body_label.text = "\n".join(lines)
	visible = true


func next_pressed() -> Signal:
	return _next_button.pressed
