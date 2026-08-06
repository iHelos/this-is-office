extends RefCounted
## Pins the localization seam.
##
## Every screen renders through [code]L10n.t()[/code]. If the translations ever
## silently drop from the project (a classic Godot CSV race), the UI would show
## raw keys instead of words and nobody would notice until playtest. This suite
## loads both locales through the same path the autoload uses and asserts that a
## representative key resolves in each.

const KEY := "hud.day"


func run(t: TestCase) -> void:
	# Load the generated .translation resources the way autoload/l10n.gd does.
	# If the importer ever changes its output paths, this fails loudly instead of
	# letting the menu ship with blank buttons.
	var ru: Translation = load("res://i18n/translations.ru.translation") as Translation
	var en: Translation = load("res://i18n/translations.en.translation") as Translation
	t.ok(ru != null, "Russian translation resource loads")
	t.ok(en != null, "English translation resource loads")
	if ru == null or en == null:
		return
	t.ne(str(ru.get_message(KEY)), "", "ru: %s resolves to a value" % KEY)
	t.ne(str(en.get_message(KEY)), "", "en: %s resolves to a value" % KEY)
	t.ne(str(ru.get_message(KEY)), str(en.get_message(KEY)), "ru and en differ for the same key")
