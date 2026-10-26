extends SceneTree
## Mesures du rendu : temps de construction, image moyenne et primitives aux trois distances.
##   xvfb-run godot --path . --rendering-method gl_compatibility -s tests/perf_view.gd

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.new_world("4242")
	await process_frame
	main.founder_screen._confirm()
	for i in 220:
		main.world.tick()
	var t0 := Time.get_ticks_msec()
	main.view.setup(main.world)
	print("construction complète du monde visuel : %d ms" % (Time.get_ticks_msec() - t0))
	var t1 := Time.get_ticks_msec()
	main.world.planet.add_height([500], 0.2)
	main.world.planet.recompute()
	main.view.refresh()
	print("modification locale du terrain (reconstruction partielle) : %d ms" % (Time.get_ticks_msec() - t1))
	main.set_speed(0)
	var cell: int = main.world.people_settlements(0)[0].cell
	for d in [3.2, 1.9, 1.3]:
		main.rig.focus_on(main.world.planet.pos[cell], d)
		main.update_lod()
		main.view.refresh()
		for i in 10:
			await process_frame
		var f0 := Time.get_ticks_usec()
		var prim := 0
		var calls := 0
		for i in 60:
			await process_frame
			prim = maxi(prim, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
			calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		print("distance %.1f : image %.1f ms (rendu logiciel llvmpipe) · %d primitives · %d appels de dessin" % [d, (Time.get_ticks_usec() - f0) / 60000.0, prim, calls])
	print("sommets terrain : %d · mémoire statique %.1f Mo · vidéo %.1f Mo" % [main.view.vertex_count(), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	quit()
