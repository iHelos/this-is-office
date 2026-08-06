extends PanelContainer
## A single employee in the dispatch pool or an assignment slot.
##
## Shows name, role, xp, fatigue, loyalty, and rest status. Emits
## [signal toggled] when clicked so the dispatch screen can add/remove the
## employee to the active ticket's team. Disabled entirely when the employee is
## resting or unemployed.

signal toggled()

var employee: Employee = null


@onready var name_label: Label = %NameLabel
@onready var stat_label: Label = %StatLabel
@onready var rest_label: Label = %RestLabel


func setup(employee_: Employee) -> void:
	employee = employee_


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if employee == null:
		return
	_refresh()


func _on_gui_input(event: InputEvent) -> void:
	if employee == null or not employee.employed or employee.on_rest:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		toggled.emit()


func _refresh() -> void:
	name_label.text = "%s · %s" % [employee.name, employee.role]
	stat_label.text = "xp %d · fat %.0f%% · loy %+.1f" % [employee.xp, employee.fatigue * 100.0, employee.loyalty]
	rest_label.text = "(resting)" if employee.on_rest else ""
	rest_label.visible = employee.on_rest
	# A tired or disloyal employee is still selectable, but dimmed so the player
	# sees the cost before committing them.
	if employee.fatigue > 0.66 or employee.loyalty < -0.3:
		modulate = Color(0.8, 0.8, 0.8)
	else:
		modulate = Color.WHITE
