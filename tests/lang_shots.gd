extends SceneTree
## Captures de l'interface dans une autre langue : godot --path . -s tests/lang_shots.gd -- <dossier> [langue]
var main

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(out: String, name: String) -> void:
	await _frames(6)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var lang: String = args[1] if args.size() > 1 else "en"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.set_language(lang)
	main._show_menu()
	await _shot(out, "lang_menu")
	main.new_world("4242")
	await _frames(2)
	await _shot(out, "lang_fondateurs")
	main.founder_screen._confirm()
	await _frames(3)
	main.world.run_years(120)
	main.view.refresh(true)
	var s: Dictionary = main.world.people_settlements(0)[0]
	main.focus_settlement(int(s.id))
	await _shot(out, "lang_jeu")
	main.tutorial_skip()
	main.ui.show_people(0)
	await _shot(out, "lang_peuple")
	main.ui.close_modal()
	main.ui.show_game_menu()
	await _shot(out, "lang_menu_jeu")
	main.set_language("fr")
	quit()
