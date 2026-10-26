extends SceneTree
## Vitrine de la direction artistique : une région (baie, colline en terrasses, forêt, falaise, village)
## rendue dans le moteur, interface masquée, en vue globale, régionale et rapprochée.
##   xvfb-run godot --path . --rendering-method gl_compatibility -s tests/art_showcase.gd -- <dossier>

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(path: String) -> void:
	await _frames(6)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)

## Village dont les environs contiennent de l'eau (baie), du relief, de la forêt.
func _pick(w) -> int:
	var best := -1
	var best_score := -1.0
	for s in w.alive_settlements():
		var coast := 0.0
		var forest := 0.0
		var hill := 0.0
		for c in w.planet.cells_within(int(s.cell), 3, 60):
			var b: String = w.planet.biome_name(c)
			if w.planet.height[c] < 0.0: coast += 1.0
			if b in ["temperate_forest", "taiga", "rainforest"]: forest += 1.0
			if w.planet.height[c] > 0.3: hill += 1.0
		var score := minf(coast, 6.0) + minf(forest, 6.0) + minf(hill, 6.0) * 1.5
		if score > best_score:
			best_score = score
			best = int(s.cell)
	return best

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(2)
	main.new_world("4242")
	await _frames(2)
	main.founder_screen._confirm()
	for i in 220:
		main.world.tick()
	main.set_speed(0)
	main.view.refresh(true)
	main.ui.visible = false
	var cell := _pick(main.world)
	var dir: Vector3 = main.world.planet.pos[cell]
	print("région : cellule %d (%s)" % [cell, main.world.planet.biome_name(cell)])
	for v in [["1_globale", 3.0, 0.0], ["2_regionale", 1.75, 0.0], ["3_rapprochee", 1.22, 0.0], ["4_rapprochee_autre_cap", 1.22, 2.2]]:
		main.rig.heading = v[2]
		main.rig.focus_on(dir, v[1])
		main.update_lod()
		main.view.refresh()
		await _shot("%s/%s.png" % [out, v[0]])
	quit()
