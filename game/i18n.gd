extends RefCounted
## Langues de l'interface. Le français est la langue source : ses textes servent de clés.
## data/i18n/<langue>.json associe chaque texte français à sa traduction. Au chargement :
## - une Translation Godot est enregistrée : boutons et étiquettes à texte fixe se traduisent seuls,
##   et tr("...") traduit les gabarits avant leur mise en forme (« % ») ;
## - le catalogue (pouvoirs, traits, techniques, espèces, objectifs) est traduit en place.
## Un texte absent du fichier reste en français. Le journal produit par la simulation reste en français.

const LANGS := {"fr": "Français", "en": "English"}
const SETTINGS := "user://settings.cfg"

static var _current: Translation

static func load_dict(locale: String) -> Dictionary:
	if locale == "fr":
		return {}
	var text := FileAccess.get_file_as_string("res://data/i18n/%s.json" % locale)
	var d = JSON.parse_string(text) if text != "" else null
	return d if d is Dictionary else {}

static func apply(locale: String, cat) -> int:
	if not LANGS.has(locale):
		locale = "fr"
	if _current != null:
		TranslationServer.remove_translation(_current)
		_current = null
	var dict := load_dict(locale)
	if not dict.is_empty():
		var t := Translation.new()
		t.locale = locale
		for k in dict:
			t.add_message(k, str(dict[k]))
		TranslationServer.add_translation(t)
		_current = t
	TranslationServer.set_locale(locale)
	if cat != null:
		cat.localize(dict)
	return dict.size()

static func saved_locale() -> String:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		return str(c.get_value("ui", "locale", default_locale()))
	return default_locale()

static func default_locale() -> String:
	var l := OS.get_locale_language()
	return l if LANGS.has(l) else "fr"

static func save_locale(locale: String) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("ui", "locale", locale)
	c.save(SETTINGS)
