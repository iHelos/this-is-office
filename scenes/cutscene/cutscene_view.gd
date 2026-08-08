extends Control
## The branching cutscene player. Built in code.
##
## Walks a Cutscene graph node by node. Each frame shows the speaker and line,
## then offers the node's choices as buttons. Picking a choice applies its
## effects through Game.apply_cutscene_choice and either advances to the next
## node or ends the cutscene.

var cutscene: Cutscene = null
var current_node: CutsceneNode = null

var _speaker_label: Label
var _text_label: Label
var _choices_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -360.0
	panel.offset_top = -220.0
	panel.offset_right = 360.0
	panel.offset_bottom = 160.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_speaker_label)
	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 16)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_text_label)
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 8)
	_choices_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_choices_box)
	var skip := Button.new()
	skip.text = L10n.t("cutscene.skip")
	skip.custom_minimum_size = Vector2(0, 36)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(close)
	vbox.add_child(skip)


func play(cutscene_: Cutscene) -> void:
	cutscene = cutscene_
	if cutscene == null:
		close()
		return
	current_node = cutscene.start_node()
	if current_node == null:
		push_error("CutsceneView: cutscene '%s' has no start node '%s'" % [cutscene.id, cutscene.start_node_id])
		close()
		return
	_refresh()
	visible = true


func _refresh() -> void:
	if current_node == null:
		close()
		return
	_speaker_label.text = L10n.t(current_node.speaker_key) if not current_node.speaker_key.is_empty() else ""
	_text_label.text = L10n.t(current_node.text_key)
	for c: Node in _choices_box.get_children():
		_choices_box.remove_child(c)
		c.queue_free()
	if current_node.choices.is_empty():
		var end := Button.new()
		end.text = L10n.t("choice.continue")
		end.custom_minimum_size = Vector2(0, 44)
		end.pressed.connect(close)
		_choices_box.add_child(end)
		return
	for raw: Variant in current_node.choices:
		var choice: Dictionary = raw as Dictionary
		var btn := Button.new()
		btn.text = L10n.t(String(choice.get("label_key", "")))
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(_on_choice.bind(choice))
		_choices_box.add_child(btn)


func _on_choice(choice: Dictionary) -> void:
	var next_id: String = Game.apply_cutscene_choice(cutscene.id, current_node.id, choice)
	if next_id.is_empty():
		close()
		return
	var next_node: CutsceneNode = cutscene.node_by_id(next_id)
	if next_node == null:
		push_error("CutsceneView: choice points at missing node '%s'" % next_id)
		close()
		return
	current_node = next_node
	_refresh()


func close() -> void:
	cutscene = null
	current_node = null
	visible = false
