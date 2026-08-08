extends Control
## The personnel / HR screen — built in code.
##
## Lists every employee with full stats and two actions: toggle rest (recovers
## fatigue at end of day, at the cost of one fewer staff member that day) and
## fire (permanent, used to satisfy HR quotas or shed a disloyal hire). The
## unemployed stay listed but greyed. Reads through Game and refreshes on
## Game.state_changed.

var _list: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	add_child(_make_dim())
	var panel: Control = _make_panel()

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Personnel"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func() -> void: visible = false)
	vbox.add_child(close_btn)

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
	if not visible:
		return
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for e: Employee in Game.state.employees:
		_list.add_child(_make_row(e))


func _make_row(e: Employee) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name := Label.new()
	name.text = "%s · %s · %s" % [e.name, e.role, e.dept]
	name.custom_minimum_size = Vector2(260, 0)
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
	fire.pressed.connect(Game.fire.bind(e.id))
	row.add_child(fire)
	if not e.employed:
		row.modulate = Color(0.5, 0.5, 0.5)
	return row
