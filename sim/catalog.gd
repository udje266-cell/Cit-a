extends RefCounted
## Chargement et indexation des catalogues JSON de data/.

var config: Dictionary = {}
var stats: Array = []
var species: Dictionary = {}       # id -> dict
var species_order: Array = []
var traits: Dictionary = {}        # id -> dict
var trait_order: Array = []
var trait_categories: Dictionary = {}
var temporary: Dictionary = {}
var techs: Dictionary = {}
var tech_order: Array = []
var eras: Array = []
var powers: Dictionary = {}
var power_order: Array = []
var power_families: Dictionary = {}
var achievements: Array = []
var level_xp: Array = []
var errors: Array = []

static var _shared = null

static func shared():
	if _shared == null:
		_shared = load("res://sim/catalog.gd").new()
		_shared.load_all()
	return _shared

static func read_json(path: String):
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("Catalogue introuvable : " + path)
		return {}
	var data = JSON.parse_string(text)
	if data == null:
		push_error("JSON invalide : " + path)
		return {}
	return data

func load_all() -> void:
	config = read_json("res://data/config.json")
	var sp = read_json("res://data/species.json")
	stats = sp.get("stats", [])
	for s in sp.get("species", []):
		species[s.id] = s
		species_order.append(s.id)
	var tr = read_json("res://data/traits.json")
	trait_categories = tr.get("categories", {})
	temporary = tr.get("temporary", {})
	for t in tr.get("traits", []):
		traits[t.id] = t
		trait_order.append(t.id)
	var te = read_json("res://data/techs.json")
	eras = te.get("eras", [])
	for t in te.get("techs", []):
		techs[t.id] = t
		tech_order.append(t.id)
	var pw = read_json("res://data/powers.json")
	power_families = pw.get("families", {})
	achievements = pw.get("achievements", [])
	level_xp = pw.get("level_xp", [0])
	for p in pw.get("powers", []):
		powers[p.id] = p
		power_order.append(p.id)
	_validate()

## Traduit en place les textes affichés du catalogue (clé = texte français d'origine, conservé dans « <champ>_fr »).
## Un dictionnaire vide rétablit le français. La simulation ne dépend que des identifiants, jamais de ces textes.
func localize(dict: Dictionary) -> void:
	var lists: Array = [species.values(), traits.values(), temporary.values(), techs.values(), powers.values(), achievements]
	for items in lists:
		for it in items:
			for f in ["name", "desc", "interactions"]:
				if it.has(f) or it.has(f + "_fr"):
					if not it.has(f + "_fr"):
						it[f + "_fr"] = it[f]
					it[f] = dict.get(it[f + "_fr"], it[f + "_fr"])
	if not has_meta("labels_fr"):
		set_meta("labels_fr", [power_families.duplicate(), trait_categories.duplicate(), eras.duplicate()])
	var orig: Array = get_meta("labels_fr")
	for k in power_families:
		power_families[k] = dict.get(orig[0][k], orig[0][k])
	for k in trait_categories:
		trait_categories[k] = dict.get(orig[1][k], orig[1][k])
	for i in eras.size():
		eras[i] = dict.get(orig[2][i], orig[2][i])

func _validate() -> void:
	for id in traits:
		for x in traits[id].get("incompat", []):
			if not traits.has(x):
				errors.append("Trait %s : incompatibilité inconnue %s" % [id, x])
	for id in techs:
		for p in techs[id].get("prereq", []):
			if not techs.has(p):
				errors.append("Technique %s : prérequis inconnu %s" % [id, p])
	for e in errors:
		push_error(e)

func cfg(section: String, key: String, default = null):
	return config.get(section, {}).get(key, default)

func heritable_traits() -> Array:
	var out := []
	for id in trait_order:
		if traits[id].kind == "heritable":
			out.append(id)
	return out

func incompatible(a: String, b: String) -> bool:
	return traits.has(a) and b in traits[a].get("incompat", []) or traits.has(b) and a in traits[b].get("incompat", [])
