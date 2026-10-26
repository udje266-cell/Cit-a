extends SceneTree
## Rapport d'équilibrage : godot --headless --path . -s tests/balance_report.gd -- [années] [graines...]
## Mesure, par graine, l'état du monde tous les 250 ans et compte les événements marquants.

const KEYS := ["Guerre", "Paix", "Alliance", "Accord", "Union", "conquiert", "Sécession", "disparaît", "Épidémie", "Famine", "Pacte"]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0]) if args.size() > 0 else 1000
	var seeds := []
	for i in range(1, args.size()):
		seeds.append(int(args[i]))
	if seeds.is_empty():
		seeds = [5, 42, 777]
	var cat = preload("res://sim/catalog.gd").new()
	cat.load_all()
	var species := ["sylvain", "terragne", "ondin", "cendre", "givrin", "vivace"]
	for sd in seeds:
		var w = preload("res://sim/world.gd").new(cat)
		w.create_planet(sd, 4)
		w.create_player_people(species[sd % species.size()], "Joueur", [{"name": "A", "traits": []}, {"name": "B", "traits": []}], {"name": "Vous"})
		w.create_rivals(4)
		var counts := {}
		var t0 := Time.get_ticks_msec()
		for y in years:
			w.tick()
			for e in w.chronicle:
				if e.has("seen"):
					continue
				e["seen"] = true
				for k in KEYS:
					if str(e.txt).find(k) >= 0:
						counts[k] = int(counts.get(k, 0)) + 1
			if w.year % 250 == 0:
				var line := "graine %d an %4d :" % [sd, w.year]
				for p in w.peoples:
					if not p.extinct:
						line += " [%s %s ère %d %d hab. %d ét.]" % [p.name.left(10), p.polity, int(p.era), int(w.people_pop(int(p.id))), w.people_settlements(int(p.id)).size()]
				print(line)
				var dl := "    dieux :"
				for d in w.deities:
					dl += " %s %d fidèles niv.%d énergie %.0f/%.0f ;" % [d.name.left(10), int(d.believers), int(d.level), float(d.energy), float(d.max_energy)]
				print(dl)
		var alive := 0
		for p in w.peoples:
			if not p.extinct:
				alive += 1
		print("graine %d : %d peuples (%d vivants), %d établissements, %.1f s, événements %s" % [sd, w.peoples.size(), alive, w.alive_settlements().size(), (Time.get_ticks_msec() - t0) / 1000.0, counts])
	quit()
