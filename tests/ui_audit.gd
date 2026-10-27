extends SceneTree
## Audit de l'interface à un format d'écran donné (lancer une fois par format) :
##   xvfb-run godot --path . --rendering-method gl_compatibility --resolution 1600x720 -s tests/ui_audit.gd -- <dossier>
## Pour chaque écran : tout bouton, case ou champ visible hors d'une liste défilante doit être entièrement à l'écran.
## Vérifie aussi, avec de vrais événements d'entrée : défilement au glisser, case cochée au toucher, création du peuple.
var main
var out := "user://"
var failures := 0
var checks := 0
var tag := ""

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
	print(("  ✔ " if cond else "  ✘ ") + msg)

func _shot(name: String) -> void:
	await _frames(4)
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, tag, name])

## Les positions sont données en coordonnées d'interface ; l'événement d'entrée est en coordonnées de fenêtre
## (différentes quand l'interface est mise à l'échelle, par exemple en 4:3).
func _win(p: Vector2) -> Vector2:
	return root.get_final_transform() * p

func _mouse(p0: Vector2, pressed: bool) -> void:
	var p := _win(p0)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = p
	e.global_position = p
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)

func _tap(p: Vector2) -> void:
	_mouse(p, true)
	await _frames(1)
	_mouse(p, false)
	await _frames(4)

func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(from, true)
	await _frames(1)
	for i in 12:
		var m := InputEventMouseMotion.new()
		var p := _win(from.lerp(to, (i + 1) / 12.0))
		m.position = p
		m.global_position = p
		m.relative = (_win(to) - _win(from)) / 12.0
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		await _frames(1)
	_mouse(to, false)
	await _frames(4)

func _in_scroll(c: Control) -> ScrollContainer:
	var n := c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null

## Contrôles interactifs visibles qui dépassent de l'écran (hors listes défilantes, où le dépassement est voulu).
func _audit(screen: String, under: Node) -> void:
	await _frames(4)
	var vis := root.get_viewport().get_visible_rect()
	var bad := []
	for c in under.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not (ctl is BaseButton or ctl is LineEdit or ctl is SpinBox or ctl is Slider) or not ctl.is_visible_in_tree():
			continue
		var r := ctl.get_global_rect()
		var sc := _in_scroll(ctl)
		if sc != null:
			# Dans une liste : la liste elle-même doit être à l'écran.
			r = sc.get_global_rect()
		if not vis.grow(1.0).encloses(r) or r.size.x < 1.0 or r.size.y < 1.0:
			bad.append("%s %s %s" % [ctl.get_class(), str(ctl.get("text")).left(30), r])
	check(bad.is_empty(), "%s : tous les éléments interactifs à l'écran%s" % [screen, "" if bad.is_empty() else " — hors écran : " + "; ".join(bad.slice(0, 4))])
	await _shot(screen)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var vs := root.get_viewport().get_visible_rect().size
	tag = "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	print("Format %s (interface %dx%d)" % [tag, vs.x, vs.y])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	await _audit("menu_principal", main.ui)

	# Création du peuple.
	main.new_world("777")
	await _frames(4)
	var fs = main.founder_screen
	await _audit("creation_peuple", fs)
	var scrolls: Array = fs.find_children("*", "ScrollContainer", true, false).filter(func(s): return s.is_visible_in_tree() and s.get_v_scroll_bar().max_value > s.size.y + 4)
	check(scrolls.size() > 0, "création : la liste des traits dépasse l'écran et défile")
	var trait_scroll: ScrollContainer = null
	for s in scrolls:
		if s.find_children("*", "CheckBox", true, false).size() > 0:
			trait_scroll = s
	if trait_scroll != null:
		var r := trait_scroll.get_global_rect()
		var before := trait_scroll.scroll_vertical
		var boxes: Array = trait_scroll.find_children("*", "CheckBox", true, false)
		var states := boxes.map(func(b): return b.button_pressed)
		await _drag(r.get_center() + Vector2(0, r.size.y * 0.3), r.get_center() - Vector2(0, r.size.y * 0.3))
		await _frames(20)
		check(trait_scroll.scroll_vertical > before + 50, "création : glisser le doigt sur les traits fait défiler (%d → %d px)" % [before, trait_scroll.scroll_vertical])
		check(boxes.map(func(b): return b.button_pressed) == states, "création : le glisser ne coche ni ne décoche aucun trait")
		var target: CheckBox = null
		for b in boxes:
			if r.encloses(b.get_global_rect()) and not b.button_pressed and not b.disabled:
				target = b
				break
		if target != null:
			await _tap(target.get_global_rect().get_center())
			check(target.button_pressed, "création : toucher un trait le coche")
			await _tap(target.get_global_rect().get_center())
			check(not target.button_pressed, "création : toucher à nouveau le décoche")
	var species_scroll: ScrollContainer = null
	for s in fs.find_children("*", "ScrollContainer", true, false):
		if s.find_children("*", "CheckBox", true, false).is_empty() and s.is_visible_in_tree():
			species_scroll = s
	if species_scroll != null:
		var sb: Array = species_scroll.find_children("*", "Button", true, false)
		var last: Button = sb[sb.size() - 1]
		species_scroll.ensure_control_visible(last)
		await _frames(3)
		await _tap(last.get_global_rect().get_center())
		check(fs.species_id == main.cat.species_order[main.cat.species_order.size() - 1], "création : la dernière espèce se choisit au toucher (%s)" % fs.species_id)
	var ok: Button = null
	for b in fs.find_children("*", "Button", true, false):
		if str(b.text).begins_with("Créer"):
			ok = b
	check(ok != null and root.get_viewport().get_visible_rect().encloses(ok.get_global_rect()), "création : le bouton « Créer le peuple » est entièrement visible")
	if ok != null:
		await _tap(ok.get_global_rect().get_center())
		await _frames(10)
	check(main.state == "play" and main.founder_screen == null, "création : « Créer le peuple » lance la partie")

	# Jeu : barre du haut, rail, tiroir des pouvoirs, panneaux et fenêtres.
	main.tutorial_skip()
	main.set_speed(0)
	await _frames(5)
	await _audit("jeu", main.ui)
	if not main.ui.drawer.visible:
		main.ui._toggle_drawer()
	await _frames(20)
	await _audit("tiroir_pouvoirs", main.ui)
	var fam_scroll: ScrollContainer = main.ui.family_scroll
	var h0 := fam_scroll.scroll_horizontal
	var fr := fam_scroll.get_global_rect()
	await _drag(fr.get_center() + Vector2(fr.size.x * 0.3, 0), fr.get_center() - Vector2(fr.size.x * 0.3, 0))
	await _frames(20)
	check(fam_scroll.scroll_horizontal > h0 or fam_scroll.get_h_scroll_bar().max_value <= fam_scroll.size.x + 2, "tiroir : glisser fait défiler les catégories (%d → %d)" % [h0, fam_scroll.scroll_horizontal])
	var s: Dictionary = main.world.people_settlements(0)[0]
	main.ui.show_cell(int(s.cell))
	await _audit("fiche_village", main.ui)
	main.ui.info_panel.visible = false
	for item in [["menu_jeu", main.ui.show_game_menu], ["peuples", main.ui.show_peoples], ["regles_affinites", main.ui.show_affinity_rules],
			["dieu", main.ui.show_deity.bind(main.world.player_deity)], ["cartes", main.ui.show_overlays], ["fiche_peuple", main.ui.show_people.bind(0)]]:
		item[1].call()
		await _audit(item[0], main.ui)
		# Défilement des fenêtres longues au doigt.
		var ms: Array = main.ui.modal.find_children("*", "ScrollContainer", true, false)
		if ms.size() > 0 and ms[0].get_v_scroll_bar().max_value > ms[0].size.y + 40:
			var mr: Rect2 = ms[0].get_global_rect()
			var v0: int = ms[0].scroll_vertical
			await _drag(mr.get_center() + Vector2(0, mr.size.y * 0.3), mr.get_center() - Vector2(0, mr.size.y * 0.3))
			await _frames(20)
			check(ms[0].scroll_vertical > v0, "%s : la fenêtre défile au doigt" % item[0])
		main.ui.close_modal()
	main.ui._toggle_log()
	await _audit("journal", main.ui)
	main.ui._toggle_log()
	# Touche « retour » d'Android.
	main.ui.show_peoples()
	check(main.handle_back() == "fenetre_fermee" and main.ui.modal == null, "retour : ferme la fenêtre ouverte")
	main.ui.info_panel.visible = false
	if main.ui.drawer.visible:
		check(main.handle_back() == "tiroir_ferme", "retour : ferme le tiroir des pouvoirs")
	check(main.handle_back() == "menu_ouvert" and main.ui.modal != null, "retour en jeu : ouvre le menu (ne quitte pas)")
	main.ui.close_modal()
	print("Format %s : %d vérifications, %d échecs" % [tag, checks, failures])
	quit(1 if failures > 0 else 0)
