extends Control
## The title screen.
##
## Owns the path into the game: New Game seeds a fresh campaign through the
## Game autoload and changes to the gameplay scene; Settings toggles the
## language so the translation seam is visible immediately; Quit exits.

const GAME_SCENE := "res://scenes/game.tscn"

@onready var new_game_button: Button = %NewGameButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var language_button: Button = %LanguageButton


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	language_button.pressed.connect(_cycle_language)
	L10n.locale_changed.connect(_refresh_labels)
	_refresh_labels()


func _refresh_labels(_locale: String = "") -> void:
	new_game_button.text = L10n.t("menu.new_game")
	settings_button.text = L10n.t("menu.settings")
	quit_button.text = L10n.t("menu.quit")
	language_button.text = L10n.current_locale().to_upper()


func _on_new_game() -> void:
	# Seed from the wall clock so each campaign starts somewhere new; the
	# deterministic core still replays identically from this seed once set.
	var seed_from_clock: int = int(Time.get_unix_time_from_system()) % 1000000
	Game.start_new_game(seed_from_clock)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings() -> void:
	# Settings surface is a single language toggle for now; a real panel lands
	# alongside the gameplay HUD.
	_cycle_language()


func _cycle_language() -> void:
	var current: String = L10n.current_locale()
	var next: String = "en" if current == "ru" else "ru"
	L10n.set_locale(next)


func _on_quit() -> void:
	get_tree().quit()
