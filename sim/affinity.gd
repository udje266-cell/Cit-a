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
	if n <= 0:
		return result
	var match_cache := {}   # conditions d'une règle : évaluées une fois par établissement et par lot
	# 1) Tirages naissance par naissance : emplacement (compteur mondial) puis dieu ou hasard.
	var natural := {"none": 0, "magic": 0, "sword": 0}
	var divine_by_deity := {}   # id du dieu (-1 : aucun croyant) -> nombre de naissances
	for i in n:
		var counter: int = world.birth_counter
		world.birth_counter += 1
		if is_divine_slot(counter, cfg):
			var deity = _deity_for_birth(world, s)
			var did := -1 if deity == null else int(deity.id)
			divine_by_deity[did] = int(divine_by_deity.get(did, 0)) + 1
		else:
			natural[natural_draw(world.rng, cfg)] += 1
	# 2) Naissances naturelles, regroupées.
	var nat_total: int = natural.none + natural.magic + natural.sword
	world.stats_births.natural_slots += nat_total
	s.births.natural_slots += nat_total
	for a in natural:
		var k: int = natural[a]
		if k == 0:
			continue
		world.stats_births.natural[a] += k
		s.births.natural[a] += k
		s.aff[a] = float(s.aff[a]) + k
		result[a] += k
		if a != NONE:
			_record(world, null, s, "natural", a, "Naissance naturelle (hasard)", k)
			_add_src(s, a, "natural", k)
	# 3) Naissances ouvertes au divin : décision du dieu, une par une seulement s'il a des règles ou des ordres.
	for did in divine_by_deity:
		var k: int = divine_by_deity[did]
		world.stats_births.divine_slots += k
		s.births.divine_slots += k
		var deity = null if did < 0 else world.deities[did]
		if deity == null or (deity.rules.is_empty() and deity.manual_orders.is_empty()):
			world.stats_births.divine_none += k
			s.births.divine_none += k
			s.aff[NONE] = float(s.aff[NONE]) + k
			result[NONE] += k
			continue
		var left := k
		# Ordres manuels d'abord, puis règles par priorité : chacune prend des naissances jusqu'à
		# épuisement de son plafond, du budget ou de l'énergie (équivalent au traitement une par une).
		for o in deity.manual_orders:
			if left == 0:
				break
			if int(o.settlement) != int(s.id) or int(o.remaining) <= 0:
				continue
			var c := cost_of(world, o.affinity, false)
			var take := mini(left, mini(int(o.remaining), int(floor(float(deity.energy) / c + 0.000001))))
			if take <= 0:
				continue
			deity.energy -= c * take
			o.remaining = int(o.remaining) - take
			deity.affinities_granted += take
			_record(world, deity, s, "manual", o.affinity, "Ordre manuel du dieu", take)
			_grant_births(world, s, o.affinity, "manual", take, result)
			left -= take
		_cleanup_orders(deity)
		if left > 0:
			for r in _sorted_rules(world, deity):
				if left == 0:
					break
				if not r.enabled or int(r.used_this_year) >= int(r.max_per_year):
					continue
				var mkey := "%d_%d" % [int(deity.id), int(r.id)]
				if not match_cache.has(mkey):
					match_cache[mkey] = match_rule(world, deity, s, r)
				var reason: String = match_cache[mkey]
				if reason == "":
					continue
				var c2 := cost_of(world, r.result, false)
				var by_budget := int(floor((float(deity.auto_budget) - float(deity.auto_spent)) / c2 + 0.000001))
				var by_energy := int(floor(float(deity.energy) / c2 + 0.000001))
				var take2 := mini(left, mini(int(r.max_per_year) - int(r.used_this_year), mini(by_budget, by_energy)))
				if take2 <= 0:
					r.blocked_budget = int(r.get("blocked_budget", 0)) + left
					continue
				deity.energy -= c2 * take2
				deity.auto_spent += c2 * take2
				r.used_this_year = int(r.used_this_year) + take2
				r.total = int(r.total) + take2
				deity.affinities_granted += take2
				_record(world, deity, s, "rule:" + str(r.name), r.result, reason, take2)
				_grant_births(world, s, r.result, "rule:" + str(r.name), take2, result)
				left -= take2
				if left > 0 and (by_budget == take2 or by_energy == take2):
					r.blocked_budget = int(r.get("blocked_budget", 0)) + left
		if left > 0:
			world.stats_births.divine_none += left
			s.births.divine_none += left
			s.aff[NONE] = float(s.aff[NONE]) + left
			result[NONE] += left
	return result

static func _grant_births(world, s: Dictionary, a: String, src: String, k: int, result: Dictionary) -> void:
	world.stats_births.divine[a] += k
	s.births.divine[a] += k
	s.aff[a] = float(s.aff[a]) + k
	result[a] += k
	_add_src(s, a, src, k)

static func _sorted_rules(world, deity) -> Array:
	var rkey := "rules%d" % int(deity.id)
	if world.tick_cache.has(rkey):
		return world.tick_cache[rkey]
	var rules: Array = deity.rules.duplicate()
	rules.sort_custom(func(x, y): return int(x.priority) < int(y.priority))
	world.tick_cache[rkey] = rules
	return rules

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
