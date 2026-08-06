extends Control
## A visual-novel-style choice prompt.
##
## Used for the load-bearing decisions the campaign hinges on — chiefly the day
## 12 faction choice (the Sand/Varga analogue). The screen is generic: it takes
## a prompt key and a list of options (each an id + label key + a flag it sets)
## and emits [signal chosen when the player picks. The gameplay scene listens
## and routes the result back into Game state.

signal chosen(option_id: String, flag_key: String, flag_value: String)

var _prompt_key: String = ""
var _options: Array = []   # Array[Dictionary] with id, label_key, flag_key, flag_value

@onready var prompt_label: Label = %PromptLabel
@onready var options_box: VBoxContainer = %OptionsBox


func present(prompt_key: String, options: Array) -> void:
	_prompt_key = prompt_key
	_options = options
	_refresh()
	visible = true


func _refresh() -> void:
	prompt_label.text = L10n.t(_prompt_key) if not _prompt_key.is_empty() else ""
	for c: Node in options_box.get_children():
		options_box.remove_child(c)
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
		options_box.add_child(btn)


func _on_option(id: String, flag_key: String, flag_value: String) -> void:
	chosen.emit(id, flag_key, flag_value)
	visible = false
