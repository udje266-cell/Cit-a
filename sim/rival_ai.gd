extends RefCounted
## Divinités rivales : IA d'utilité locale, mêmes règles et mêmes coûts que le joueur.
## Les attributions d'affinités se font via leurs propres règles automatiques (affinity.gd).

const Powers = preload("res://sim/powers.gd")
const Faith = preload("res://sim/faith_system.gd")
const RESERVE := 5.0

static func tick(w) -> void:
	for d in w.deities:
		if d.is_player:
			continue
		if (w.year + int(d.id)) % 3 == 0:
			_act(w, d)
	if w.year % 10 == 0:
		_diplomacy(w)

static func _own_settlements(w, did: int) -> Array:
	var out := []
	for s in w.alive_settlements():
		var m := Faith.main_religion(s)
		if m != "" and int(w.religions[int(m)].deity) == did:
			out.append(s)
	return out

static func _act(w, d: Dictionary) -> void:
	var did := int(d.id)
	var pers: Dictionary = d.personality
	var options := []   # [utility, power, cell, reason]
	var own := _own_settlements(w, did)
	for s in own:
		if s.statuses.has("famine"):
			options.append([1.0 + float(pers.benevolence), "pluie", int(s.cell), "famine"])
			options.append([0.9 + float(pers.benevolence), "floraison", int(s.cell), "famine"])
		if s.statuses.has("epidemie"):
			options.append([1.1 + float(pers.benevolence), "guerison", int(s.cell), "épidémie"])
		if float(s.fervor) < 0.35:
			options.append([0.7, "signe", int(s.cell), "ferveur faible"])
		var p: Dictionary = w.peoples[int(s.people)]
		if int(p.research.stalled_since) >= 0 or (p.research.current != "" and w.rng.randf() < 0.2):
			options.append([0.5, "revelation", int(s.cell), "recherche"])
	# Prosélytisme : établissements étrangers proches.
	for s in w.alive_settlements():
		var m := Faith.main_religion(s)
		if m != "" and int(w.religions[int(m)].deity) == did:
			continue
		for o in own:
			if w.planet.pos[int(s.cell)].distance_to(w.planet.pos[int(o.cell)]) < 0.35:
				options.append([0.4 + float(pers.aggression) * 0.4, "signe", int(s.cell), "conversion"])
				break
	# Guerre : malédiction sur l'ennemi des peuples fidèles.
	if float(pers.aggression) > 0.6:
		for s in w.alive_settlements():
			var m2 := Faith.main_religion(s)
			if m2 == "" or int(w.religions[int(m2)].deity) == did:
				continue
			for o in own:
				var r: Dictionary = w.relation(int(o.people), int(s.people))
				if int(o.people) != int(s.people) and r.war:
					options.append([0.6 + float(pers.aggression) * 0.5 - float(pers.benevolence) * 0.4, "malediction", int(s.cell), "guerre"])
					break
	# Retour d'un dieu oublié.
	if own.is_empty():
		for s in w.alive_settlements():
			if float(s.memory.get(str(did), 0.0)) > 0.0:
				options.append([2.0, "murmure", int(s.cell), "reconquête"])
				break
		if options.is_empty() and w.alive_settlements().size() > 0:
			var any: Dictionary = w.alive_settlements()[w.rng.randi_range(0, w.alive_settlements().size() - 1)]
			options.append([1.5, "murmure", int(any.cell), "reconquête"])
	options.sort_custom(func(a, b): return a[0] > b[0])
	for o in options:
		var pid: String = o[1]
		if not Powers.is_unlocked(w, d, pid):
			continue
		var reserve := 0.0 if pid == "murmure" else RESERVE
		var pv := Powers.preview(w, did, pid, o[2])
		if pv.ok and float(d.energy) >= float(pv.cost) + reserve:
			Powers.apply(w, did, pid, o[2])
			return

## Relations entre dieux : affinités de personnalité, concurrence pour les mêmes fidèles.
static func _diplomacy(w) -> void:
	for a in w.deities:
		for b in w.deities:
			if int(a.id) >= int(b.id):
				continue
			var pa: Dictionary = a.personality
			var pb: Dictionary = b.personality
			var delta := 0.1 - absf(float(pa.magic_bias) - float(pb.magic_bias)) * 0.1 - (float(pa.aggression) + float(pb.aggression)) * 0.08
			delta += (float(pa.benevolence) + float(pb.benevolence)) * 0.04
			# Rivalité religieuse : fidèles mêlés dans les mêmes établissements.
			var ra := Faith.religion_of_deity(w, int(a.id))
			var rb := Faith.religion_of_deity(w, int(b.id))
			for s in w.alive_settlements():
				if s.faith.has(str(ra)) and s.faith.has(str(rb)):
					delta -= 0.03
			var v := clampf(float(a.relations.get(str(b.id), 0.0)) + delta, -1.0, 1.0)
			var old := float(a.relations.get(str(b.id), 0.0))
			a.relations[str(b.id)] = v
			b.relations[str(a.id)] = v
			if old <= 0.5 and v > 0.5 and not (a.is_player or b.is_player):
				if not a.has("pacts"): a["pacts"] = {}
				if not b.has("pacts"): b["pacts"] = {}
				a.pacts[str(b.id)] = w.year
				b.pacts[str(a.id)] = w.year
				w.add_log("Pacte divin : %s et %s" % [a.name, b.name], "Préférences compatibles (relation %.2f) ; leurs peuples se rapprochent" % v, "diplomacy", -1)
			elif old >= -0.5 and v < -0.5:
				w.add_log("Rivalité divine : %s et %s" % [a.name, b.name], "Concurrence pour les mêmes fidèles ou tempéraments opposés (%.2f)" % v, "diplomacy", -1)
