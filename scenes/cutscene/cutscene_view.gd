extends Control
## The branching cutscene player.
##
## Walks a [Cutscene] graph node by node. Each frame shows the speaker and line,
## then offers the node's choices as buttons. Picking a choice applies its
## effects through [method Game.apply_cutscene_choice] and either advances to the
## next node or ends the cutscene (when the choice's [code]next[/code] is empty).
## The view is modal: it dims the day scene behind it and holds focus until the
## cutscene ends or the player dismisses it.

var cutscene: Cutscene = null
var current_node: CutsceneNode = null

@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var skip_button: Button = %SkipButton


func _ready() -> void:
	skip_button.text = L10n.t("cutscene.skip")
	skip_button.pressed.connect(close)
	visible = false


## Begin playing [param cutscene_]. Called by the day scene when
## [method Game.pending_cutscene] returns a cutscene.
func play(cutscene_: Cutscene) -> void:
	cutscene = cutscene_
	if cutscene == null:
		close()
		return
	current_node = cutscene.start_node()
	# A cutscene with no reachable start node is malformed content; the test suite
	# catches this, but guard anyway so the UI degrades instead of crashing.
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
	speaker_label.text = L10n.t(current_node.speaker_key) if not current_node.speaker_key.is_empty() else ""
	text_label.text = L10n.t(current_node.text_key)
	for c: Node in choices_box.get_children():
		choices_box.remove_child(c)
		c.queue_free()
	# A node with zero choices is a terminal still frame: show a single "Continue"
	# button that closes the view without applying effects.
	if current_node.choices.is_empty():
		var end := Button.new()
		end.text = L10n.t("choice.continue")
		end.custom_minimum_size = Vector2(0, 44)
		end.pressed.connect(close)
		choices_box.add_child(end)
		return
	for raw: Variant in current_node.choices:
		var choice: Dictionary = raw as Dictionary
		var btn := Button.new()
		btn.text = L10n.t(String(choice.get("label_key", "")))
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(_on_choice.bind(choice))
		choices_box.add_child(btn)


func _on_choice(choice: Dictionary) -> void:
	# apply_cutscene_choice marks the cutscene seen, applies effects, and returns
	# the next node id ("" = end). We navigate or close accordingly.
	var next_id: String = Game.apply_cutscene_choice(cutscene.id, current_node.id, choice)
	if next_id.is_empty():
		close()
		return
	var next_node: CutsceneNode = cutscene.node_by_id(next_id)
	if next_node == null:
		# A dangling next pointer is a content bug; the test suite catches it, but
		# degrade gracefully rather than freezing the screen.
		push_error("CutsceneView: choice points at missing node '%s'" % next_id)
		close()
		return
	current_node = next_node
	_refresh()


func close() -> void:
	cutscene = null
	current_node = null
	visible = false
