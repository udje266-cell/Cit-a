extends RefCounted
## Affinités Magie / Épée — règle centrale du jeu (voir docs/RULES.md §1).
##
## Invariants garantis par ce module (et vérifiés par tests/run_tests.gd) :
##  1. Sur chaque cycle de naissances, `divine_slots_per_cycle` naissances sont ouvertes à l'attribution divine
##     et `natural_slots_per_cycle` sont naturelles (par défaut 2 sur 3 et 1 sur 3), grâce à un compteur global.
##  2. Une naissance divine sans attribution donne 'none'. Aucun tirage naturel de remplacement.
##  3. Une naissance naturelle tire parmi none / magic / sword uniquement : jamais 'both'.
##  4. L'hérédité, les mutations et le milieu n'interviennent pas ici : les affinités des parents sont ignorées.
##  5. Après la naissance, seule une intervention divine (grant_late) peut ajouter une affinité.
##  6. Le résultat des naissances fait partie de l'état sauvegardé, avec l'état du générateur aléatoire :
##     recharger une partie ne retire jamais une naissance déjà résolue.

const NONE := "none"
const MAGIC := "magic"
const SWORD := "sword"
const BOTH := "both"
const ALL := [NONE, MAGIC, SWORD, BOTH]
const NAMES := {"none": "Sans affinité", "magic": "Magie", "sword": "Épée", "both": "Magie et Épée"}

const CONDITION_FIELDS := {
	"always": "Toujours",
	"own_people": "Peuple d'origine du dieu",
	"species": "Espèce",
	"biome": "Région (biome)",
	"lineage_share": "Part de la lignée portant une affinité",
	"trait_freq": "Fréquence d'un trait",
	"need": "Besoin du peuple",
	"population": "Population de l'établissement",
}
const NEEDS := {"defense": "Menace ou guerre", "magic_research": "Recherche magique en cours", "food": "Famine", "faith": "Ferveur faible"}

static func empty_counts() -> Dictionary:
	return {"none": 0.0, "magic": 0.0, "sword": 0.0, "both": 0.0}

## Origine des porteurs d'affinité (comptes agrégés par établissement) :
## {"magic": {"natural": n, "rule:Nom": n, "manual": n, "late": n, "creation": n}, "sword": {...}, "both": {...}}
static func empty_sources() -> Dictionary:
	return {"magic": {}, "sword": {}, "both": {}}

static var _last_src := ""

static func _add_src(s: Dictionary, affinity: String, src: String, amount: float) -> void:
	if affinity == NONE:
		return
	if not s.has("aff_src"):
		s["aff_src"] = empty_sources()
	var d: Dictionary = s.aff_src[affinity]
	d[src] = float(d.get(src, 0.0)) + amount

static func empty_stats() -> Dictionary:
	return {"divine_slots": 0, "divine_none": 0, "divine": {"magic": 0, "sword": 0, "both": 0},
		"natural_slots": 0, "natural": {"none": 0, "magic": 0, "sword": 0}, "late": {"magic": 0, "sword": 0, "both": 0}}

static func is_divine_slot(counter: int, cfg: Dictionary) -> bool:
	var d := int(cfg.get("divine_slots_per_cycle", 2))
	var n := int(cfg.get("natural_slots_per_cycle", 1))
	return counter % (d + n) < d

## Tirage naturel : uniquement none / magic / sword (toute autre clé de configuration est ignorée).
static func natural_draw(rng: RandomNumberGenerator, cfg: Dictionary) -> String:
	var p: Dictionary = cfg.get("natural_probabilities", {})
	var pn := maxf(float(p.get("none", 0.8)), 0.0)
	var pm := maxf(float(p.get("magic", 0.12)), 0.0)
	var ps := maxf(float(p.get("sword", 0.08)), 0.0)
	var total := pn + pm + ps
	if total <= 0.0:
		return NONE
	var r := rng.randf() * total
	if r < pm:
		return MAGIC
	if r < pm + ps:
		return SWORD
	return NONE

## Résout `n` naissances d'un établissement. Modifie s.aff, les statistiques, l'énergie et l'historique des dieux.
static func resolve_births(world, s: Dictionary, n: int) -> Dictionary:
	var cfg: Dictionary = world.cat.config.get("affinity", {})
	var result := empty_counts()
	for i in n:
		var counter: int = world.birth_counter
		world.birth_counter += 1
		var a := NONE
		if is_divine_slot(counter, cfg):
			world.stats_births.divine_slots += 1
			s.births.divine_slots += 1
			_last_src = ""
			a = _divine_birth(world, s, cfg)
			_add_src(s, a, _last_src, 1.0)
			if a == NONE:
				world.stats_births.divine_none += 1
				s.births.divine_none += 1
			else:
				world.stats_births.divine[a] += 1
				s.births.divine[a] += 1
		else:
			world.stats_births.natural_slots += 1
			s.births.natural_slots += 1
			a = natural_draw(world.rng, cfg)
			world.stats_births.natural[a] += 1
			s.births.natural[a] += 1
			if a != NONE:
				_record(world, null, s, "natural", a, "Naissance naturelle (hasard)")
				_add_src(s, a, "natural", 1.0)
		s.aff[a] = float(s.aff[a]) + 1.0
		result[a] += 1.0
	return result

## Naissance ouverte à l'attribution : le dieu de la famille (tiré selon les parts religieuses) décide.
## Pas de croyant → pas de dieu pour décider → 'none'.
static func _divine_birth(world, s: Dictionary, cfg: Dictionary) -> String:
	var deity = _deity_for_birth(world, s)
	if deity == null:
		return NONE
	# 1) Ordres manuels du dieu (prioritaires).
	for o in deity.manual_orders:
		if int(o.settlement) == int(s.id) and int(o.remaining) > 0:
			var c := cost_of(world, o.affinity, false)
			if deity.energy >= c:
				deity.energy -= c
				o.remaining = int(o.remaining) - 1
				deity.affinities_granted += 1
				_record(world, deity, s, "manual", o.affinity, "Ordre manuel du dieu")
				_cleanup_orders(deity)
				_last_src = "manual"
				return o.affinity
	# 2) Règles automatiques par priorité croissante.
	var rules: Array = deity.rules.duplicate()
	rules.sort_custom(func(a, b): return int(a.priority) < int(b.priority))
	for r in rules:
		if not r.enabled:
			continue
		if int(r.used_this_year) >= int(r.max_per_year):
			continue
		var reason := match_rule(world, deity, s, r)
		if reason == "":
			continue
		var c2 := cost_of(world, r.result, false)
		if deity.auto_spent + c2 > float(deity.auto_budget) or deity.energy < c2:
			r.blocked_budget = int(r.get("blocked_budget", 0)) + 1
			continue
		deity.energy -= c2
		deity.auto_spent += c2
		r.used_this_year = int(r.used_this_year) + 1
		r.total = int(r.total) + 1
		deity.affinities_granted += 1
		_record(world, deity, s, "rule:" + str(r.name), r.result, reason)
		_last_src = "rule:" + str(r.name)
		return r.result
	return NONE

static func _deity_for_birth(world, s: Dictionary):
	var r: float = world.rng.randf()
	for rid in s.faith:
		r -= float(s.faith[rid])
		if r <= 0.0:
			var rel = world.religions[int(rid)]
			return world.deities[int(rel.deity)]
	return null

static func cost_of(world, affinity: String, late: bool) -> float:
	var cfg: Dictionary = world.cat.config.get("affinity", {})
	var c := float(cfg.get("cost", {}).get(affinity, 1.0))
	if late:
		c *= float(cfg.get("late_grant_cost_multiplier", 2.0))
	return c

## Renvoie une explication lisible si la règle s'applique, sinon "".
static func match_rule(world, deity, s: Dictionary, rule: Dictionary) -> String:
	var parts := []
	for cond in rule.conditions:
		var ok := false
		var txt := ""
		match str(cond.field):
			"always":
				ok = true
				txt = "toujours"
			"own_people":
				ok = int(world.peoples[int(s.people)].deity) == int(deity.id)
				txt = "peuple d'origine"
			"species":
				ok = world.peoples[int(s.people)].species == str(cond.value)
				txt = "espèce " + str(cond.value)
			"biome":
				ok = world.planet.biome_name(int(s.cell)) == str(cond.value)
				txt = "région " + str(cond.value)
			"lineage_share":
				var share := lineage_share(s, str(cond.key))
				ok = _compare(share, str(cond.op), float(cond.value))
				txt = "lignée %s %.0f %% %s %.0f %%" % [NAMES.get(str(cond.key), str(cond.key)), share * 100.0, cond.op, float(cond.value) * 100.0]
			"trait_freq":
				var f := float(s.freqs.get(str(cond.key), 0.0))
				ok = _compare(f, str(cond.op), float(cond.value))
				txt = "trait %s à %.0f %%" % [str(cond.key), f * 100.0]
			"need":
				ok = has_need(world, s, str(cond.value))
				txt = "besoin : " + NEEDS.get(str(cond.value), str(cond.value))
			"population":
				ok = _compare(float(s.pop), str(cond.op), float(cond.value))
				txt = "population %d" % int(s.pop)
		if not ok:
			return ""
		parts.append(txt)
	if parts.is_empty():
		return ""
	return "Règle « %s » : %s" % [rule.name, ", ".join(parts)]

static func _compare(a: float, op: String, b: float) -> bool:
	match op:
		">=": return a >= b
		"<=": return a <= b
		">": return a > b
		"<": return a < b
	return false

static func lineage_share(s: Dictionary, key: String) -> float:
	var total := float(s.aff.none) + float(s.aff.magic) + float(s.aff.sword) + float(s.aff.both)
	if total <= 0.0:
		return 0.0
	match key:
		"magic": return (float(s.aff.magic) + float(s.aff.both)) / total
		"sword": return (float(s.aff.sword) + float(s.aff.both)) / total
		"both": return float(s.aff.both) / total
		"none": return float(s.aff.none) / total
	return 0.0

static func has_need(world, s: Dictionary, need: String) -> bool:
	match need:
		"defense":
			return world.people_at_war(int(s.people))
		"magic_research":
			var cur = world.peoples[int(s.people)].research.current
			return cur != "" and world.cat.techs.has(cur) and world.cat.techs[cur].path in ["magic", "hybrid"]
		"food":
			return s.statuses.has("famine")
		"faith":
			return float(s.fervor) < 0.3
	return false

## Intervention divine tardive : confère une affinité à `count` habitants nés sans elle.
## 'magic'/'sword' : pris parmi les 'none'. 'both' : pris parmi les 'magic' et 'sword' d'abord (complément), puis 'none'.
## Retourne le nombre réellement converti (limité par l'énergie et les habitants disponibles).
static func grant_late(world, deity, s: Dictionary, affinity: String, count: int) -> int:
	if not affinity in [MAGIC, SWORD, BOTH]:
		return 0
	var cost := cost_of(world, affinity, true)
	var done := 0
	for i in count:
		if deity.energy < cost:
			break
		var src := ""
		if affinity == BOTH:
			for k in [MAGIC, SWORD, NONE]:
				if float(s.aff[k]) >= 1.0:
					src = k
					break
		elif float(s.aff[NONE]) >= 1.0:
			src = NONE
		if src == "":
			break
		s.aff[src] = float(s.aff[src]) - 1.0
		s.aff[affinity] = float(s.aff[affinity]) + 1.0
		_add_src(s, affinity, "late", 1.0)
		if src != NONE and s.has("aff_src"):
			_scale_src(s, src, (float(s.aff[src])) / maxf(float(s.aff[src]) + 1.0, 1.0))
		deity.energy -= cost
		done += 1
	if done > 0:
		deity.affinities_granted += done
		world.stats_births.late[affinity] += done
		_record(world, deity, s, "late", affinity, "Intervention divine tardive (%d personnes)" % done, done)
	return done

## Les morts retirent proportionnellement dans chaque catégorie.
static func apply_deaths(s: Dictionary, deaths: float) -> void:
	var total := float(s.aff.none) + float(s.aff.magic) + float(s.aff.sword) + float(s.aff.both)
	if total <= 0.0:
		return
	var k := clampf(1.0 - deaths / total, 0.0, 1.0)
	for a in ALL:
		s.aff[a] = float(s.aff[a]) * k
		if a != NONE:
			_scale_src(s, a, k)

static func _scale_src(s: Dictionary, affinity: String, k: float) -> void:
	if not s.has("aff_src"):
		return
	var d: Dictionary = s.aff_src[affinity]
	for src in d.keys():
		d[src] = float(d[src]) * k

## Une partie de la population part fonder un nouvel établissement : les porteurs partent au prorata.
static func split_counts(s: Dictionary, fraction: float) -> Dictionary:
	var out := empty_counts()
	for a in ALL:
		out[a] = float(s.aff[a]) * fraction
		s.aff[a] = float(s.aff[a]) - out[a]
	return out

## Origines emportées par les colons (même fraction).
static func split_sources(s: Dictionary, fraction: float) -> Dictionary:
	var out := empty_sources()
	if not s.has("aff_src"):
		return out
	for a in out:
		for src in s.aff_src[a]:
			var v := float(s.aff_src[a][src]) * fraction
			out[a][src] = v
			s.aff_src[a][src] = float(s.aff_src[a][src]) - v
	return out

## Libellé lisible d'une origine.
static func source_label(src: String) -> String:
	if src == "natural":
		return "naturelle (hasard de la naissance)"
	if src == "manual":
		return "divine — ordre manuel du dieu"
	if src == "late":
		return "divine — don tardif (Don d'affinité)"
	if src == "creation":
		return "divine — don à la création des fondateurs"
	if src.begins_with("rule:"):
		return "divine — règle « %s »" % src.substr(5)
	return "inconnue"

## Historique agrégé (une ligne par année / établissement / source / résultat) pour rester compact.
static func _record(world, deity, s: Dictionary, source: String, affinity: String, reason: String, count: int = 1) -> void:
	var hist: Array = world.affinity_history
	if not hist.is_empty():
		var last: Dictionary = hist[hist.size() - 1]
		if int(last.year) == world.year and int(last.settlement) == int(s.id) and last.source == source and last.result == affinity:
			last.count = int(last.count) + count
			return
	hist.append({"year": world.year, "deity": -1 if deity == null else int(deity.id), "settlement": int(s.id),
		"source": source, "result": affinity, "count": count, "reason": reason})
	var cap := int(world.cat.cfg("affinity", "history_max_entries", 200))
	while hist.size() > cap:
		hist.pop_front()

static func _cleanup_orders(deity) -> void:
	var keep := []
	for o in deity.manual_orders:
		if int(o.remaining) > 0:
			keep.append(o)
	deity.manual_orders = keep

static func new_rule(id: int, name: String, result: String, conditions: Array, priority: int = 10, max_per_year: int = 5) -> Dictionary:
	return {"id": id, "name": name, "enabled": true, "priority": priority, "conditions": conditions,
		"result": result, "max_per_year": max_per_year, "used_this_year": 0, "total": 0, "blocked_budget": 0}

## Règles automatiques des dieux rivaux, déduites de leur personnalité.
static func rival_rules(personality: Dictionary) -> Array:
	var rules := []
	var mb := float(personality.magic_bias)
	var aggr := float(personality.aggression)
	if aggr > 0.5:
		rules.append(new_rule(0, "Lames en temps de guerre", SWORD, [{"field": "need", "value": "defense"}], 1, 6))
	if mb > 0.2:
		rules.append(new_rule(1, "Mages pour la recherche", MAGIC, [{"field": "need", "value": "magic_research"}], 2, 4))
	rules.append(new_rule(2, "Élus du peuple", BOTH, [{"field": "own_people"}, {"field": "lineage_share", "key": "both", "op": "<", "value": 0.02}], 3, 1))
	rules.append(new_rule(3, "Dons ordinaires", MAGIC if mb >= 0.0 else SWORD, [{"field": "own_people"}], 5, 2))
	return rules
