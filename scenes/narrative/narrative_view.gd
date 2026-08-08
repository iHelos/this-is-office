extends Control
## A visual-novel-style choice prompt. Built in code.
##
## Retained for simple single-shot prompts; the campaign's main decisions now
## flow through cutscene_view. Generic: takes a prompt key and a list of options
## (each id + label key + flag it sets) and emits chosen when the player picks.

signal chosen(option_id: String, flag_key: String, flag_value: String)

var _prompt_key: String = ""
var _options: Array = []

var _prompt_label: Label
var _options_box: VBoxContainer


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
	panel.offset_left = -320.0
	panel.offset_top = -200.0
	panel.offset_right = 320.0
	panel.offset_bottom = 120.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_prompt_label = Label.new()
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_prompt_label)
	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	_options_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_options_box)


func present(prompt_key: String, options: Array) -> void:
	_prompt_key = prompt_key
	_options = options
	_refresh()
	visible = true


func _refresh() -> void:
	_prompt_label.text = L10n.t(_prompt_key) if not _prompt_key.is_empty() else ""
	for c: Node in _options_box.get_children():
		_options_box.remove_child(c)
		c.queue_free()
	for raw: Variant in _options:
		var opt: Dictionary = raw as Dictionary
		var btn := Button.new()
		btn.text = L10n.t(String(opt.get("label_key", "")))
		btn.custom_minimum_size = Vector2(0, 48)
		var id: String = String(opt.get("id", ""))
		var flag_key: String = String(opt.get("flag_key", ""))
		var flag_value: String = String(opt.get("flag_value", ""))
		btn.pressed.connect(_on_option.bind(id, flag_key, flag_value))
		_options_box.add_child(btn)


func _on_option(id: String, flag_key: String, flag_value: String) -> void:
	chosen.emit(id, flag_key, flag_value)
	visible = false
