extends SceneTree
## Captures de la vie du monde (routes, port, bateaux, convoi, habitants, repères d'époque).
## xvfb-run godot --path . --rendering-method gl_compatibility -s tests/life_shots.gd -- <dossier>
var main

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.new_world("4242")
	await _frames(2)
	main.founder_screen._confirm()
	await _frames(3)
	main.tutorial_skip()
	main.set_speed(0)
	main.world.run_years(450)
	main.view.refresh(true)
	main.ui.close_modal()
	main.ui.info_panel.visible = false
	var w = main.world
	# Village côtier d'un peuple navigateur, le plus peuplé.
	var best: Dictionary = {}
	for s in w.alive_settlements():
		if w.planet.is_coastal(int(s.cell)) and w.peoples[int(s.people)].techs.has("navigation"):
			if best.is_empty() or float(s.pop) > float(best.pop):
				best = s
	if best.is_empty():
		best = w.alive_settlements()[0]
	print("village : ", best.name, " ", int(best.pop), " hab. époque ", int(w.peoples[int(best.people)].era), " voie ", float(w.peoples[int(best.people)].lean))
	main.rig.focus_on(w.planet.pos[int(best.cell)], 1.9)
	await _frames(40)
	main.view.life.rebuild()
	await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/vie_region.png")
	print("bateaux ", main.view.life.boat_count(), " route ", main.view.life._road_node.mesh != null, " lod ", main.view.lod)
	var ds := []
	for o in w.people_settlements(int(best.people)):
		ds.append(snappedf(w.planet.pos[int(best.cell)].distance_to(w.planet.pos[int(o.cell)]), 0.001))
	ds.sort()
	print("distances voisins ", ds.slice(0, 5))
	main.rig.focus_on(w.planet.pos[int(best.cell)], 1.4)
	await _frames(40)
	# Convoi de démonstration vers un voisin du même peuple.
	var others: Array = w.people_settlements(int(best.people))
	for o in others:
		if int(o.id) != int(best.id):
			main.view.life._spawn_convoy(best, o)
			break
	await create_timer(1.2).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/vie_village.png")
	print("habitants ", main.view.life.walker_count(), " convois ", main.view.life.convoy_count())
	await create_timer(5.0).timeout
	print("convois après arrivée ", main.view.life.convoy_count())
	quit()
