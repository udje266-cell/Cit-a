extends SceneTree
## Captures d'écran (nécessite un affichage, ex. xvfb-run) :
##   xvfb-run godot --path . --rendering-method gl_compatibility -s tests/screenshot.gd -- <dossier>

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(path: String) -> void:
	await _frames(4)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _shot(out + "/0_menu.png")
	main.new_world("4242")
	await _shot(out + "/1_fondateurs.png")
	main.founder_screen._randomize()
	main.founder_screen._confirm()
	for i in 220:
		main.world.tick()
	main.view.refresh(true)
	var s: Dictionary = main.world.people_settlements(0)[0]
	main.rig.focus_on(main.world.planet.pos[int(s.cell)], 3.0)
	await _shot(out + "/2_planete.png")
	main.set_overlay("peoples")
	main.ui.show_cell(int(s.cell))
	await _shot(out + "/3_peuples_fiche.png")
	main.ui.show_cell(-1)
	main.set_overlay("terrain")
	main.rig.focus_on(main.world.planet.pos[int(s.cell)], 1.45)
	main.select_power("pluie")
	main.preview_at(int(s.cell))
	await _shot(out + "/4_zoom_previsualisation.png")
	main.cancel_power()
	main.rig.focus_on(main.world.planet.pos[int(s.cell)], 1.9)
	main.update_lod()
	main.set_overlay("grid")
	await _shot(out + "/6_grille_consultation.png")
	main.set_overlay("terrain")
	main.ui.show_affinity_rules()
	await _shot(out + "/5_regles_affinites.png")
	quit()
