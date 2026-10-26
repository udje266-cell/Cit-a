extends SceneTree
## Mesure du coût de la simulation selon la taille du monde.
##   godot --headless --path . -s tests/bench_sim.gd
func _init():
	var W = preload("res://sim/world.gd")
	for sub in [4, 5]:
		var w = W.new()
		var t0 := Time.get_ticks_msec()
		w.create_planet(2024, sub)
		var gen := Time.get_ticks_msec() - t0
		w.create_player_people("vivace", "B", [{"name":"A","traits":["fecond"]},{"name":"B","traits":["curieux"]}], {"name":"D"})
		w.create_rivals(4 if sub == 5 else 2)
		w.run_years(300)
		var t1 := Time.get_ticks_usec()
		w.run_years(50)
		var per := (Time.get_ticks_usec() - t1) / 50000.0
		print("niveau %d : %d cellules · génération %d ms · %d établissements · %d peuples · %.2f ms/an" % [sub, w.planet.cell_count, gen, w.alive_settlements().size(), w.peoples.size(), per])
	quit()
