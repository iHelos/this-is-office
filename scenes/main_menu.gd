extends Control
## The title screen — UI built entirely in code.
##
## Every visual element here is created in _ready() with Control.new() rather
## than declared in a .tscn. This is deliberate: hand-written .tscn files were
## the source of several silent bugs (scripts not attached to nodes, parent
## attributes missing, anchors not resolving). Building in code means every
## node is provably parented, positioned, and connected before it is shown.

const GAME_SCENE := "res://scenes/game.tscn"

var _new_game_button: Button
var _settings_button: Button
var _language_button: Button
var _quit_button: Button


func _ready() -> void:
	# Full-rect root so children can anchor to it.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.13, 0.18, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Centered vertical stack of title + buttons.
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	var title := Label.new()
	title.text = "This Is the Office"
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_new_game_button = _make_button()
	vbox.add_child(_new_game_button)
	_settings_button = _make_button()
	vbox.add_child(_settings_button)
	_language_button = _make_button()
	_language_button.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(_language_button)
	_quit_button = _make_button()
	vbox.add_child(_quit_button)

	_new_game_button.pressed.connect(_on_new_game)
	_settings_button.pressed.connect(_on_settings)
	_quit_button.pressed.connect(_on_quit)
	_language_button.pressed.connect(_cycle_language)
	L10n.locale_changed.connect(_refresh_labels)
	_refresh_labels()


func _make_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(240, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func _refresh_labels(_locale: String = "") -> void:
	_new_game_button.text = L10n.t("menu.new_game")
	_settings_button.text = L10n.t("menu.settings")
	_quit_button.text = L10n.t("menu.quit")
	_language_button.text = L10n.current_locale().to_upper()


func _on_new_game() -> void:
	# Seed from the wall clock so each campaign starts somewhere new; the
	# deterministic core replays identically from this seed once set.
	var seed_from_clock: int = int(Time.get_unix_time_from_system()) % 1000000
	Game.start_new_game(seed_from_clock)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings() -> void:
	# Settings is a single language toggle for now; a real panel lands alongside
	# the gameplay HUD.
	_cycle_language()


func _cycle_language() -> void:
	var current: String = L10n.current_locale()
	var next: String = "en" if current == "ru" else "ru"
	L10n.set_locale(next)


func _on_quit() -> void:
	get_tree().quit()
