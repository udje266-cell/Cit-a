extends RefCounted
## Foi : 5 grandeurs distinctes (DECISIONS D11)
##  - fidèles : Σ population × part religieuse
##  - ferveur : 0–1 par établissement
##  - production de foi : Σ fidèles × ferveur × taux (par an)
##  - énergie divine : réserve plafonnée, dépensée par les pouvoirs et les attributions d'affinité
##  - progression : XP issue des accomplissements → niveau → pouvoirs débloqués

const Civ = preload("res://sim/civ_system.gd")

static func tick(w) -> void:
	var cfg: Dictionary = w.cat.config.faith
	var alive: Array = w.alive_settlements()
	for s in alive:
		_fervor(w, s, cfg)
	_conversions(w, alive, cfg)
	for s in alive:
		_memory(w, s, cfg)
	_production(w, alive, cfg)

static func _fervor(w, s: Dictionary, cfg: Dictionary) -> void:
	var p: Dictionary = w.peoples[int(s.people)]
	var st: Dictionary = Civ.stats_of(w, s)
	var fx: Dictionary = Civ.tech_fx(w, p)
	var target := 0.15 + float(st.spi) * 0.55 + float(fx.get("fervor", 0.0))
	s.fervor = clampf(float(s.fervor) + (target - float(s.fervor)) * float(cfg.fervor_decay), 0.0, 1.0)
	# Doute : crise sans aide divine depuis 10 ans.
	if (s.statuses.has("famine") or s.statuses.has("epidemie")) and w.year - int(s.last_help) > 10:
		s.fervor = maxf(0.0, float(s.fervor) - 0.03)
		var main := main_religion(s)
		if main != "":
			var lost := minf(float(s.faith[main]), 0.015 * (1.2 - float(st.spi)))
			s.faith[main] = float(s.faith[main]) - lost
			if lost > 0.01 and w.rng.randf() < 0.15:
				w.add_log("Les habitants de %s doutent" % s.name, "Crise sans intervention de leur dieu depuis plus de 10 ans", "faith", int(s.cell))

static func main_religion(s: Dictionary) -> String:
	var best := ""
	var bv := 0.0
	for rid in s.faith:
		if float(s.faith[rid]) > bv:
			bv = float(s.faith[rid])
			best = rid
	return best

## Diffusion entre établissements proches, indépendamment des peuples.
static func _conversions(w, alive: Array, cfg: Dictionary) -> void:
	var rate := float(cfg.conversion_rate)
	var deltas := []
	var near := _near_lists(w, alive)
	for idx in alive.size():
		var s: Dictionary = alive[idx]
		var d := {}
		var resist := 1.0 + float(w.peoples[int(s.people)].culture.get("fanatique", 0.0))
		for o in near[idx]:
			var dist: float = w.planet.pos[int(s.cell)].distance_to(w.planet.pos[int(o.cell)])
			var weight := (1.0 - dist / 0.35) * clampf(float(o.pop) / maxf(float(s.pop), 1.0), 0.2, 3.0)
			for rid in o.faith:
				var mine := float(s.faith.get(rid, 0.0))
				var push := float(o.faith[rid]) * float(o.fervor) - mine * float(s.fervor)
				if push > 0.0:
					d[rid] = d.get(rid, 0.0) + rate * weight * push / resist
		deltas.append(d)
	for i in alive.size():
		var s: Dictionary = alive[i]
		var before := main_religion(s)
		for rid in deltas[i]:
			s.faith[rid] = float(s.faith.get(rid, 0.0)) + float(deltas[i][rid])
		_normalize(s)
		var after := main_religion(s)
		if after != before and after != "":
			var rel: Dictionary = w.religions[int(after)]
			w.add_log("%s se convertit au %s" % [s.name, rel.name], "Influence d'établissements voisins plus fervents", "faith", int(s.cell))

## Voisins religieux (distance < 0,35) de chaque établissement, recalculés quand la liste change.
static func _near_lists(w, alive: Array) -> Array:
	var sig := alive.size() * 100003 + (int(alive[alive.size() - 1].id) if alive.size() > 0 else 0)
	if w.has_meta("near_lists") and w.get_meta("near_sig") == sig:
		return w.get_meta("near_lists")
	var out := []
	for s in alive:
		var lst := []
		for o in alive:
			if not is_same(o, s) and w.planet.pos[int(s.cell)].distance_to(w.planet.pos[int(o.cell)]) <= 0.35:
				lst.append(o)
		out.append(lst)
	w.set_meta("near_lists", out)
	w.set_meta("near_sig", sig)
	return out

static func _normalize(s: Dictionary) -> void:
	var total := 0.0
	for rid in s.faith:
		total += float(s.faith[rid])
	if total > 1.0:
		for rid in s.faith:
			s.faith[rid] = float(s.faith[rid]) / total
	for rid in s.faith.keys():
		if float(s.faith[rid]) < 0.005:
			s.faith.erase(rid)

## Mémoire du culte : trace qui survit à l'abandon d'une religion et permet sa redécouverte.
static func _memory(w, s: Dictionary, cfg: Dictionary) -> void:
	var decay := float(cfg.memory_decay)
	if w.peoples[int(s.people)].culture.has("ancestral"):
		decay *= 0.5
	for rid in s.faith:
		var did := str(w.religions[int(rid)].deity)
		s.memory[did] = maxf(float(s.memory.get(did, 0.0)), float(s.faith[rid]))
	for did in s.memory.keys():
		s.memory[did] = float(s.memory[did]) - decay * 0.1
		if float(s.memory[did]) <= 0.0:
			s.memory.erase(did)
			continue
		# Redécouverte : traces anciennes d'un culte presque disparu ici.
		var rid := religion_of_deity(w, int(did))
		if rid >= 0 and float(s.faith.get(str(rid), 0.0)) < 0.05 and float(s.memory[did]) > 0.2 and w.rng.randf() < 0.01:
			s.faith[str(rid)] = float(s.faith.get(str(rid), 0.0)) + 0.06
			_normalize(s)
			w.add_log("Redécouverte à %s du culte de %s" % [s.name, w.deities[int(did)].name], "Des ruines de sanctuaire et des récits anciens subsistent (mémoire %.0f %%)" % (float(s.memory[did]) * 100.0), "faith", int(s.cell))

static func religion_of_deity(w, did: int) -> int:
	for r in w.religions:
		if int(r.deity) == did:
			return int(r.id)
	return -1

static func _production(w, alive: Array, cfg: Dictionary) -> void:
	var prod := {}
	var bel := {}
	for d in w.deities:
		prod[int(d.id)] = 0.0
		bel[int(d.id)] = 0.0
	for s in alive:
		var fx: Dictionary = Civ.tech_fx(w, w.peoples[int(s.people)])
		var temple := 1.0 + float(fx.get("fervor", 0.0)) * 2.0
		for rid in s.faith:
			var did := int(w.religions[int(rid)].deity)
			var b := float(s.pop) * float(s.faith[rid])
			bel[did] += b
			prod[did] += b * float(s.fervor) * float(cfg.faith_per_believer) * temple
	for d in w.deities:
		var id := int(d.id)
		d.believers = bel[id]
		d.faith_rate = prod[id]
		d.max_energy = float(cfg.base_max_energy) + float(cfg.max_energy_per_level) * int(d.level)
		# Revenu de base : un dieu qui a au moins un fidèle gagne toujours un peu d'énergie (début de partie jouable).
		var base := float(cfg.get("base_income", 0.0)) if bel[id] >= 1.0 else 0.0
		d.faith_rate = prod[id] + base
		var e := float(d.energy) + float(prod[id]) + base
		# Voie de retour : un dieu sans fidèles conserve une étincelle d'énergie.
		if bel[id] < 10.0 and e < float(cfg.weak_regen_cap):
			e = minf(e + float(cfg.weak_regen), float(cfg.weak_regen_cap))
		d.energy = minf(e, float(d.max_energy))

# ------------------------------------------------------------------ Progression

static func metric(w, d: Dictionary, kind: String) -> float:
	var id := int(d.id)
	match kind:
		"settlements":
			var n := 0
			for s in w.alive_settlements():
				var m := main_religion(s)
				if m != "" and int(w.religions[int(m)].deity) == id:
					n += 1
			return n
		"believers":
			return w.believers_of(id)
		"powers_used":
			return int(d.powers_used)
		"rules_enabled":
			var n2 := 0
			for r in d.rules:
				if r.enabled:
					n2 += 1
			return n2
		"affinities_granted":
			return int(d.affinities_granted)
		"era":
			var e := 0
			for p in w.peoples:
				if int(p.deity) == id and not p.extinct:
					e = maxi(e, int(p.era))
			return e
		"foreign_believers":
			var t := 0.0
			for s in w.alive_settlements():
				if int(w.peoples[int(s.people)].deity) == id:
					continue
				for rid in s.faith:
					if int(w.religions[int(rid)].deity) == id:
						t += float(s.pop) * float(s.faith[rid])
			return t
	return 0.0

static func check_achievements(w) -> void:
	for d in w.deities:
		for a in w.cat.achievements:
			if a.id in d.achievements:
				continue
			if metric(w, d, a.cond.type) >= float(a.cond.value):
				d.achievements.append(a.id)
				d.xp = int(d.xp) + int(a.xp)
				if d.is_player:
					w.add_log("Accomplissement : %s" % a.name, a.desc, "deity", -1)
		var lvl := 0
		for i in w.cat.level_xp.size():
			if int(d.xp) >= int(w.cat.level_xp[i]):
				lvl = i
		if lvl > int(d.level):
			d.level = lvl
			if d.is_player:
				var unlocked := []
				for pid in w.cat.power_order:
					if int(w.cat.powers[pid].unlock.get("level", 0)) == lvl:
						unlocked.append(w.cat.powers[pid].name)
				w.add_log("Votre puissance grandit : niveau %d" % lvl, "Nouveaux pouvoirs : " + (", ".join(unlocked) if unlocked.size() > 0 else "aucun") + " ; énergie maximale accrue", "deity", -1)
