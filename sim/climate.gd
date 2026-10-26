extends RefCounted
## Années climatiques : épisodes de quelques années qui modulent les récoltes selon la région.
## Sécheresse : régions chaudes et sèches ; hiver rude : régions froides ; années fastes : partout.
## Le statut « saison douce » (pouvoir divin) protège un établissement des mauvaises années.

const KINDS := {
	"secheresse": {"name": "Sécheresse", "factor": 0.7, "why": "Pluies insuffisantes dans les régions chaudes et sèches"},
	"hiver_rude": {"name": "Hivers rudes", "factor": 0.7, "why": "Gel prolongé dans les régions froides"},
	"annee_faste": {"name": "Années fastes", "factor": 1.2, "why": "Saisons régulières et douces"},
}
const START_CHANCE := 0.07

static func none() -> Dictionary:
	return {"kind": "", "until": -1}

static func tick(w) -> void:
	var c: Dictionary = w.climate
	if c.kind != "" and w.year > int(c.until):
		w.add_log("Fin : %s" % KINDS[c.kind].name, "Retour à un climat ordinaire", "climate", -1)
		c.kind = ""
	if c.kind == "" and w.rng.randf() < START_CHANCE:
		var keys: Array = KINDS.keys()
		c.kind = keys[w.rng.randi_range(0, keys.size() - 1)]
		c.until = w.year + w.rng.randi_range(2, 5)
		c.since = w.year
		w.add_log("%s (jusqu'en l'an %d)" % [KINDS[c.kind].name, int(c.until)], KINDS[c.kind].why, "climate", -1)

## Région touchée par l'épisode en cours ?
static func affects(w, cell: int) -> bool:
	var k: String = w.climate.kind
	if k == "":
		return false
	var t: float = w.planet.temperature[cell]
	match k:
		"secheresse":
			return t > 0.55 and w.planet.moisture[cell] < 0.55
		"hiver_rude":
			return t < 0.45
	return true

## Multiplicateur des récoltes d'un établissement.
static func food_factor(w, s: Dictionary) -> float:
	if not affects(w, int(s.cell)):
		return 1.0
	var f: float = KINDS[w.climate.kind].factor
	if f < 1.0 and s.statuses.has("saison_douce"):
		return 1.0
	return f

static func label(w) -> String:
	if w.climate.kind == "":
		return "Climat ordinaire"
	return "%s jusqu'en l'an %d" % [KINDS[w.climate.kind].name, int(w.climate.until)]
