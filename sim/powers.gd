extends RefCounted
## Pouvoirs divins : disponibilité, prévisualisation (zone + coût), application réelle, effets différés.

const Affinity = preload("res://sim/affinity.gd")
const Civ = preload("res://sim/civ_system.gd")
const Faith = preload("res://sim/faith_system.gd")

static func is_unlocked(w, d: Dictionary, pid: String) -> bool:
	var p: Dictionary = w.cat.powers[pid]
	return p.get("always_available", false) or int(d.level) >= int(p.unlock.get("level", 0))

static func cost(w, pid: String, opts: Dictionary = {}) -> float:
	var p: Dictionary = w.cat.powers[pid]
	for e in p.effects:
		if e.t == "grant_affinity":
			return Affinity.cost_of(w, opts.get("affinity", Affinity.MAGIC), true) * int(opts.get("count", e.v))
	return float(p.cost)

static func area(w, pid: String, cell: int) -> Array:
	var p: Dictionary = w.cat.powers[pid]
	return w.planet.cells_within(cell, int(p.radius), 200)

static func settlements_in(w, cells: Array) -> Array:
	var seen := {}
	var out := []
	for c in cells:
		var o: int = w.owner[int(c)]
		if o >= 0 and not seen.has(o) and w.settlements[o].alive:
			seen[o] = true
			out.append(w.settlements[o])
	return out

## Prévisualisation sans effet de bord.
static func preview(w, did: int, pid: String, cell: int, opts: Dictionary = {}) -> Dictionary:
	var d: Dictionary = w.deities[did]
	var p: Dictionary = w.cat.powers[pid]
	var cells := area(w, pid, cell)
	var setl := settlements_in(w, cells)
	var c := cost(w, pid, opts)
	var reason := ""
	if not is_unlocked(w, d, pid):
		reason = "Débloqué au niveau %d" % int(p.unlock.get("level", 0))
	elif float(d.energy) < c:
		reason = "Énergie insuffisante (%.1f / %.1f)" % [float(d.energy), c]
	elif p.target == "settlement" and setl.is_empty():
		reason = "Choisissez un établissement"
	var warnings := []
	for s in setl:
		var m := Faith.main_religion(s)
		if m != "" and int(w.religions[int(m)].deity) == did and p.family in ["catastrophe"] and pid != "renaissance":
			warnings.append("%s vous vénère : vos fidèles souffriront" % s.name)
	return {"cells": cells, "settlements": setl.map(func(s): return int(s.id)), "cost": c, "ok": reason == "",
		"reason": reason, "warnings": warnings, "name": p.name}

static func apply(w, did: int, pid: String, cell: int, opts: Dictionary = {}) -> Dictionary:
	var pv := preview(w, did, pid, cell, opts)
	if not pv.ok:
		return {"ok": false, "msg": pv.reason}
	var d: Dictionary = w.deities[did]
	var p: Dictionary = w.cat.powers[pid]
	var cells: Array = pv.cells
	if p.target == "settlement":
		cells = [int(w.settlements[pv.settlements[0]].cell)]
	var spent := float(pv.cost)
	var result_note := ""
	for e in p.effects:
		var r := apply_effect(w, did, e, cells, opts)
		if e.t == "grant_affinity":
			# On ne facture que les personnes réellement transformées.
			spent = 0.0
			result_note = " (%d personnes)" % r
	d.energy = float(d.energy) - spent
	d.powers_used = int(d.powers_used) + 1
	for e in p.get("delayed", []):
		w.pending.append({"due": w.year + int(e.after), "effect": e, "cells": cells, "deity": did, "power": pid})
	var place := ""
	var setl := settlements_in(w, cells)
	if not setl.is_empty():
		place = " sur " + setl[0].name
	w.add_log("%s : %s%s%s" % [d.name, p.name, place, result_note], "Intervention divine", "power", cell)
	return {"ok": true, "msg": p.name + result_note}

## Retourne une valeur numérique selon l'effet (ex. nombre de personnes touchées).
static func apply_effect(w, did: int, e: Dictionary, cells: Array, opts: Dictionary = {}) -> int:
	var pl = w.planet
	var setl := settlements_in(w, cells)
	var rel := Faith.religion_of_deity(w, did)
	match str(e.t):
		"height":
			var noise_rng = w.rng if e.get("noise", false) else null
			pl.add_height(cells, float(e.v), true, noise_rng)
			_after_terrain(w)
		"moisture":
			pl.add_offset("moist_offset", cells, float(e.v))
			pl.recompute()
		"temperature":
			pl.add_offset("temp_offset", cells, float(e.v))
			pl.recompute()
		"fertility":
			pl.add_offset("fert_offset", cells, float(e.v))
			pl.recompute()
		"resource":
			pl.add_resource(cells, str(e.v))
			pl.recompute()
		"fervor":
			for s in setl:
				var m := Faith.main_religion(s)
				if m != "" and int(w.religions[int(m)].deity) == did:
					var bonus := 1.0 + float(s.freqs.get("devin", 0.0))
					s.fervor = clampf(float(s.fervor) + float(e.v) * bonus, 0.0, 1.0)
					if float(e.v) > 0.0:
						s.last_help = w.year
				elif float(e.v) > 0.0 and rel >= 0:
					s.faith[str(rel)] = float(s.faith.get(str(rel), 0.0)) + float(e.v) * 0.3
					Faith._normalize(s)
		"conversion":
			for s in setl:
				if float(e.v) > 0.0 and rel >= 0:
					var mem := float(s.memory.get(str(did), 0.0))
					s.faith[str(rel)] = float(s.faith.get(str(rel), 0.0)) + float(e.v) * (1.0 + mem)
					Faith._normalize(s)
				elif float(e.v) < 0.0:
					var m2 := Faith.main_religion(s)
					if m2 != "":
						s.faith[m2] = maxf(0.0, float(s.faith[m2]) + float(e.v))
		"memory":
			for s in setl:
				s.memory[str(did)] = minf(1.0, float(s.memory.get(str(did), 0.0)) + float(e.v))
		"status":
			for s in setl:
				var years := int(e.get("years", 5))
				if e.v == "maudit":
					years = int(years * (1.0 - 0.5 * float(s.freqs.get("sourd_magie", 0.0))))
				else:
					s.last_help = w.year
				s.statuses[e.v] = years
		"cleanse":
			for s in setl:
				for k in e.v:
					s.statuses.erase(k)
				s.last_help = w.year
		"pop":
			for s in setl:
				var deaths := float(s.pop) * absf(float(e.v))
				Affinity.apply_deaths(s, deaths)
				s.pop = float(s.pop) - deaths
				w.add_log("%s perd %d habitants" % [s.name, int(deaths)], "Catastrophe divine", "disaster", int(s.cell))
		"research":
			for s in setl:
				var p: Dictionary = w.peoples[int(s.people)]
				var cur: String = p.research.current
				if cur != "" and w.cat.techs.has(cur):
					p.research.progress = float(p.research.progress) + float(e.v) * float(w.cat.techs[cur].cost)
				s.last_help = w.year
		"grant_affinity":
			if setl.is_empty():
				return 0
			return Affinity.grant_late(w, w.deities[did], setl[0], str(opts.get("affinity", Affinity.MAGIC)), int(opts.get("count", e.v)))
		"evolve":
			for s in setl:
				Civ.force_generation(w, s, 1.0 + float(e.v) * 20.0)
	return 0

## Après un changement de relief : recalcul du climat, établissements submergés.
static func _after_terrain(w) -> void:
	var pl = w.planet
	pl.recompute()
	for s in w.alive_settlements():
		if not pl.is_land(int(s.cell)):
			var survivors := float(s.pop) * 0.5
			var target := -1
			for c in pl.cells_within(int(s.cell), 3, 40):
				if pl.is_land(c) and (w.owner[c] == -1 or w.owner[c] == int(s.id)):
					target = c
					break
			if target < 0:
				Civ._abandon(w, s, "Englouti par les eaux, aucune terre proche")
			else:
				w.owner[int(s.cell)] = -1
				Affinity.apply_deaths(s, float(s.pop) - survivors)
				s.pop = survivors
				s.cell = target
				w.owner[target] = int(s.id)
				w.add_log("%s est englouti ; les survivants se replient" % s.name, "Le relief a été abaissé sous le niveau de la mer", "disaster", target)
		var keep := []
		for c in s.territory:
			if pl.is_land(int(c)):
				keep.append(int(c))
			elif w.owner[int(c)] == int(s.id):
				w.owner[int(c)] = -1
		if s.alive:
			if not int(s.cell) in keep:
				keep.push_front(int(s.cell))
			s.territory = keep

static func process_pending(w) -> void:
	var keep := []
	for p in w.pending:
		if int(p.due) <= w.year:
			apply_effect(w, int(p.deity), p.effect, p.cells)
			var pname: String = w.cat.powers[p.power].name if w.cat.powers.has(p.power) else str(p.power)
			w.add_log("Conséquence différée : %s" % pname, "Effet de « %s » utilisé en l'an %d" % [pname, int(p.due) - int(p.effect.after)], "power", int(p.cells[0]) if p.cells.size() > 0 else -1)
		else:
			keep.append(p)
	w.pending = keep
