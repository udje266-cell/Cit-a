extends SceneTree
## Tests de la simulation, sans interface :
##   godot --headless --path . -s tests/run_tests.gd
## Code de sortie 0 = tout passe, 1 = au moins un échec.

const Catalog = preload("res://sim/catalog.gd")
const World = preload("res://sim/world.gd")
const Genetics = preload("res://sim/genetics.gd")
const Affinity = preload("res://sim/affinity.gd")
const Powers = preload("res://sim/powers.gd")
const Faith = preload("res://sim/faith_system.gd")
const SaveSystem = preload("res://sim/save_system.gd")

var passed := 0
var failed := 0
var cat

func _init() -> void:
	cat = Catalog.shared()
	var tests := [
		"test_catalogs", "test_planet_determinism", "test_planet_structure",
		"test_inheritance", "test_selection", "test_mutation", "test_incompat",
		"test_birth_split", "test_natural_never_both", "test_natural_distribution",
		"test_no_divine_attribution", "test_rule_attribution", "test_parents_both_not_inherited",
		"test_genetics_never_touch_affinity", "test_late_grant", "test_manual_orders", "test_budget_limit",
		"test_reload_no_reroll", "test_growth_bounded", "test_powers", "test_delayed_effect",
		"test_conversion", "test_weak_deity_return", "test_save_roundtrip", "test_save_files",
		"test_migration_v0", "test_export_import", "test_offline", "test_benchmark",
	]
	for t in tests:
		var before := failed
		call(t)
		print(("  ok   " if failed == before else "  FAIL ") + t)
	print("\n%d assertions réussies, %d échecs" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("    échec : " + msg)

func make_world(seed_value: int = 1234) -> Object:
	var w = World.new(cat)
	w.create_planet(seed_value, 3)
	w.create_player_people("terragne", "Peuple test",
		[{"name": "A", "traits": ["endurant", "curieux"]}, {"name": "B", "traits": ["endurant", "pieux"]}], {"name": "Dieu test"})
	w.create_rivals(2)
	return w

# ------------------------------------------------------------------ Catalogues & planète

func test_catalogs() -> void:
	check(cat.errors.is_empty(), "catalogues sans erreur : %s" % str(cat.errors))
	check(cat.traits.size() >= 100, "au moins 100 traits (%d)" % cat.traits.size())
	check(cat.species.size() >= 6, "6 espèces")
	for id in cat.traits:
		check(not cat.traits[id].fx.is_empty(), "le trait %s a un effet mécanique" % id)
		check(cat.traits[id].kind in ["heritable", "acquired"], "type de trait valide %s" % id)
	check(not cat.traits.has("both") and not cat.traits.has("magic") and not cat.traits.has("sword"), "les affinités ne sont pas des traits")

func test_planet_determinism() -> void:
	var a = World.new(cat); a.create_planet(42, 3)
	var b = World.new(cat); b.create_planet(42, 3)
	var c = World.new(cat); c.create_planet(43, 3)
	check(a.planet.height == b.planet.height, "même graine → même relief")
	check(a.planet.biome == b.planet.biome, "même graine → mêmes biomes")
	check(a.planet.height != c.planet.height, "graine différente → relief différent")

func test_planet_structure() -> void:
	var w = World.new(cat); w.create_planet(7, 4)
	var pl = w.planet
	check(pl.cell_count == 2562, "niveau 4 = 2562 cellules (%d)" % pl.cell_count)
	var land := 0
	var kinds := {}
	for i in pl.cell_count:
		if pl.is_land(i):
			land += 1
		kinds[pl.biome_name(i)] = true
		for nb in pl.neighbors[i]:
			if not i in pl.neighbors[nb]:
				check(false, "voisinage symétrique %d-%d" % [i, nb])
				return
	var frac: float = float(land) / pl.cell_count
	check(frac > 0.25 and frac < 0.5, "part de terres plausible (%.2f)" % frac)
	check(kinds.has("ocean"), "océans présents")
	check(kinds.size() >= 6, "au moins 6 biomes (%d)" % kinds.size())

# ------------------------------------------------------------------ Génétique

func test_inheritance() -> void:
	var f := Genetics.founders_to_freqs([["endurant", "curieux"], ["endurant", "pieux"]])
	check(is_equal_approx(f.endurant, 1.0), "trait des deux parents → 100 %")
	check(is_equal_approx(f.curieux, 0.5), "trait d'un parent → 50 %")
	check(not f.has("fecond"), "trait absent des parents → absent")

func test_selection() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var freqs := {"resistant_froid": 0.3, "craint_chaleur": 0.3}
	var env := {"cold": 0.8, "heat": 0.0}
	for i in 40:
		Genetics.generation_step(cat, freqs, env, 5000.0, rng)
	check(float(freqs.get("resistant_froid", 0.0)) > 0.6, "le froid sélectionne la résistance au froid (%.2f)" % float(freqs.get("resistant_froid", 0.0)))

func test_mutation() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var freqs := {}
	var mutations := 0
	for i in 300:
		for e in Genetics.generation_step(cat, freqs, {}, 400.0, rng):
			if e.type == "mutation":
				mutations += 1
				check(cat.traits[e.trait].kind == "heritable", "une mutation ne produit qu'un trait héréditaire")
	check(mutations > 5, "des mutations apparaissent (%d)" % mutations)

func test_incompat() -> void:
	var freqs := {"pelage_epais": 0.8, "peau_fine": 0.7}
	Genetics.enforce_incompat(cat, freqs)
	check(float(freqs.pelage_epais) + float(freqs.peau_fine) <= 1.0001, "traits incompatibles : somme ≤ 1")

# ------------------------------------------------------------------ Affinités

func affinity_world() -> Object:
	var w = make_world()
	return w

func player_settlement(w) -> Dictionary:
	return w.people_settlements(0)[0]

func test_birth_split() -> void:
	var w = affinity_world()
	var s := player_settlement(w)
	var b0: int = w.stats_births.divine_slots
	var n0: int = w.stats_births.natural_slots
	w.birth_counter = 0
	Affinity.resolve_births(w, s, 3000)
	check(w.stats_births.divine_slots - b0 == 2000, "2/3 des naissances sont ouvertes au divin (%d)" % (w.stats_births.divine_slots - b0))
	check(w.stats_births.natural_slots - n0 == 1000, "1/3 des naissances sont naturelles (%d)" % (w.stats_births.natural_slots - n0))

func test_natural_never_both() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var cfg := {"natural_probabilities": {"none": 0.2, "magic": 0.3, "sword": 0.3, "both": 5.0}}
	var seen := {}
	for i in 50000:
		seen[Affinity.natural_draw(rng, cfg)] = true
	check(not seen.has("both"), "le hasard ne produit jamais 'both', même si la configuration le demande")
	check(seen.has("magic") and seen.has("sword") and seen.has("none"), "les trois résultats naturels existent")

func test_natural_distribution() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 4
	var cfg: Dictionary = cat.config.affinity
	var counts := {"none": 0, "magic": 0, "sword": 0}
	var n := 60000
	for i in n:
		counts[Affinity.natural_draw(rng, cfg)] += 1
	for k in counts:
		var expected := float(cfg.natural_probabilities[k])
		check(absf(counts[k] / float(n) - expected) < 0.01, "fréquence naturelle %s ≈ %.2f (%.3f)" % [k, expected, counts[k] / float(n)])

func test_no_divine_attribution() -> void:
	var w = affinity_world()
	for d in w.deities:
		d.rules = []
		d.manual_orders = []
	var s := player_settlement(w)
	s.aff = Affinity.empty_counts()
	w.birth_counter = 0
	var before: Dictionary = w.stats_births.duplicate(true)
	Affinity.resolve_births(w, s, 300)
	var dn: int = w.stats_births.divine_none - before.divine_none
	var dslots: int = w.stats_births.divine_slots - before.divine_slots
	check(dn == dslots and dslots == 200, "sans attribution, toutes les naissances divines donnent 'none' (%d/%d)" % [dn, dslots])
	var nat_aff: int = (w.stats_births.natural.magic - before.natural.magic) + (w.stats_births.natural.sword - before.natural.sword)
	check(is_equal_approx(float(s.aff.magic) + float(s.aff.sword), float(nat_aff)), "les seules affinités viennent des naissances naturelles (pas de tirage de remplacement)")
	check(float(s.aff.both) == 0.0, "aucune double affinité sans dieu")

func test_rule_attribution() -> void:
	var w = affinity_world()
	var d: Dictionary = w.deities[w.player_deity]
	d.rules = [Affinity.new_rule(0, "Tous élus", "both", [{"field": "always"}], 1, 1000)]
	d.auto_budget = 10000.0
	d.energy = 10000.0
	d.max_energy = 10000.0
	var s := player_settlement(w)
	s.faith = {str(w.peoples[0].religion): 1.0}
	s.aff = Affinity.empty_counts()
	w.birth_counter = 0
	var nat_before: Dictionary = w.stats_births.natural.duplicate()
	Affinity.resolve_births(w, s, 30)
	check(int(s.aff.both) == 20, "la règle confère 'both' aux 20 naissances divines (%d)" % int(s.aff.both))
	check(not w.stats_births.natural.has("both"), "les statistiques naturelles n'ont pas de catégorie 'both'")
	check(is_equal_approx(10000.0 - float(d.energy), 20 * Affinity.cost_of(w, "both", false)), "chaque attribution coûte de l'énergie")
	var explained := false
	for e in w.affinity_history:
		if str(e.source).begins_with("rule:") and str(e.reason).find("Tous élus") >= 0 and e.result == "both":
			explained = true
	check(explained, "l'attribution par règle est expliquée dans l'historique")
	check(int(d.rules[0].total) == 20, "statistiques de la règle")

func test_parents_both_not_inherited() -> void:
	var w = affinity_world()
	for d in w.deities:
		d.rules = []
	var s := player_settlement(w)
	s.aff = {"none": 0.0, "magic": 0.0, "sword": 0.0, "both": 500.0}
	s.pop = 500.0
	Affinity.resolve_births(w, s, 900)
	check(is_equal_approx(float(s.aff.both), 500.0), "des parents 'both' n'engendrent pas d'enfant 'both' sans dieu (%.0f)" % float(s.aff.both))

func test_genetics_never_touch_affinity() -> void:
	var w = affinity_world()
	for d in w.deities:
		d.rules = []
		d.manual_orders = []
	var s := player_settlement(w)
	s.aff = {"none": 100.0, "magic": 0.0, "sword": 0.0, "both": 0.0}
	var rng := RandomNumberGenerator.new(); rng.seed = 1
	for i in 50:
		Genetics.generation_step(cat, s.freqs, Genetics.environment_pressure(w.planet, int(s.cell), 1.0, true), 100.0, rng)
	check(s.aff == {"none": 100.0, "magic": 0.0, "sword": 0.0, "both": 0.0}, "mutations et milieu n'altèrent pas les affinités")
	# Un siècle de simulation complète sans aucune règle ni ordre : jamais de 'both'.
	w.deities[w.player_deity].manual_orders = []
	for d2 in w.deities:
		d2.rules = []
	for i in 100:
		w.tick()
		for d3 in w.deities:
			d3.rules = []
	var both := 0.0
	for st in w.alive_settlements():
		both += float(st.aff.both)
	check(both == 0.0, "aucune double affinité n'apparaît sans dieu en 100 ans (%.1f)" % both)

func test_late_grant() -> void:
	var w = affinity_world()
	var d: Dictionary = w.deities[w.player_deity]
	var s := player_settlement(w)
	s.aff = {"none": 10.0, "magic": 0.0, "sword": 0.0, "both": 0.0}
	d.energy = 0.0
	check(Affinity.grant_late(w, d, s, "magic", 3) == 0, "sans énergie, aucune affinité tardive")
	d.energy = 100.0
	var n := Affinity.grant_late(w, d, s, "magic", 3)
	check(n == 3 and is_equal_approx(float(s.aff.magic), 3.0) and is_equal_approx(float(s.aff.none), 7.0), "intervention tardive : 3 'none' deviennent 'magic'")
	check(is_equal_approx(100.0 - float(d.energy), 3 * Affinity.cost_of(w, "magic", true)), "coût tardif appliqué")
	var n2 := Affinity.grant_late(w, d, s, "both", 2)
	check(n2 == 2 and is_equal_approx(float(s.aff.both), 2.0), "le dieu peut conférer 'both' plus tard")
	check(Affinity.grant_late(w, d, s, "none", 1) == 0, "on ne peut pas 'attribuer' l'absence d'affinité")

func test_manual_orders() -> void:
	var w = affinity_world()
	var d: Dictionary = w.deities[w.player_deity]
	d.rules = []
	d.energy = 100.0
	var s := player_settlement(w)
	s.faith = {str(w.peoples[0].religion): 1.0}
	s.aff = Affinity.empty_counts()
	d.manual_orders = [{"settlement": int(s.id), "affinity": "sword", "remaining": 4}]
	w.birth_counter = 0
	Affinity.resolve_births(w, s, 30)
	check(int(s.aff.sword) >= 4, "l'ordre manuel produit 4 'sword' (%d)" % int(s.aff.sword))
	check(d.manual_orders.is_empty(), "l'ordre manuel est consommé")

func test_budget_limit() -> void:
	var w = affinity_world()
	var d: Dictionary = w.deities[w.player_deity]
	d.rules = [Affinity.new_rule(0, "Mages", "magic", [{"field": "always"}], 1, 100)]
	d.energy = 1000.0
	d.auto_budget = 1.25
	d.auto_spent = 0.0
	var s := player_settlement(w)
	s.faith = {str(w.peoples[0].religion): 1.0}
	s.aff = Affinity.empty_counts()
	w.birth_counter = 0
	Affinity.resolve_births(w, s, 60)
	check(int(d.rules[0].total) == 2, "le budget annuel limite les attributions automatiques (%d)" % int(d.rules[0].total))
	check(int(d.rules[0].blocked_budget) > 0, "les refus pour budget sont comptés")

func test_reload_no_reroll() -> void:
	var w = make_world(77)
	w.run_years(15)
	var saved := JSON.stringify(w.to_dict(), "", false, true)
	var births_at_save: Dictionary = w.stats_births.duplicate(true)
	var w2 = SaveSystem.world_from_dict(JSON.parse_string(saved))
	check(w2.stats_births.divine_slots == births_at_save.divine_slots and w2.birth_counter == w.birth_counter, "les naissances résolues sont conservées au rechargement")
	w.run_years(10)
	w2.run_years(10)
	check(JSON.stringify(w.stats_births) == JSON.stringify(w2.stats_births), "recharger ne retire pas les naissances (même suite exacte)")

func test_growth_bounded() -> void:
	var w = make_world(99)
	var over := {}
	for y in 260:
		w.tick()
		for s in w.alive_settlements():
			if float(s.pop) > float(s.capacity) * 1.5 + 5.0:
				over[int(s.id)] = int(over.get(int(s.id), 0)) + 1
			else:
				over.erase(int(s.id))
	var ok := true
	for id in over:
		if over[id] >= 10:
			ok = false
			printerr("    %s : dépassement depuis %d ans" % [w.settlements[id].name, over[id]])
	check(ok, "aucune population ne dépasse durablement la capacité du milieu")
	check(w.alive_settlements().size() > 3, "les peuples fondent des villages (%d)" % w.alive_settlements().size())

func test_powers() -> void:
	var w = make_world()
	var did: int = w.player_deity
	var d: Dictionary = w.deities[did]
	var s := player_settlement(w)
	d.energy = 50.0
	var pv := Powers.preview(w, did, "seisme", int(s.cell))
	check(not pv.ok and str(pv.reason).find("niveau") >= 0, "pouvoir verrouillé refusé")
	var h0: float = w.planet.height[int(s.cell)]
	var r := Powers.apply(w, did, "soulever", int(s.cell))
	check(r.ok, "pouvoir disponible utilisable")
	check(w.planet.height[int(s.cell)] > h0, "Soulever la terre modifie réellement le relief")
	check(is_equal_approx(float(d.energy), 50.0 - float(cat.powers.soulever.cost)), "coût déduit")
	d.energy = 1.0
	check(not Powers.apply(w, did, "signe", int(s.cell)).ok, "énergie insuffisante refusée")
	d.energy = 10.0
	check(Powers.preview(w, did, "pluie", int(s.cell)).cells.size() > 1, "la prévisualisation renvoie la zone")

func test_delayed_effect() -> void:
	var w = make_world()
	var did: int = w.player_deity
	var d: Dictionary = w.deities[did]
	var s := player_settlement(w)
	d.energy = 50.0
	var f0: float = w.planet.fert_offset[int(s.cell)]
	Powers.apply(w, did, "pluie", int(s.cell))
	check(w.pending.size() >= 1, "effet différé programmé")
	w.run_years(3)
	check(w.planet.fert_offset[int(s.cell)] > f0, "la fertilité augmente quelques années après la pluie")

func test_conversion() -> void:
	var w = make_world()
	var a := player_settlement(w)
	var b: Dictionary = w.people_settlements(1)[0]
	b.cell = w.planet.neighbors[int(a.cell)][0]
	b.faith = {str(w.peoples[1].religion): 1.0}
	b.fervor = 1.0
	b.pop = 400.0
	a.fervor = 0.1
	var share0 := float(a.faith.get(str(w.peoples[1].religion), 0.0))
	for i in 10:
		Faith._conversions(w, [a, b], cat.config.faith)
	var share1 := float(a.faith.get(str(w.peoples[1].religion), 0.0))
	check(share1 > share0 + 0.05, "une religion voisine fervente convertit (%.2f → %.2f)" % [share0, share1])

func test_weak_deity_return() -> void:
	var w = make_world()
	var did: int = w.player_deity
	var d: Dictionary = w.deities[did]
	var rel := str(w.peoples[0].religion)
	for s in w.alive_settlements():
		s.faith.erase(rel)
	d.energy = 0.0
	w.run_years(10)
	check(float(d.energy) > 0.0, "un dieu sans fidèles regagne un peu d'énergie (%.1f)" % float(d.energy))
	check(Powers.is_unlocked(w, d, "murmure"), "Murmure reste disponible")
	var s0 := player_settlement(w)
	d.energy = 10.0
	var r := Powers.apply(w, did, "murmure", int(s0.cell))
	check(r.ok and float(s0.faith.get(rel, 0.0)) > 0.0, "Murmure ramène des fidèles")

func test_save_roundtrip() -> void:
	var w = make_world(5)
	w.run_years(30)
	var d: Dictionary = w.to_dict()
	var w2 = SaveSystem.world_from_dict(JSON.parse_string(JSON.stringify(d, "", false, true)))
	check(w2 != null, "rechargement réussi")
	check(w2.year == w.year and w2.settlements.size() == w.settlements.size(), "année et établissements conservés")
	check(w2.planet.height == w.planet.height, "terrain et modifications conservés")
	check(JSON.stringify(w2.deities[0].rules) == JSON.stringify(w.deities[0].rules), "règles d'attribution conservées")
	w.run_years(5)
	w2.run_years(5)
	check(absf(w.people_pop(0) - w2.people_pop(0)) < 0.01, "la simulation reprend à l'identique")

func test_save_files() -> void:
	var w = make_world(6)
	w.run_years(5)
	var id := "test_world"
	check(SaveSystem.save_world(w, id), "sauvegarde fichier")
	var w2 = SaveSystem.load_world(id)
	check(w2 != null and w2.year == w.year, "chargement fichier")
	var found := false
	for m in SaveSystem.list_worlds():
		if m.id == id:
			found = true
	check(found, "monde listé")
	SaveSystem.delete_world(id)

func test_migration_v0() -> void:
	var w = make_world(8)
	w.run_years(3)
	var d: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict(), "", false, true))
	d.version = 0
	d.erase("birth_counter"); d.erase("stats_births"); d.erase("affinity_history")
	for s in d.settlements:
		s.erase("aff"); s.erase("mastery"); s.erase("births")
	for dd in d.deities:
		dd.erase("rules"); dd.erase("manual_orders")
	var w2 = SaveSystem.world_from_dict(d)
	check(w2 != null and int(w2.settlements[0].aff.none) >= 0, "une sauvegarde v0 est migrée")
	w2.run_years(3)
	check(w2.year == w.year + 3, "le monde migré continue")

func test_export_import() -> void:
	var w = make_world(11)
	w.run_years(5)
	var p1 := SaveSystem.export_world(w, "seed")
	var p2 := SaveSystem.export_world(w, "evolved")
	var a := SaveSystem.import_file(p1)
	var b := SaveSystem.import_file(p2)
	check(a.get("kind") == "seed" and a.world.peoples.is_empty(), "export « monde initial » sans peuples")
	check(a.world.planet.height == w.planet.height, "le monde initial conserve le terrain modifié")
	check(b.get("kind") == "evolved" and b.world.year == w.year, "export « monde évolué » complet")
	check(SaveSystem.import_file("user://inexistant.cworld").has("error"), "import invalide signalé")

func test_offline() -> void:
	var w = make_world(12)
	var now := 2_000_000_000
	w.last_saved_unix = now - 3600
	var r := SaveSystem.offline_years(w, now)
	check(r.years == 6, "1 h d'absence = 6 ans (%d)" % r.years)
	w.last_saved_unix = now - 100 * 3600
	r = SaveSystem.offline_years(w, now)
	check(r.capped and r.years == 48, "absence plafonnée à 8 h = 48 ans (%d)" % r.years)
	w.last_saved_unix = now + 5000
	r = SaveSystem.offline_years(w, now)
	check(r.clock_issue and r.years == 0, "horloge reculée : aucune progression")
	w.last_saved_unix = now - 3600
	SaveSystem.consume_offline(w, now)
	r = SaveSystem.offline_years(w, now)
	check(r.years == 0, "une absence déjà consommée n'est pas réappliquée")
	var before: Dictionary = w.snapshot()
	w.run_years(6)
	var lines := SaveSystem.summary(w, before, w.snapshot())
	check(lines.size() >= 3, "résumé d'absence produit")

func test_benchmark() -> void:
	var w = World.new(cat)
	w.create_planet(2024, 4)
	w.create_player_people("vivace", "Bench", [{"name": "A", "traits": ["fecond"]}, {"name": "B", "traits": ["curieux"]}], {"name": "B"})
	w.create_rivals(2)
	var t0 := Time.get_ticks_msec()
	w.run_years(200)
	var ms := Time.get_ticks_msec() - t0
	var t1 := Time.get_ticks_msec()
	w.run_years(50)
	var per_tick := (Time.get_ticks_msec() - t1) / 50.0
	print("    bench : 200 ans en %d ms ; %.2f ms/an à l'an 250 ; %d établissements ; mémoire statique %.1f Mo" % [ms, per_tick, w.alive_settlements().size(), OS.get_static_memory_usage() / 1048576.0])
	check(per_tick < 50.0, "tick < 50 ms sur PC (%.2f ms) — la cible mobile ≤ 4 ms reste à mesurer sur appareil" % per_tick)
