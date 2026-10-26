extends SceneTree
## Test de fumée de la couche jeu : parcourt le flux complet sans intervention humaine.
##   godot --headless --path . -s tests/smoke_game.gd

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.new_world("4242")
	await _frames(2)
	main.founder_screen._randomize()
	main.founder_screen._confirm()
	await _frames(2)
	print("état : ", main.state, " · peuples : ", main.world.peoples.size())
	main.set_speed(4)
	for i in 120:
		main.world.tick()
	main.view.refresh(true)
	await _frames(2)
	var s: Dictionary = main.world.people_settlements(0)[0]
	main.ui.show_cell(int(s.cell))
	main.select_power("signe")
	main.preview_at(int(s.cell))
	main.confirm_power()
	main.select_power("don_affinite", {"affinity": "both", "count": 1})
	main.preview_at(int(s.cell))
	main.confirm_power()
	for o in main.view.OVERLAYS:
		main.set_overlay(o)
	main.ui.show_affinity_rules()
	main.ui.show_people(0)
	main.ui.show_deity(1)
	main.ui.show_individuals(int(s.id))
	main.ui.show_manual_affinity(int(s.id))
	main.ui.show_game_menu()
	main.ui._toggle_log()
	main.ui.show_peoples()
	main.ui.show_overlays()
	for t in ["year", "energy", "faith", "believers"]:
		main.ui.show_explain(t)
	main.focus_people(1)
	for d in [3.2, 1.9, 1.2]:
		main.rig.focus_on(main.world.planet.pos[int(s.cell)], d)
		main.update_lod()
		main.view.refresh()
		await _frames(1)
	main.set_overlay("grid")
	main.ui.refresh_hud(1)
	await _frames(3)
	print(main.export_world("seed"))
	print("sommets : ", main.view.vertex_count(), " · maillage ", main.view.last_build_ms, " ms")
	var id: String = main.world_id
	main.back_to_menu()
	await _frames(2)
	main.continue_world(id)
	await _frames(5)
	print("reprise : an ", main.world.year, " · état ", main.state)
	main.delete_world(id)
	print("SMOKE OK")
	quit()
