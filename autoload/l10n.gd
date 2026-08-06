extends Node
## Thin wrapper around Godot's TranslationServer.
##
## Two responsibilities: keep the current locale in one place so every screen
## can react to a language switch, and expose [method t] as the single spelling
## of "translate this key". Screens call [code]L10n.t("hud.day")[/code] instead
## of [method @GlobalScope.tr]; if the translation seam ever needs to grow a
## fallback or a plural form, it grows in exactly one file.
##
## Translations are registered in code from [code]i18n/translations.csv[/code]
## rather than via [code]project.godot[/code]. Registering the .csv path in the
## project file races the csv_translation importer under [code]--headless[/code]
## and leaves the locale blank on a clean checkout; loading it here, after the
## SceneTree is up, is reliable across editor, exports, and the test runner.

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "ru"


func _ready() -> void:
	_register_translations()
	apply_locale(DEFAULT_LOCALE)


# The csv_translation importer emits one .translation per language column next
# to the source. We register those generated resources explicitly instead of the
# .csv: under --headless on a clean checkout, registering the .csv path in
# project.godot races the importer and leaves the locale blank. These two paths
# are stable as long as the CSV keeps exactly the `ru` and `en` columns.
# PackedStringArray([...]) is not a constant expression in GDScript, so the list
# is built here rather than as a const.
func _translation_paths() -> PackedStringArray:
	return PackedStringArray([
		"res://i18n/translations.ru.translation",
		"res://i18n/translations.en.translation",
	])


func _register_translations() -> void:
	for path: String in _translation_paths():
		var loaded: Translation = load(path) as Translation
		if loaded != null:
			TranslationServer.add_translation(loaded)


# PackedStringArray([...]) is not a constant expression in GDScript, so the
# supported set lives in a regular method rather than a const. Two entries is
# all this project ships; adding a language means editing exactly here.
func _supported() -> PackedStringArray:
	return PackedStringArray(["ru", "en"])


## Returns the translation for [param key], or the key itself when nothing is
## registered. Returning the key makes missing translations loud but safe.
func t(key: String) -> String:
	var resolved: String = tr(key)
	return key if resolved.is_empty() else resolved


func current_locale() -> String:
	return TranslationServer.get_locale()


func set_locale(locale: String) -> void:
	if locale == current_locale():
		return
	apply_locale(locale)
	locale_changed.emit(locale)


func apply_locale(locale: String) -> void:
	# TranslationServer rejects unknown locales silently; coerce to the default
	# so a corrupt save never produces a blank UI.
	var resolved: String = locale if _supported().has(locale) else DEFAULT_LOCALE
	TranslationServer.set_locale(resolved)
