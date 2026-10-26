extends SceneTree
## Démonstration vérifiable pilotée par de vrais événements d'entrée (souris, toucher, clics d'interface).
##   xvfb-run godot --path . --rendering-method gl_compatibility -s tests/interaction_demo.gd -- <dossier captures>
## Code de sortie 0 si toutes les vérifications passent.

var main
var out := "user://"
var passed := 0
var failed := 0
var report: Array = []

func _init() -> void:
	_run.call_deferred()

func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		report.append("  ✔ " + msg)
	else:
		failed += 1
		report.append("  ✘ " + msg)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _shot(name: String) -> void:
	await _frames(5)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	report.append("  [capture] %s.png" % name)

# ---- Entrées réelles

func _mouse_button(pos: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)

func _click(pos: Vector2) -> void:
	_mouse_button(pos, true)
	await _frames(1)
	_mouse_button(pos, false)
	await _frames(2)

func _drag_mouse(from: Vector2, to: Vector2) -> void:
	_mouse_button(from, true)
	await _frames(1)
	for i in 10:
		var m := InputEventMouseMotion.new()
		var p := from.lerp(to, (i + 1) / 10.0)
		m.position = p
		m.global_position = p
		m.relative = (to - from) / 10.0
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		await _frames(1)
	_mouse_button(to, false)
	await _frames(2)

func _drag_touch(from: Vector2, to: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = from
	t.pressed = true
	Input.parse_input_event(t)
	await _frames(1)
	for i in 10:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = from.lerp(to, (i + 1) / 10.0)
		d.relative = (to - from) / 10.0
		Input.parse_input_event(d)
		await _frames(1)
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = to
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(2)

func _click_control(c: Control) -> void:
	await _click(c.get_global_rect().get_center())

func _screen_of_cell(cell: int) -> Vector2:
	var dir: Vector3 = main.world.planet.pos[cell]
	return main.rig.camera.unproject_position(dir * main.view.surface_radius(dir, cell))

func _button_with_meta(parent: Node, key: String, value: String) -> Button:
	for b in parent.get_children():
		if b is Button and str(b.get_meta(key, "")) == value:
			return b
	return null

# ---- Démonstration

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.new_world("4242")
	await _frames(2)
	main.founder_screen._confirm()
	await _frames(3)
	var w = main.world
	var center := Vector2(get_root().get_visible_rect().size) * Vector2(0.4, 0.55)

	report.append("1. Tutoriel")
	check(main.tutorial_active() and main.speed == 0, "le temps est en pause au début du tutoriel")
	var y0: int = w.year
	await _wait(1.2)
	check(w.year == y0, "aucune année ne passe pendant l'apprentissage (an %d)" % w.year)
	await _shot("demo_01_tutoriel_debut")
	await _drag_mouse(center, center + Vector2(160, 40))
	await _wait(0.35)
	check(0 in w.tutorial.done, "glisser à la souris valide l'étape « tourner la planète »")
	var d0: float = main.rig.distance
	_mouse_button(center, true, MOUSE_BUTTON_WHEEL_UP)
	await _frames(2)
	check(main.rig.distance < d0, "la molette zoome (distance %.2f → %.2f)" % [d0, main.rig.distance])
	main.tutorial_restart()
	await _drag_touch(center, center + Vector2(-140, 30))
	await _wait(0.35)
	check(0 in w.tutorial.done, "glisser au doigt valide la même étape")
	main.tutorial_skip()
	check(not main.tutorial_active() and main.speed == 1, "« Passer » termine le tutoriel et relance le temps")
	main.tutorial_restart()
	check(main.tutorial_active() and main.speed == 0, "« Revoir le tutoriel » le relance, temps en pause")
	await _drag_mouse(center, center + Vector2(60, 0))
	await _wait(0.35)

	report.append("2. Village sélectionné et sa fiche")
	var s: Dictionary = w.people_settlements(0)[0]
	main.rig.focus_on(w.planet.pos[int(s.cell)], 1.5)
	main.update_lod()
	main.view.refresh()
	await _frames(3)
	await _click(_screen_of_cell(int(s.cell)))
	await _wait(0.35)
	var info: String = main.ui.info_text.text
	check(main.ui.info_panel.visible, "toucher le village ouvre sa fiche")
	for key in [s.name, w.peoples[0].name, "Population", "Divinité", "Religion dominante", "Ressources", "Besoins", "Développement", "Activité", "Problèmes"]:
		check(info.find(str(key)) >= 0, "la fiche contient « %s »" % key)
	check(1 in w.tutorial.done, "l'étape « toucher un village » est validée")
	main.view.set_names(true)
	main.view.set_borders(true)
	await _shot("demo_02_fiche_village_noms_frontieres")

	report.append("3. Activité autonome")
	var n_setl: int = w.people_settlements(0).size()
	var techs0: int = w.peoples[0].techs.size()
	var log0: int = w.chronicle.size()
	main.ui.show_cell(-1)
	main.ui.info_panel.visible = false
	var years := 0
	while years < 200 and w.people_settlements(0).size() == n_setl:
		w.tick()
		years += 1
	var auto_events := []
	for i in range(log0, w.chronicle.size()):
		if w.chronicle[i].kind in ["settlement", "tech"] and str(w.chronicle[i].txt).begins_with(str(w.peoples[0].name)):
			auto_events.append("an %d : %s — %s" % [int(w.chronicle[i].y), w.chronicle[i].txt, w.chronicle[i].why])
	check(w.people_settlements(0).size() > n_setl, "le peuple du joueur fonde seul un nouveau village en %d ans (%d → %d)" % [years, n_setl, w.people_settlements(0).size()])
	report.append("     " + (auto_events[0] if auto_events.size() > 0 else "aucun événement"))
	main.view.refresh()
	main.ui._toggle_log()
	await _shot("demo_03_activite_autonome_journal")
	main.ui._toggle_log()

	report.append("4. Naissances et attribution")
	var d: Dictionary = w.deities[w.player_deity]
	d.rules[0].conditions = [{"field": "own_people"}]
	d.rules[0].enabled = true
	d.rules[0].result = "sword"
	d.rules[0].name = "Gardiens du peuple"
	d.energy = float(d.max_energy)
	var st0: Dictionary = w.stats_births.duplicate(true)
	var h0: int = w.affinity_history.size()
	for i in 6:
		w.tick()
	var div: int = w.stats_births.divine_slots - st0.divine_slots
	var nat: int = w.stats_births.natural_slots - st0.natural_slots
	check(div > 0 and absi(div - 2 * nat) <= 2, "2/3 ouvertes au divin, 1/3 naturelles (%d / %d)" % [div, nat])
	check(not w.stats_births.natural.has("both"), "aucune double affinité naturelle")
	var rule_entry := {}
	for i in range(h0, w.affinity_history.size()):
		if str(w.affinity_history[i].source).begins_with("rule:") and int(w.affinity_history[i].deity) == int(w.player_deity):
			rule_entry = w.affinity_history[i]
	check(not rule_entry.is_empty(), "une naissance a reçu l'affinité par la règle : %s" % (str(rule_entry.get("reason", "")) if not rule_entry.is_empty() else "-"))
	var dn: int = w.stats_births.divine_none - st0.divine_none
	report.append("     naissances divines sans attribution (budget, autres dieux, non-croyants) : %d → sans affinité" % dn)
	var s2: Dictionary = w.people_settlements(0)[0]
	main.ui.show_individuals(int(s2.id))
	await _frames(2)
	var found_origin := false
	for c in main.ui.modal.find_children("*", "RichTextLabel", true, false):
		if (c as RichTextLabel).text.find("Origine de l'affinité") >= 0 or (c as RichTextLabel).text.find("Origine des affinités") >= 0:
			found_origin = true
	check(found_origin, "la fiche des habitants indique l'origine des affinités")
	await _shot("demo_04_habitants_affinites")
	main.ui.close_modal()

	report.append("5. Pouvoir : catégorie → pouvoir → cible → confirmation → effet")
	if not main.ui.drawer.visible:
		await _click_control(main.ui.rail_buttons.powers)
	for fam in w.cat.power_families:
		var fb: Button = _button_with_meta(main.ui.family_bar, "family", fam)
		main.ui.family_scroll.ensure_control_visible(fb)
		await _frames(2)
		await _click_control(fb)
		await _frames(2)
		var shown := []
		for b in main.ui.power_bar.get_children():
			if b is Button and b.has_meta("power"):
				shown.append(str(b.get_meta("power")))
		var expected := []
		for pid in w.cat.power_order:
			if w.cat.powers[pid].family == fam:
				expected.append(pid)
		check(shown == expected and fb.button_pressed, "catégorie « %s » : affiche ses %d pouvoir(s) et apparaît sélectionnée" % [fam, expected.size()])
	var fb2: Button = _button_with_meta(main.ui.family_bar, "family", "catastrophe")
	main.ui.family_scroll.ensure_control_visible(fb2)
	await _frames(2)
	await _click_control(fb2)
	await _click_control(_button_with_meta(main.ui.power_bar, "power", "seisme"))
	check(main.ui.confirm_bar.visible and main.ui.confirm_label.text.find("Verrouillé") >= 0, "un pouvoir verrouillé explique pourquoi")
	await _shot("demo_05_pouvoir_verrouille")
	var fb3: Button = _button_with_meta(main.ui.family_bar, "family", "sign")
	main.ui.family_scroll.ensure_control_visible(fb3)
	await _frames(2)
	await _click_control(fb3)
	await _click_control(_button_with_meta(main.ui.power_bar, "power", "signe"))
	check(main._power == "signe", "le pouvoir est sélectionné (ciblage)")
	var target: Dictionary = w.people_settlements(0)[0]
	main.rig.focus_on(w.planet.pos[int(target.cell)], 1.5)
	main.update_lod()
	await _frames(3)
	await _click(_screen_of_cell(int(target.cell)))
	await _frames(2)
	check(main._preview_cell >= 0 and not main.ui.confirm_ok.disabled, "toucher la planète prévisualise la zone et le coût")
	await _shot("demo_06_previsualisation")
	var e0 := float(d.energy)
	var fer0 := float(target.fervor)
	await _click_control(main.ui.confirm_ok)
	var e1 := float(d.energy)
	check(is_equal_approx(e0 - e1, float(w.cat.powers.signe.cost)), "coût débité : %.1f → %.1f" % [e0, e1])
	await _click_control(main.ui.confirm_ok)
	check(is_equal_approx(float(d.energy), e1), "une seconde validation ne débite rien")
	check(float(target.fervor) > fer0, "effet réel : ferveur de %s %.0f → %.0f %%" % [target.name, fer0 * 100.0, float(target.fervor) * 100.0])
	check(main.ui.toast != null and main.ui.toast.visible, "retour visuel affiché : « %s »" % main.ui.toast_label.text.replace("\n", " / "))
	await _shot("demo_07_effet_pouvoir")

	report.append("6. Sauvegarde et rechargement")
	var id: String = main.world_id
	var snap := {"year": w.year, "fervor": float(target.fervor), "energy": float(d.energy), "setl": w.alive_settlements().size(),
		"hist": w.affinity_history.size(), "births": JSON.stringify(w.stats_births), "rule": d.rules[0].enabled}
	main.save_now()
	main.back_to_menu()
	await _frames(3)
	main.continue_world(id)
	await _frames(5)
	var w2 = main.world
	var t2: Dictionary = w2.settlements[int(target.id)]
	var d2: Dictionary = w2.deities[w2.player_deity]
	check(w2.year == snap.year and w2.alive_settlements().size() == snap.setl, "année et villages conservés (an %d, %d villages)" % [w2.year, snap.setl])
	check(is_equal_approx(float(t2.fervor), snap.fervor), "effet du pouvoir conservé (ferveur %.0f %%)" % (float(t2.fervor) * 100.0))
	check(absf(float(d2.energy) - snap.energy) < 0.001, "énergie conservée (%.1f)" % float(d2.energy))
	check(JSON.stringify(w2.stats_births) == snap.births and w2.affinity_history.size() == snap.hist, "naissances et historique des attributions conservés")
	check(d2.rules[0].enabled == snap.rule, "règle d'attribution conservée")
	main.focus_settlement(int(target.id))
	await _shot("demo_08_apres_rechargement")
	main.delete_world(id)

	print("\n".join(report))
	print("\n%d vérifications réussies, %d échecs" % [passed, failed])
	quit(1 if failed > 0 else 0)
