extends RefCounted
## État complet d'une partie + orchestration du tick annuel. Aucune dépendance au rendu.

const Catalog = preload("res://sim/catalog.gd")
const Planet = preload("res://sim/planet.gd")
const Genetics = preload("res://sim/genetics.gd")
const Affinity = preload("res://sim/affinity.gd")
const Civ = preload("res://sim/civ_system.gd")
const Faith = preload("res://sim/faith_system.gd")
const Powers = preload("res://sim/powers.gd")
const RivalAI = preload("res://sim/rival_ai.gd")
const Diplomacy = preload("res://sim/diplomacy.gd")
const History = preload("res://sim/history.gd")
const Climate = preload("res://sim/climate.gd")

const SAVE_VERSION := 1
const LOG_MAX := 400

var cat
var planet
var rng := RandomNumberGenerator.new()
var world_seed: int = 0
var world_name: String = "Nouveau monde"
var year: int = 0
var peoples: Array = []
var settlements: Array = []
var religions: Array = []
var deities: Array = []
var relations: Dictionary = {}       # "a:b" (a<b) -> {value, war, since, alliance, contact}
var pending: Array = []              # effets différés
var chronicle: Array = []
var series: Dictionary = History.empty()
var climate: Dictionary = Climate.none()
var owner: Array = []                # cellule -> id d'établissement ou -1 (Array : modifié en place depuis les systèmes)
var birth_counter: int = 0
var stats_births: Dictionary = {}
var affinity_history: Array = []
var player_deity: int = 0
var tutorial: Dictionary = {"step": 0, "done": []}
var offline_consumed_until: int = 0  # horodatage Unix jusqu'auquel l'absence a déjà été simulée
var last_saved_unix: int = 0
var tick_ms_last: float = 0.0
var tick_cache := {}                # calculs réutilisés pendant une année simulée (jamais sauvegardé)

func _init(p_cat = null) -> void:
	cat = p_cat if p_cat != null else Catalog.shared()
	stats_births = Affinity.empty_stats()

# ------------------------------------------------------------------ Création

func create_planet(p_seed: int, subdivisions: int = -1) -> void:
	world_seed = p_seed
	rng.seed = p_seed
	planet = Planet.new()
	if subdivisions < 0:
		subdivisions = int(cat.cfg("planet", "subdivisions", 4))
	planet.generate(p_seed, subdivisions)
	owner.resize(planet.cell_count)
	owner.fill(-1)

## founders : [{name, traits:[...]}, {...}] ; deity_info : {name, color}
func create_player_people(species_id: String, people_name: String, founders: Array, deity_info: Dictionary) -> int:
	var d := _new_deity(deity_info.get("name", "Vous"), true, {"benevolence": 0.5, "aggression": 0.3, "magic_bias": 0.0}, deity_info.get("color", [1.0, 0.85, 0.3]))
	player_deity = d
	var rules: Array = deities[d].rules
	rules.append(Affinity.new_rule(0, "Exemple : mages pour la recherche", Affinity.MAGIC, [{"field": "need", "value": "magic_research"}], 1, 3))
	rules[0].enabled = false
	return _create_people(species_id, people_name, founders, d)

func create_rivals(count: int) -> void:
	var used := {}
	for p in peoples:
		used[p.species] = true
	var options: Array = []
	for s in cat.species_order:
		if not used.has(s):
			options.append(s)
	for i in count:
		if options.is_empty():
			options = cat.species_order.duplicate()
		var sp: String = options[rng.randi_range(0, options.size() - 1)]
		options.erase(sp)
		var pers := {"benevolence": rng.randf_range(0.1, 0.9), "aggression": rng.randf_range(0.1, 0.9), "magic_bias": rng.randf_range(-0.8, 0.8)}
		var dname := Genetics.make_name(rng, sp) + ", " + _deity_title(pers)
		var d := _new_deity(dname, false, pers, [rng.randf_range(0.3, 1.0), rng.randf_range(0.2, 0.7), rng.randf_range(0.3, 1.0)])
		deities[d].rules = Affinity.rival_rules(pers)
		var founders := []
		var heritable: Array = cat.heritable_traits()
		for f in 2:
			var traits := []
			for k in 5:
				var t: String = heritable[rng.randi_range(0, heritable.size() - 1)]
				var ok := not t in traits
				for o in traits:
					if cat.incompatible(t, o):
						ok = false
				if ok:
					traits.append(t)
			founders.append({"name": Genetics.make_name(rng, sp), "traits": traits})
		_create_people(sp, cat.species[sp].name + " de " + Genetics.make_name(rng, sp), founders, d)

func _deity_title(p: Dictionary) -> String:
	if p.aggression > 0.6:
		return "Seigneur des lames"
	if p.magic_bias > 0.4:
		return "Tisseuse d'arcanes"
	if p.benevolence > 0.6:
		return "Gardien des moissons"
	return "Voix des cimes"

func _new_deity(dname: String, is_player: bool, pers: Dictionary, color: Array) -> int:
	var id := deities.size()
	deities.append({"id": id, "name": dname, "is_player": is_player, "personality": pers, "color": color,
		"energy": 15.0, "max_energy": float(cat.cfg("faith", "base_max_energy", 60.0)), "xp": 0, "level": 0,
		"achievements": [], "powers_used": 0, "rules": [], "manual_orders": [],
		"auto_budget": float(cat.cfg("affinity", "default_auto_budget_per_year", 4.0)), "auto_spent": 0.0,
		"affinities_granted": 0, "faith_rate": 0.0, "believers": 0.0, "relations": {}, "next_rule_id": 1})
	return id

func _create_people(species_id: String, pname: String, founders: Array, deity_id: int) -> int:
	var pid := peoples.size()
	var sp: Dictionary = cat.species[species_id]
	var cell := _find_start_cell(species_id)
	var freqs := Genetics.founders_to_freqs(founders.map(func(f): return f.traits))
	var rid := religions.size()
	religions.append({"id": rid, "deity": deity_id, "name": "Culte de " + deities[deity_id].name.split(",")[0], "founder_people": pid})
	peoples.append({"id": pid, "name": pname, "species": species_id, "color": sp.color, "deity": deity_id, "religion": rid,
		"culture": {}, "techs": {}, "research": {"current": "", "progress": 0.0, "stalled_since": -1},
		"lean": float(deities[deity_id].personality.magic_bias) * -0.5, "founders": founders, "founded": year,
		"origin_cell": cell, "history": [], "extinct": false, "era": 0, "polity": "Tribu", "parent": -1})
	var s := _new_settlement(pid, cell, 2.0, freqs)
	# Les deux fondateurs : sans affinité, sauf don divin explicite lors de la création.
	for f in founders:
		var a: String = f.get("affinity", Affinity.NONE)
		s.aff[a] = float(s.aff[a]) + 1.0
		Affinity._add_src(s, a, "creation", 1.0)
	s.faith = {str(rid): 1.0}
	s.fervor = 0.8
	s.memory = {str(deity_id): 1.0}
	peoples[pid].history.append({"year": year, "text": "Création de %s et %s, fondateurs du peuple." % [founders[0].name, founders[1].name]})
	add_log("Naissance d'un peuple : %s" % pname, "Créés par %s" % deities[deity_id].name, "people", cell)
	return pid

func _find_start_cell(species_id: String) -> int:
	var best := -1
	var best_score := -1.0
	var hab: Dictionary = cat.species[species_id].habitat
	for k in 400:
		var c := rng.randi_range(0, planet.cell_count - 1)
		if not planet.is_land(c) or owner[c] != -1 or _too_close(c, 6):
			continue
		var sc: float = float(hab.get(planet.biome_name(c), 0.0)) * (0.4 + planet.fertility[c])
		if planet.is_coastal(c):
			sc += float(cat.species[species_id].get("coastal_bonus", 0.1))
		if sc > best_score:
			best_score = sc
			best = c
	if best < 0:
		for c in planet.cell_count:
			if planet.is_land(c) and owner[c] == -1:
				return c
	return best

func _too_close(cell: int, dist: int) -> bool:
	for s in settlements:
		if s.alive and planet.pos[cell].distance_to(planet.pos[int(s.cell)]) < dist * 0.06:
			return true
	return false

func _new_settlement(pid: int, cell: int, pop: float, freqs: Dictionary) -> Dictionary:
	var id := settlements.size()
	var p: Dictionary = peoples[pid]
	var s := {"id": id, "name": Genetics.make_name(rng, p.species), "people": pid, "species": p.species, "cell": cell, "pop": pop,
		"birth_acc": 0.0, "aff": Affinity.empty_counts(), "mastery": {"magic": 0.0, "sword": 0.0}, "training": 0.0,
		"freqs": freqs, "faith": {}, "fervor": 0.5, "memory": {}, "statuses": {}, "stability": 0.6,
		"food": pop * 2.0, "capacity": 10.0, "territory": [cell], "founded": year, "alive": true,
		"last_gen": year, "last_help": -100, "births": Affinity.empty_stats(), "military": 0.0,
		"aff_src": Affinity.empty_sources(), "prev_pop": pop}
	settlements.append(s)
	owner[cell] = id
	invalidate_settlements()
	return s

# ------------------------------------------------------------------ Tick

func tick() -> void:
	while not tick_step(1 << 30):
		pass

var _phase := 0
var _phase_list: Array = []
var _phase_index := 0
var _tick_t0 := 0

func tick_in_progress() -> bool:
	return _phase != 0

## Termine immédiatement l'année en cours (avant une sauvegarde, par exemple).
func finish_tick() -> void:
	if _phase != 0:
		while not tick_step(1 << 30):
			pass

## Avance l'année en cours par phases, dans un budget de temps (µs). Renvoie true quand l'année est finie.
## Permet d'étaler le calcul sur plusieurs images (pas d'à-coup sur téléphone). Même résultat que tick().
func tick_step(budget_usec: int) -> bool:
	var start := Time.get_ticks_usec()
	if _phase == 0:
		_tick_t0 = start
		tick_cache.clear()
		year += 1
		for d in deities:
			d.auto_spent = 0.0
			for r in d.rules:
				r.used_this_year = 0
		Powers.process_pending(self)
		Climate.tick(self)
		for p in peoples:
			if not p.extinct:
				Civ.tech_fx(self, p)
		_phase_list = alive_settlements().duplicate()
		_phase_index = 0
		_phase = 1
	if _phase == 1:
		var cfg: Dictionary = cat.config.civ
		while _phase_index < _phase_list.size():
			var s: Dictionary = _phase_list[_phase_index]
			_phase_index += 1
			if s.alive:
				Civ._settlement_year(self, s, cfg, Civ.tech_fx(self, peoples[int(s.people)]))
			if Time.get_ticks_usec() - start > budget_usec:
				return false
		_phase = 2
	if _phase == 2:
		for p in peoples.duplicate():   # copie : une sécession peut ajouter un peuple pendant la boucle
			if not p.extinct:
				Civ._research(self, p, Civ.tech_fx(self, p))
				Civ._politics(self, p)
		_phase = 3
		if Time.get_ticks_usec() - start > budget_usec:
			return false
	if _phase == 3:
		Diplomacy.tick(self)
		Civ._check_extinction(self)
		_phase = 4
		if Time.get_ticks_usec() - start > budget_usec:
			return false
	if _phase == 4:
		Faith.tick(self)
		_phase = 5
		if Time.get_ticks_usec() - start > budget_usec:
			return false
	RivalAI.tick(self)
	History.tick(self)
	Faith.check_achievements(self)
	tick_cache.clear()
	_phase = 0
	tick_ms_last = (Time.get_ticks_usec() - _tick_t0) / 1000.0
	return true

func run_years(n: int) -> void:
	for i in n:
		tick()

# ------------------------------------------------------------------ Requêtes

func alive_settlements() -> Array:
	if tick_cache.has("alive"):
		return tick_cache.alive
	var out := settlements.filter(func(s): return s.alive)
	tick_cache["alive"] = out
	return out

func people_settlements(pid: int) -> Array:
	if not tick_cache.has("bypeople"):
		var by := {}
		for s in settlements:
			if s.alive:
				var k := int(s.people)
				if not by.has(k):
					by[k] = []
				by[k].append(s)
		tick_cache["bypeople"] = by
	return tick_cache.bypeople.get(pid, [])

## À appeler quand la liste des établissements ou leur peuple change.
func invalidate_settlements() -> void:
	tick_cache.erase("alive")
	tick_cache.erase("bypeople")

func people_pop(pid: int) -> float:
	var t := 0.0
	for s in people_settlements(pid):
		t += float(s.pop)
	return t

func rel_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]

func relation(a: int, b: int) -> Dictionary:
	var k := rel_key(a, b)
	if not relations.has(k):
		relations[k] = {"value": 0.0, "war": false, "since": year, "alliance": false, "contact": false}
	return relations[k]

func people_at_war(pid: int) -> bool:
	for k in relations:
		var r: Dictionary = relations[k]
		if r.war:
			var parts: PackedStringArray = k.split(":")
			if int(parts[0]) == pid or int(parts[1]) == pid:
				return true
	return false

func believers_of(deity_id: int) -> float:
	var t := 0.0
	for s in settlements:
		if not s.alive:
			continue
		for rid in s.faith:
			if int(religions[int(rid)].deity) == deity_id:
				t += float(s.pop) * float(s.faith[rid])
	return t

func settlement_at(cell: int) -> Dictionary:
	if cell < 0 or cell >= owner.size() or owner[cell] < 0:
		return {}
	return settlements[owner[cell]]

func add_log(text: String, why: String, kind: String, cell: int = -1) -> void:
	chronicle.append({"y": year, "txt": text, "why": why, "kind": kind, "cell": cell})
	while chronicle.size() > LOG_MAX:
		chronicle.pop_front()

## Instantané pour les résumés (absence, tests).
func snapshot() -> Dictionary:
	var pops := {}
	var techs := {}
	var setl := {}
	for p in peoples:
		pops[p.id] = people_pop(int(p.id))
		techs[p.id] = p.techs.size()
		setl[p.id] = people_settlements(int(p.id)).size()
	var bel := {}
	for d in deities:
		bel[d.id] = believers_of(int(d.id))
	var wars := 0
	for k in relations:
		if relations[k].war:
			wars += 1
	return {"year": year, "pops": pops, "techs": techs, "settlements": setl, "believers": bel, "wars": wars,
		"log_index": chronicle.size(), "energy": deities[player_deity].energy if deities.size() > 0 else 0.0,
		"births": stats_births.duplicate(true)}

# ------------------------------------------------------------------ Sérialisation

func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "name": world_name, "seed": world_seed, "year": year,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"planet": planet.to_dict(), "peoples": peoples, "settlements": settlements, "religions": religions,
		"deities": deities, "relations": relations, "pending": pending, "log": chronicle,
		"birth_counter": birth_counter, "stats_births": stats_births, "affinity_history": affinity_history,
		"player_deity": player_deity, "tutorial": tutorial, "series": series, "climate": climate,
		"offline_consumed_until": offline_consumed_until, "last_saved_unix": last_saved_unix}

func from_dict(d: Dictionary) -> void:
	world_name = d.get("name", "Monde")
	world_seed = int(d.seed)
	year = int(d.year)
	planet = Planet.new()
	planet.from_dict(d.planet)
	peoples = d.peoples
	settlements = d.settlements
	religions = d.religions
	deities = d.deities
	relations = d.relations
	pending = d.pending
	chronicle = d.log
	birth_counter = int(d.birth_counter)
	stats_births = d.stats_births
	affinity_history = d.affinity_history
	player_deity = int(d.player_deity)
	tutorial = d.get("tutorial", {"step": 0, "done": []})
	series = d.get("series", History.empty())
	climate = d.get("climate", Climate.none())
	for k in ["until", "since"]:
		if climate.has(k):
			climate[k] = int(climate[k])
	offline_consumed_until = int(d.get("offline_consumed_until", 0))
	last_saved_unix = int(d.get("last_saved_unix", 0))
	rng.seed = int(d.rng_seed)
	rng.state = int(d.rng_state)
	_normalize_numbers()
	owner.resize(planet.cell_count)
	owner.fill(-1)
	for s in settlements:
		if s.alive:
			for c in s.territory:
				owner[int(c)] = int(s.id)

## JSON ne distingue pas entiers et flottants : on retype les champs utilisés comme index.
func _normalize_numbers() -> void:
	for s in settlements:
		if not s.has("aff_src"):
			s["aff_src"] = Affinity.empty_sources()
		s["prev_pop"] = float(s.get("prev_pop", s.pop))
		if not s.has("species"):
			s["species"] = peoples[int(s.people)].species
		for k in ["id", "people", "cell", "founded", "last_gen", "last_help"]:
			s[k] = int(s[k])
		s.territory = s.territory.map(func(c): return int(c))
		_int_births(s.births)
	for p in peoples:
		for k in ["id", "deity", "religion", "origin_cell", "era", "founded", "parent"]:
			p[k] = int(p[k])
	for r in religions:
		for k in ["id", "deity", "founder_people"]:
			r[k] = int(r[k])
	for d in deities:
		for k in ["id", "xp", "level", "powers_used", "affinities_granted", "next_rule_id"]:
			d[k] = int(d[k])
		for r in d.rules:
			for k in ["id", "priority", "max_per_year", "used_this_year", "total", "blocked_budget"]:
				r[k] = int(r.get(k, 0))
		for o in d.manual_orders:
			o.settlement = int(o.settlement)
			o.remaining = int(o.remaining)
	_int_births(stats_births)
	for e in pending:
		e.due = int(e.due)
		e.deity = int(e.deity)
		e.cells = e.cells.map(func(c): return int(c))

static func _int_births(b: Dictionary) -> void:
	for k in ["divine_slots", "divine_none", "natural_slots"]:
		b[k] = int(b[k])
	for sub in ["divine", "natural", "late"]:
		for a in b[sub]:
			b[sub][a] = int(b[sub][a])
