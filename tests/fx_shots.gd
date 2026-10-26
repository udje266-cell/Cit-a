extends SceneTree
## Captures des effets visuels des pouvoirs, même cadrage pour chacun.
## xvfb-run godot --path . --rendering-method gl_compatibility -s tests/fx_shots.gd -- <dossier> [effets...]
var main

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var kinds: Array = args.slice(1) if args.size() > 1 else ["rain", "blessing", "aurora", "eruption", "frost", "dna", "spring", "sun"]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.new_world("4242")
	await _frames(2)
	main.founder_screen._confirm()
	await _frames(3)
	main.tutorial_skip()
	main.set_speed(0)
	main.ui.close_modal()
	var s: Dictionary = main.world.people_settlements(0)[0]
	main.rig.focus_on(main.world.planet.pos[int(s.cell)], 1.45)
	main.ui.info_panel.visible = false
	await _frames(30)
	var cells: Array = main.world.planet.cells_within(int(s.cell), 1, 20)
	for k in kinds:
		main.view.play_fx(k, cells)
		await create_timer(0.9).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/fx_%s.png" % [out, k])
		print("fx ", k, " nœuds actifs ", main.view.fx.active_count())
		await create_timer(5.0).timeout
	print("fx restants après extinction : ", main.view.fx.active_count())
	quit()
