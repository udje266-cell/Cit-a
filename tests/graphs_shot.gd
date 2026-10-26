extends SceneTree
## Capture des graphiques : xvfb-run godot --path . --rendering-method gl_compatibility -s tests/graphs_shot.gd -- <dossier>
var main

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.new_world("4242")
	await _frames(2)
	main.founder_screen._confirm()
	await _frames(3)
	main.tutorial_skip()
	main.world.run_years(300)
	main.ui.show_peoples()
	await _frames(8)
	root.get_viewport().get_texture().get_image().save_png(out + "/graphes_peuples.png")
	main.ui.show_people(1)
	await _frames(4)
	var charts: Array = main.ui.modal.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == preload("res://game/chart.gd"))
	for sc in main.ui.modal.find_children("*", "ScrollContainer", true, false):
		sc.ensure_control_visible(charts[charts.size() - 1])
	await _frames(4)
	for sc in main.ui.modal.find_children("*", "ScrollContainer", true, false):
		sc.ensure_control_visible(charts[charts.size() - 1])
	await _frames(6)
	root.get_viewport().get_texture().get_image().save_png(out + "/graphes_traits.png")
	quit()
