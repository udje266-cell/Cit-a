extends RefCounted
## Civilisations autonomes : nourriture, croissance bornée par le milieu, naissances (via affinity.gd),
## territoires, expansion, génétique par génération, recherche, crises, relations et guerres, scissions.

const Climate = preload("res://sim/climate.gd")
const Genetics = preload("res://sim/genetics.gd")
const Affinity = preload("res://sim/affinity.gd")
const Planet = preload("res://sim/planet.gd")

## L'année est orchestrée par World.tick_step (phases étalées sur plusieurs images).

# ------------------------------------------------------------------ Établissement

## Espèce d'un établissement (un royaume peut réunir plusieurs espèces après fusion ou conquête).
static func species_of(w, s: Dictionary) -> String:
	return str(s.get("species", w.peoples[int(s.people)].species))

static func stats_of(w, s: Dictionary) -> Dictionary:
	var key := "st%d" % int(s.id)
	if w.tick_cache.has(key):
		return w.tick_cache[key]
	var p: Dictionary = w.peoples[int(s.people)]
	var st := Genetics.effective_stats(w.cat, species_of(w, s), s.freqs, p.culture, s.statuses)
	w.tick_cache[key] = st
	return st

static func cell_food(w, cell: int, species_id: String, st: Dictionary, fx: Dictionary) -> float:
	var pl = w.planet
	if not pl.is_land(cell):
		return 0.0
	var b: String = pl.biome_name(cell)
	var hab := float(w.cat.species[species_id].habitat.get(b, 0.0))
	var t: float = pl.temperature[cell]
	hab += 0.5 * (float(st.cold) - 0.5) * maxf(0.0, 0.45 - t) * 2.0
	hab += 0.5 * (float(st.heat) - 0.5) * maxf(0.0, t - 0.7) * 2.5
	if b in ["taiga", "temperate_forest", "rainforest"]:
		hab += 0.3 * (float(st.forest) - 0.5)
	elif b in ["mountain", "snow_peak"]:
		hab += 0.4 * (float(st.mount) - 0.5)
	elif b == "desert":
		hab += 0.4 * (float(st.desert) - 0.5)
	hab = clampf(hab + float(fx.get("cold_shelter", 0.0)) * maxf(0.0, 0.4 - t), 0.0, 1.3)
	var food: float = pl.fertility[cell] * hab
	if pl.has_res(cell, "game"):
		food += 0.15 * hab
	if pl.has_res(cell, "fish"):
		food += 0.3 * (0.4 + float(st.aqua)) * (1.0 + float(fx.get("fish_mult", 0.0)))
	return food

static func capacity(w, s: Dictionary, st: Dictionary, fx: Dictionary) -> float:
	var sp: String = species_of(w, s)
	var total := 0.0
	for c in s.territory:
		total += cell_food(w, int(c), sp, st, fx)
	var k := total * 40.0 * (1.0 + float(fx.get("capacity_mult", 0.0)) + float(fx.get("food_mult", 0.0))) * (0.6 + float(st.food) * 0.8)
	if s.statuses.has("maudit"):
		k *= 0.7
	return maxf(k, 2.0)

static func _settlement_year(w, s: Dictionary, cfg: Dictionary, fx: Dictionary) -> void:
	var p: Dictionary = w.peoples[int(s.people)]
	var sp: Dictionary = w.cat.species[species_of(w, s)]
	var st := stats_of(w, s)
	var pop := float(s.pop)
	s.prev_pop = pop
	# Statuts temporaires.
	for k in s.statuses.keys():
		s.statuses[k] = int(s.statuses[k]) - 1
		if int(s.statuses[k]) <= 0:
			s.statuses.erase(k)
	# Territoire (rayon selon la taille) tous les 5 ans ou si vide.
	if w.year % 5 == int(s.id) % 5 or s.territory.is_empty():
		_update_territory(w, s)
	# Capacité : recalculée tous les 5 ans, ou si le terrain, le territoire ou les techniques ont changé.
	var stamp := "%d_%d_%d" % [w.planet.version, s.territory.size(), w.peoples[int(s.people)].techs.size()]
	var k: float
	if s.get("_kstamp", "") != stamp or w.year % 5 == int(s.id) % 5 or not s.has("_kbase"):
		s["_kbase"] = capacity(w, s, st, fx) / (0.7 if s.statuses.has("maudit") else 1.0)
		s["_kstamp"] = stamp
	k = float(s._kbase) * (0.7 if s.statuses.has("maudit") else 1.0)
	s.capacity = k
	# Nourriture.
	var need := pop * float(cfg.food_per_pop) * (1.15 - float(st.food) * 0.3)
	var prod := minf(pop, k) * float(cfg.food_per_pop) * 1.1 * Climate.food_factor(w, s)
	var store_cap := pop * 1.5 * (1.0 + float(fx.get("storage", 0.0)))
	var stock := float(s.food) + prod - need
	var famine := false
	var deaths := pop * float(cfg.base_death_rate) * (1.3 - float(st.lon) * 0.6)
	if stock < 0.0:
		famine = true
		var deficit := -stock / maxf(float(cfg.food_per_pop), 0.01)
		deaths += deficit * float(cfg.famine_death_rate) * 4.0 * (1.2 - float(st.coop) * 0.5 - float(st.end) * 0.3)
		stock = 0.0
		if not s.statuses.has("famine"):
			s.statuses["famine"] = 3
			w.add_log("Famine à %s" % s.name, "Nourriture insuffisante (population %d, capacité %d)" % [int(pop), int(k)], "crisis", int(s.cell))
	s.food = minf(stock, store_cap)
	# Surpopulation au-delà de la capacité.
	if pop > k:
		deaths += (pop - k) * 0.25
	# Épidémies (densité, immunité).
	if pop > 250 and not s.statuses.has("epidemie") and not s.statuses.has("protege"):
		var risk := 0.004 * (pop / 500.0) * (1.4 - float(st.disease) - float(fx.get("disease", 0.0)))
		if w.rng.randf() < risk:
			s.statuses["epidemie"] = 4
			deaths += pop * 0.12
			w.add_log("Épidémie à %s" % s.name, "Forte densité (%d habitants) et faible résistance aux maladies" % int(pop), "crisis", int(s.cell))
	# Naissances entières, résolues une par une pour les affinités.
	var br := float(cfg.birth_rate) * (0.5 + float(sp.growth) * 20.0 * float(st.fert))
	var births_f := pop * br * maxf(0.0, 1.0 - pop / (1.1 * k))
	if pop < 1.0:
		births_f = 0.0
	s.birth_acc = float(s.birth_acc) + births_f
	var births := int(floor(s.birth_acc))
	s.birth_acc = float(s.birth_acc) - births
	deaths = minf(deaths, pop)
	Affinity.apply_deaths(s, deaths)
	Affinity.resolve_births(w, s, births)
	s.pop = maxf(pop - deaths + births, 0.0)
	# Maîtrise : seulement l'apprentissage des porteurs. Entraînement aux armes : compétence ordinaire de tous.
	var gain := float(w.cat.cfg("affinity", "mastery_gain_per_year", 0.01))
	s.mastery.magic = minf(1.0, float(s.mastery.magic) + gain * (1.0 + float(fx.get("magic_mastery_rate", 0.0))) * (0.5 + float(st.mag)) * (1.0 - float(s.mastery.magic)))
	s.mastery.sword = minf(1.0, float(s.mastery.sword) + gain * (1.0 + float(fx.get("sword_mastery_rate", 0.0))) * (0.5 + float(st.str)) * (1.0 - float(s.mastery.sword)))
	s.training = minf(1.0, float(s.training) + gain * 0.5 * float(fx.get("military", 0.0)) * (1.0 - float(s.training)))
	var holders_sword := float(s.aff.sword) + float(s.aff.both)
	var holders_magic := float(s.aff.magic) + float(s.aff.both)
	s.military = float(s.pop) * 0.02 * (0.5 + float(st.str)) * (1.0 + float(fx.get("military", 0.0)) + float(s.training)) \
		+ holders_sword * (0.3 + float(s.mastery.sword)) * 0.4 + holders_magic * float(s.mastery.magic) * 0.2
	# Stabilité.
	var target := 0.45 + float(st.coop) * 0.3 - float(st.agg) * 0.15 + float(s.fervor) * 0.1 + float(fx.get("stability", 0.0))
	if famine:
		target -= 0.3
	if s.statuses.has("epidemie"):
		target -= 0.15
	if s.statuses.has("traumatise"):
		target -= 0.2
	if w.people_at_war(int(s.people)):
		target -= 0.1
	s.stability = clampf(lerpf(float(s.stability), target, 0.2), 0.0, 1.0)
	# Génétique : une génération tous les generation_years (allongés par la longévité).
	var gen_years := int(float(sp.generation_years) * (0.7 + float(st.lon) * 0.6))
	if w.year - int(s.last_gen) >= gen_years:
		s.last_gen = w.year
		_generation(w, s, k, famine)
		w.tick_cache.erase("st%d" % int(s.id))
	if float(s.pop) < 1.0:
		_abandon(w, s, "Population éteinte")
		return
	_try_expand(w, s, cfg, st, k)

static func _generation(w, s: Dictionary, k: float, famine: bool, intensity: float = 1.0) -> void:
	var env := Genetics.environment_pressure(w.planet, int(s.cell), float(s.pop) / maxf(k, 1.0), famine)
	var events := Genetics.generation_step(w.cat, s.freqs, env, float(s.pop), w.rng, intensity)
	var p: Dictionary = w.peoples[int(s.people)]
	for e in events:
		var tname: String = w.cat.traits[e.trait].name
		match e.type:
			"mutation":
				w.add_log("Mutation à %s : %s" % [s.name, tname], "Mutation aléatoire apparue chez quelques nouveau-nés", "genetics", int(s.cell))
			"dominant":
				var why := "Sélection par le milieu (%s)" % Planet.BIOME_NAMES[w.planet.biome_name(int(s.cell))]
				w.add_log("%s : le trait « %s » devient majoritaire" % [s.name, tname], why, "genetics", int(s.cell))
				p.history.append({"year": w.year, "text": "« %s » devient majoritaire à %s. %s." % [tname, s.name, why]})
			"lost":
				if w.rng.randf() < 0.3:
					w.add_log("%s : le trait « %s » a disparu" % [s.name, tname], "Dérive génétique ou sélection défavorable", "genetics", int(s.cell))

static func force_generation(w, s: Dictionary, intensity: float) -> void:
	_generation(w, s, float(s.capacity), s.statuses.has("famine"), intensity)

static func _update_territory(w, s: Dictionary) -> void:
	var pop := float(s.pop)
	var r := 0 if pop < 12 else (1 if pop < 150 else (2 if pop < 600 else 3))
	for c in s.territory:
		if w.owner[int(c)] == int(s.id):
			w.owner[int(c)] = -1
	var cells: Array = w.planet.cells_within(int(s.cell), r, 40)
	var terr := []
	for c in cells:
		if w.planet.is_land(c) and (w.owner[c] == -1 or w.owner[c] == int(s.id)):
			terr.append(c)
			w.owner[c] = int(s.id)
	if not int(s.cell) in terr:
		terr.push_front(int(s.cell))
		w.owner[int(s.cell)] = int(s.id)
	s.territory = terr

static func _try_expand(w, s: Dictionary, cfg: Dictionary, st: Dictionary, k: float) -> void:
	var pop := float(s.pop)
	var threshold := float(cfg.found_min_pop) * (0.7 + float(st.soc) * 0.6)
	if pop < threshold or pop < 0.55 * k:
		return
	if w.people_settlements(int(s.people)).size() >= int(cfg.max_settlements_per_people):
		return
	if w.rng.randf() > 0.12 * (0.5 + float(st.cur)) * (0.5 + float(st.cou)):
		return
	var p: Dictionary = w.peoples[int(s.people)]
	var fx := tech_fx(w, p)
	var radius := int(cfg.expansion_search_radius)
	var cand: Array = w.planet.cells_within(int(s.cell), radius, int(cfg.expansion_max_visited))
	var best := -1
	var best_score := 0.2 * (1.3 - float(st.cou))
	for c in cand:
		if not w.planet.is_land(c) or w.owner[c] != -1:
			continue
		var crowded := false
		for nb in w.planet.neighbors[c]:
			if w.owner[nb] != -1:
				crowded = true
				break
		if crowded:
			continue
		var d: float = w.planet.pos[c].distance_to(w.planet.pos[int(s.cell)])
		var sc: float = cell_food(w, c, species_of(w, s), st, fx) - d * 0.6 + w.rng.randf() * 0.05
		if sc > best_score:
			best_score = sc
			best = c
	if best < 0:
		return
	var frac := float(cfg.split_fraction)
	var moving := pop * frac
	var ns: Dictionary = w._new_settlement(int(s.people), best, moving, Genetics.founder_effect(s.freqs, w.rng))
	ns["from"] = int(s.id)
	ns.aff = Affinity.split_counts(s, frac)
	ns.aff_src = Affinity.split_sources(s, frac)
	ns.faith = s.faith.duplicate()
	ns.memory = s.memory.duplicate()
	ns.fervor = s.fervor
	ns.mastery = s.mastery.duplicate()
	ns.training = s.training
	ns.food = float(s.food) * frac
	s.food = float(s.food) * (1.0 - frac)
	s.pop = pop - moving
	_update_territory(w, ns)
	var why := "Surpopulation à %s (%d habitants pour une capacité de %d) ; terres plus fertiles trouvées à proximité" % [s.name, int(pop), int(k)]
	w.add_log("%s fonde %s" % [p.name, ns.name], why, "settlement", best)
	p.history.append({"year": w.year, "text": "Fondation de %s." % ns.name})

static func _abandon(w, s: Dictionary, why: String) -> void:
	s.alive = false
	w.invalidate_settlements()
	s.pop = 0.0
	for c in s.territory:
		if w.owner[int(c)] == int(s.id):
			w.owner[int(c)] = -1
	w.add_log("%s est abandonné" % s.name, why, "crisis", int(s.cell))

# ------------------------------------------------------------------ Techniques

static func tech_fx(w, p: Dictionary) -> Dictionary:
	var key := "fx%d" % int(p.id)
	if w.tick_cache.has(key):
		return w.tick_cache[key]
	var fx := {}
	for t in p.techs:
		if not w.cat.techs.has(t):
			continue
		var tfx: Dictionary = w.cat.techs[t].fx
		for k in tfx:
			fx[k] = fx.get(k, 0.0) + float(tfx[k])
	w.tick_cache[key] = fx
	return fx

## Pourquoi une technique est-elle indisponible ? "" si disponible.
static func tech_block_reason(w, p: Dictionary, tid: String, agg: Dictionary) -> String:
	var t: Dictionary = w.cat.techs[tid]
	for pr in t.prereq:
		if not p.techs.has(pr):
			return "prérequis : " + w.cat.techs[pr].name
	var req: Dictionary = t.req
	for r in req.get("resources", []):
		if not agg.resources.has(r):
			return "ressource absente : " + Planet.RES_NAMES[r]
	if req.has("min_stability") and agg.stability < float(req.min_stability):
		return "stabilité insuffisante"
	if req.has("min_pop") and agg.pop < float(req.min_pop):
		return "population insuffisante (%d)" % int(req.min_pop)
	if req.has("min_fertility") and agg.fertility < float(req.min_fertility):
		return "sols trop pauvres"
	if req.get("coastal", false) and not agg.coastal:
		return "pas d'accès à la mer"
	var aff: Dictionary = req.get("affinity", {})
	for a in aff:
		if agg["share_" + a] < float(aff[a]):
			return "trop peu de porteurs de l'affinité %s" % Affinity.NAMES[a]
	return ""

static func people_aggregate(w, p: Dictionary) -> Dictionary:
	var res := {}
	var pop := 0.0
	var stab := 0.0
	var fert := 0.0
	var ncell := 0
	var coastal := false
	var magic := 0.0
	var sword := 0.0
	var mm := 0.0
	for s in w.people_settlements(int(p.id)):
		pop += float(s.pop)
		stab += float(s.stability) * float(s.pop)
		magic += float(s.aff.magic) + float(s.aff.both)
		sword += float(s.aff.sword) + float(s.aff.both)
		mm += float(s.mastery.magic) * (float(s.aff.magic) + float(s.aff.both))
		for c in s.territory:
			for r in w.planet.res_list(int(c)):
				res[r] = true
			fert += w.planet.fertility[int(c)]
			ncell += 1
			if w.planet.is_coastal(int(c)):
				coastal = true
	# Ressources obtenues par commerce (accords actifs, hors guerre).
	for k in w.relations:
		var r: Dictionary = w.relations[k]
		if r.get("trade", false) and not r.war:
			var parts: PackedStringArray = k.split(":")
			var other := -1
			if int(parts[0]) == int(p.id):
				other = int(parts[1])
			elif int(parts[1]) == int(p.id):
				other = int(parts[0])
			if other >= 0:
				for os in w.people_settlements(other):
					for c in os.territory:
						for rr in w.planet.res_list(int(c)):
							res[rr] = true
	var tot := maxf(pop, 1.0)
	return {"pop": pop, "stability": stab / tot, "resources": res, "fertility": fert / maxf(ncell, 1),
		"coastal": coastal, "share_magic": magic / tot, "share_sword": sword / tot, "magic_mastered": mm}

static func _research(w, p: Dictionary, fx: Dictionary) -> void:
	var agg := people_aggregate(w, p)
	if agg.pop <= 0.0:
		return
	var avail := []
	for tid in w.cat.tech_order:
		if p.techs.has(tid):
			continue
		if tech_block_reason(w, p, tid, agg) == "":
			avail.append(tid)
	var cur: String = p.research.current
	if cur == "" or p.techs.has(cur) or not cur in avail:
		cur = _choose_tech(w, p, avail)
		p.research.current = cur
		p.research.progress = 0.0
	if cur == "":
		if int(p.research.stalled_since) < 0:
			p.research.stalled_since = w.year
		elif w.year - int(p.research.stalled_since) == 60:
			w.add_log("%s stagne" % p.name, "Aucune découverte possible : ressources, stabilité, population ou porteurs d'affinité manquants", "tech", int(p.origin_cell))
		return
	p.research.stalled_since = -1
	var sp0: Dictionary = w.people_settlements(int(p.id))[0]
	var st := stats_of(w, sp0)
	var t: Dictionary = w.cat.techs[cur]
	var pts: float = pow(agg.pop, 0.6) * (0.4 + float(st.int) * 0.6 + float(st.cur) * 0.3) * (0.5 + agg.stability)
	pts *= float(w.cat.config.civ.research_scale) * (1.0 + float(fx.get("research_mult", 0.0)))
	match str(t.path):
		"science":
			pts *= 0.6 + float(st.sci) + maxf(float(p.lean), 0.0) * 0.4
		"magic":
			pts *= 0.4 + float(st.mag) * 0.6 + maxf(-float(p.lean), 0.0) * 0.4
			pts += agg.magic_mastered * 0.05
		"hybrid":
			pts *= 0.5 + (float(st.sci) + float(st.mag)) * 0.5
	for s in w.people_settlements(int(p.id)):
		if s.statuses.has("inspire"):
			pts *= 1.3
			break
	p.research.progress = float(p.research.progress) + pts
	if float(p.research.progress) >= float(t.cost):
		learn_tech(w, p, cur, "Recherche de %s (stabilité %.0f %%, %d habitants)" % [p.name, agg.stability * 100.0, int(agg.pop)])
	# Régression lors de crises graves.
	if agg.stability < 0.25 and p.techs.size() > 1 and w.rng.randf() < 0.05 * (1.3 - float(st.lon)):
		_regress(w, p, "Instabilité prolongée (%.0f %%) : le savoir se perd" % (agg.stability * 100.0))

static func _choose_tech(w, p: Dictionary, avail: Array) -> String:
	var best := ""
	var best_sc := -INF
	for tid in avail:
		var t: Dictionary = w.cat.techs[tid]
		var sc: float = -float(t.cost) / 100.0 + w.rng.randf() * 0.5
		match str(t.path):
			"science": sc += float(p.lean) * 1.5
			"magic": sc -= float(p.lean) * 1.5
			"hybrid": sc += 0.3 - absf(float(p.lean))
		if sc > best_sc:
			best_sc = sc
			best = tid
	return best

static func learn_tech(w, p: Dictionary, tid: String, why: String) -> void:
	w.tick_cache.erase("fx%d" % int(p.id))
	var t: Dictionary = w.cat.techs[tid]
	p.techs[tid] = w.year
	p.research.current = ""
	p.research.progress = 0.0
	for c in t.get("culture", []):
		p.culture[c] = maxf(float(p.culture.get(c, 0.0)), 0.5)
	# Les découvertes orientent la culture vers leur voie.
	match str(t.path):
		"science": p.lean = clampf(float(p.lean) + 0.05, -1.0, 1.0)
		"magic": p.lean = clampf(float(p.lean) - 0.05, -1.0, 1.0)
	var old_era := int(p.era)
	p.era = era_of(w, p)
	w.add_log("%s découvre : %s" % [p.name, t.name], why, "tech", int(p.origin_cell))
	if int(p.era) > old_era:
		w.add_log("%s entre dans l'%s" % [p.name, w.cat.eras[int(p.era)]], "Plusieurs découvertes de cette époque maîtrisées", "tech", int(p.origin_cell))
		p.history.append({"year": w.year, "text": "Entrée dans l'%s." % w.cat.eras[int(p.era)]})

static func _regress(w, p: Dictionary, why: String) -> void:
	var latest := ""
	var ly := -1
	for t in p.techs:
		if int(p.techs[t]) > ly:
			ly = int(p.techs[t])
			latest = t
	if latest == "":
		return
	p.techs.erase(latest)
	w.tick_cache.erase("fx%d" % int(p.id))
	p.era = era_of(w, p)
	w.add_log("%s oublie : %s" % [p.name, w.cat.techs[latest].name], why, "tech", int(p.origin_cell))
	p.history.append({"year": w.year, "text": "Régression : perte de « %s »." % w.cat.techs[latest].name})

## Époque = la plus haute époque dont au moins 2 techniques sont connues (1 pour l'âge astral).
static func era_of(w, p: Dictionary) -> int:
	var counts := {}
	for t in p.techs:
		var e := int(w.cat.techs[t].era)
		counts[e] = counts.get(e, 0) + 1
	var era := 0
	for e in counts:
		if counts[e] >= (1 if e == 5 else 2):
			era = maxi(era, e)
	return era

# ------------------------------------------------------------------ Politique

static func _politics(w, p: Dictionary) -> void:
	var list: Array = w.people_settlements(int(p.id))
	var n := list.size()
	var old: String = p.polity
	var polity := "Tribu"
	if n >= 15:
		polity = "Empire"
	elif n >= 6 and (p.techs.has("ecriture") or p.techs.has("forteresses")):
		polity = "Royaume"
	elif n >= 3:
		polity = "Chefferie"
	if polity != old:
		p.polity = polity
		w.add_log("%s devient un(e) %s" % [p.name, polity], "%d établissements" % n, "politics", int(p.origin_cell))
		p.history.append({"year": w.year, "text": "Devient : %s." % polity})
	# Scission : grand peuple instable.
	# Le risque croît avec l'étendue (au-delà de 10 établissements) et l'instabilité : les empires finissent par se fragmenter.
	if n >= 8 and w.year % 10 == 0:
		var stab := 0.0
		for s in list:
			stab += float(s.stability)
		stab /= n
		var risk := (0.5 if stab < 0.35 else 0.0) + maxf(0.0, float(n - 10) / 60.0) * (1.0 - stab)
		if w.rng.randf() < risk:
			_secede(w, p, list, stab)

static func _secede(w, p: Dictionary, list: Array, stab: float) -> void:
	var origin: Vector3 = w.planet.pos[int(p.origin_cell)]
	list.sort_custom(func(a, b): return w.planet.pos[int(a.cell)].distance_to(origin) > w.planet.pos[int(b.cell)].distance_to(origin))
	var nid: int = w.peoples.size()
	var np: Dictionary = p.duplicate(true)
	np.id = nid
	np.name = "%s de %s" % [w.cat.species[p.species].name, list[0].name]
	np.parent = int(p.id)
	np.founded = w.year
	np.origin_cell = int(list[0].cell)
	np.history = [{"year": w.year, "text": "Sécession de %s (stabilité %.0f %%)." % [p.name, stab * 100.0]}]
	np.color = [clampf(float(p.color[0]) * 0.75 + 0.2, 0.0, 1.0), float(p.color[1]) * 0.8, clampf(float(p.color[2]) + 0.15, 0.0, 1.0)]
	w.peoples.append(np)
	for i in list.size() / 2:
		list[i].people = nid
		w.tick_cache.erase("st%d" % int(list[i].id))
	w.invalidate_settlements()
	w.add_log("Sécession : %s" % np.name, "Peuple trop étendu (%d établissements) et instable (stabilité moyenne %.0f %%)" % [list.size(), stab * 100.0], "politics", int(np.origin_cell))
	p.history.append({"year": w.year, "text": "Sécession de %s." % np.name})

static func _relations(w) -> void:
	if w.year % 2 != 0:
		return
	var contacts := {}
	for s in w.alive_settlements():
		for c in s.territory:
			for nb in w.planet.neighbors[int(c)]:
				var o: int = w.owner[nb]
				if o >= 0 and int(w.settlements[o].people) != int(s.people):
					contacts[w.rel_key(int(s.people), int(w.settlements[o].people))] = true
	for k in contacts:
		var parts: PackedStringArray = k.split(":")
		var a := int(parts[0])
		var b := int(parts[1])
		var r: Dictionary = w.relation(a, b)
		if not r.contact:
			r.contact = true
			w.add_log("Premier contact : %s et %s" % [w.peoples[a].name, w.peoples[b].name], "Leurs territoires se touchent", "diplomacy", int(w.peoples[a].origin_cell))
		var sa := stats_of(w, w.people_settlements(a)[0]) if w.people_settlements(a).size() > 0 else {}
		var sb := stats_of(w, w.people_settlements(b)[0]) if w.people_settlements(b).size() > 0 else {}
		if sa.is_empty() or sb.is_empty():
			continue
		var delta := -0.02 * (float(sa.agg) + float(sb.agg)) + 0.01 * (float(sa.coop) + float(sb.coop))
		if _main_religion(w, a) == _main_religion(w, b):
			delta += 0.03
		var da: Dictionary = w.deities[int(w.peoples[a].deity)]
		var db: Dictionary = w.deities[int(w.peoples[b].deity)]
		delta += 0.02 * float(da.relations.get(str(db.id), 0.0))
		r.value = clampf(float(r.value) + delta, -1.0, 1.0)
		if not r.war and float(r.value) < -0.5 and w.rng.randf() < 0.3 * (float(sa.agg) + float(sb.agg)):
			r.war = true
			r.since = w.year
			r.alliance = false
			w.add_log("Guerre : %s contre %s" % [w.peoples[a].name, w.peoples[b].name], "Tensions frontalières, tempéraments agressifs (relation %.2f)" % float(r.value), "war", int(w.peoples[a].origin_cell))
		elif r.war:
			_battle(w, a, b, r)
		elif not r.alliance and float(r.value) > 0.6:
			r.alliance = true
			w.add_log("Alliance : %s et %s" % [w.peoples[a].name, w.peoples[b].name], "Relations excellentes (%.2f)" % float(r.value), "diplomacy", int(w.peoples[a].origin_cell))

static func _main_religion(w, pid: int) -> int:
	var shares := {}
	for s in w.people_settlements(pid):
		for rid in s.faith:
			shares[rid] = shares.get(rid, 0.0) + float(s.faith[rid]) * float(s.pop)
	var best := -1
	var bv := 0.0
	for rid in shares:
		if shares[rid] > bv:
			bv = shares[rid]
			best = int(rid)
	return best

static func _battle(w, a: int, b: int, r: Dictionary) -> void:
	var ma := 0.0
	var mb := 0.0
	for s in w.people_settlements(a):
		ma += float(s.military)
	for s in w.people_settlements(b):
		mb += float(s.military)
	var total := maxf(ma + mb, 0.1)
	for s in w.people_settlements(a):
		var loss := float(s.pop) * 0.02 * (mb / total)
		Affinity.apply_deaths(s, loss)
		s.pop = float(s.pop) - loss
	for s in w.people_settlements(b):
		var loss2 := float(s.pop) * 0.02 * (ma / total)
		Affinity.apply_deaths(s, loss2)
		s.pop = float(s.pop) - loss2
	if w.year - int(r.since) > 10 or w.rng.randf() < 0.08:
		r.war = false
		r.value = -0.1
		var winner: String = w.peoples[a].name if ma >= mb else w.peoples[b].name
		w.add_log("Paix entre %s et %s" % [w.peoples[a].name, w.peoples[b].name], "Épuisement de la guerre ; avantage à %s (forces %.0f contre %.0f)" % [winner, maxf(ma, mb), minf(ma, mb)], "war", int(w.peoples[a].origin_cell))

static func _check_extinction(w) -> void:
	for p in w.peoples:
		if not p.extinct and w.people_settlements(int(p.id)).is_empty():
			p.extinct = true
			w.add_log("%s a disparu" % p.name, "Plus aucun établissement habité", "crisis", int(p.origin_cell))
