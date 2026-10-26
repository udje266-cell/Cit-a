extends SceneTree
## Captures d'une région de référence (côte + forêt + montagne + village) à trois distances.
##   xvfb-run godot --path . --rendering-method gl_compatibility -s tests/region_shots.gd -- <dossier> [préfixe]

const DISTANCES := {"loin": 3.2, "moyen": 1.9, "pres": 1.3}

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(path: String) -> void:
	await _frames(6)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)

## Établissement dont les environs contiennent côte, forêt et montagne.
func _pick_region(w) -> int:
	var best := -1
	var best_score := -1.0
	for s in w.alive_settlements():
		var cells: Array = w.planet.cells_within(int(s.cell), 4, 120)
		var coast := 0.0
		var forest := 0.0
		var mount := 0.0
		for c in cells:
			var b: String = w.planet.biome_name(c)
			if w.planet.is_coastal(c): coast = 1.0
			if b in ["temperate_forest", "taiga", "rainforest"]: forest = 1.0
			if b in ["mountain", "snow_peak"]: mount = 1.0
		var score := coast + forest + mount + float(s.pop) / 1000.0
		if score > best_score:
			best_score = score
			best = int(s.cell)
	return best

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var prefix: String = args[1] if args.size() > 1 else ""
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(2)
	main.new_world("4242")
	await _frames(2)
	main.founder_screen._confirm()
	for i in 220:
		main.world.tick()
	main.view.refresh(true)
	var cell := _pick_region(main.world)
	print("région : cellule ", cell, " biome ", main.world.planet.biome_name(cell))
	for k in DISTANCES:
		main.rig.focus_on(main.world.planet.pos[cell], DISTANCES[k])
		if main.has_method("update_lod"):
			main.update_lod()
		main.view.refresh()
		await _shot("%s/%s%s.png" % [out, prefix, k])
	quit()
