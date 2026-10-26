extends RefCounted
## Diplomatie entre peuples (tous les 2 ans) et pactes entre dieux.
##
## Relation entre deux peuples (World.relation) :
##   value (-1..1), contact, war, war_cause, since, alliance, trade, pact_until (non-agression),
##   tribute {payer, receiver, until, rate}, allied_since.
## Tout découle des traits, des religions, des ressources, des rapports de force et des dieux :
## aucun événement n'est imposé au hasard sans cause journalisée.

const Civ = preload("res://sim/civ_system.gd")
const Faith = preload("res://sim/faith_system.gd")
const Affinity = preload("res://sim/affinity.gd")

const PACT_YEARS := 25
const TRIBUTE_YEARS := 12

static func tick(w) -> void:
	_tributes(w)
	if w.year % 2 != 0:
		return
	var contacts := _contacts(w)
	for k in contacts:
		var parts: PackedStringArray = k.split(":")
		_pair(w, int(parts[0]), int(parts[1]))
	_trade_effects(w)
	_mergers(w)

static func _contacts(w) -> Dictionary:
	var contacts := {}
	for s in w.alive_settlements():
		for c in s.territory:
			for nb in w.planet.neighbors[int(c)]:
				var o: int = w.owner[nb]
				if o >= 0 and int(w.settlements[o].people) != int(s.people):
					contacts[w.rel_key(int(s.people), int(w.settlements[o].people))] = true
	return contacts

static func _avg_stats(w, pid: int) -> Dictionary:
	var lst: Array = w.people_settlements(pid)
	return Civ.stats_of(w, lst[0]) if lst.size() > 0 else {}

static func power_of(w, pid: int) -> float:
	var m := 0.0
	for s in w.people_settlements(pid):
		m += float(s.military)
	return m

static func resources_of(w, pid: int) -> Dictionary:
	var res := {}
	for s in w.people_settlements(pid):
		for c in s.territory:
			for r in w.planet.res_list(int(c)):
				res[r] = true
	return res

## Partenaires commerciaux d'un peuple.
static func trade_partners(w, pid: int) -> Array:
	var out := []
	for k in w.relations:
		var r: Dictionary = w.relations[k]
		if r.get("trade", false) and not r.war:
			var parts: PackedStringArray = k.split(":")
			var a := int(parts[0])
			var b := int(parts[1])
			if a == pid or b == pid:
				out.append(b if a == pid else a)
	return out

static func _pair(w, a: int, b: int) -> void:
	var r: Dictionary = w.relation(a, b)
	var pa: Dictionary = w.peoples[a]
	var pb: Dictionary = w.peoples[b]
	if pa.extinct or pb.extinct:
		return
	if not r.contact:
		r.contact = true
		w.add_log("Premier contact : %s et %s" % [pa.name, pb.name], "Leurs territoires se touchent", "diplomacy", int(pa.origin_cell))
	var sa := _avg_stats(w, a)
	var sb := _avg_stats(w, b)
	if sa.is_empty() or sb.is_empty():
		return
	# Évolution de la relation : tempéraments, religion, dieux, commerce, concurrence pour la terre.
	var ra := Civ._main_religion(w, a)
	var rb := Civ._main_religion(w, b)
	var da: Dictionary = w.deities[int(pa.deity)]
	var db: Dictionary = w.deities[int(pb.deity)]
	var delta := -0.02 * (float(sa.agg) + float(sb.agg)) + 0.01 * (float(sa.coop) + float(sb.coop))
	delta += 0.01 * (float(sa.soc) + float(sb.soc) - 1.0)
	var same_faith := ra == rb and ra >= 0
	if same_faith:
		delta += 0.03
	else:
		var fanat := float(pa.culture.get("fanatique", 0.0)) + float(pb.culture.get("fanatique", 0.0))
		delta -= 0.015 + 0.03 * fanat
	delta += 0.025 * float(da.relations.get(str(db.id), 0.0))
	if da.get("pacts", {}).has(str(db.id)):
		delta += 0.03
	if r.get("trade", false):
		delta += 0.015
	r.value = clampf(float(r.value) + delta, -1.0, 1.0)
	var v := float(r.value)
	if r.war:
		_battle(w, a, b, r)
		return
	# Traités.
	if not r.get("trade", false) and v > 0.15:
		var res_a := resources_of(w, a)
		var res_b := resources_of(w, b)
		var gives := []
		for x in res_b:
			if not res_a.has(x):
				gives.append(x)
		for x in res_a:
			if not res_b.has(x):
				gives.append(x)
		if gives.size() > 0:
			r.trade = true
			w.add_log("Accord commercial : %s et %s" % [pa.name, pb.name], "Ressources complémentaires (%s) et bonnes relations (%.2f)" % [", ".join(gives.slice(0, 3)), v], "diplomacy", int(pa.origin_cell))
	if v > 0.3 and int(r.get("pact_until", -1)) < w.year:
		r.pact_until = w.year + PACT_YEARS
		w.add_log("Pacte de non-agression : %s et %s" % [pa.name, pb.name], "Relations cordiales (%.2f), pour %d ans" % [v, PACT_YEARS], "diplomacy", int(pa.origin_cell))
	if not r.alliance and v > 0.6:
		r.alliance = true
		r.allied_since = w.year
		w.add_log("Alliance : %s et %s" % [pa.name, pb.name], "Relations excellentes (%.2f)%s" % [v, ", même foi" if same_faith else ""], "diplomacy", int(pa.origin_cell))
	elif r.alliance and v < 0.3:
		r.alliance = false
		w.add_log("Fin de l'alliance : %s et %s" % [pa.name, pb.name], "Relations dégradées (%.2f)" % v, "diplomacy", int(pa.origin_cell))
	if r.get("trade", false) and v < -0.2:
		r.trade = false
		w.add_log("Rupture commerciale : %s et %s" % [pa.name, pb.name], "Relations hostiles (%.2f)" % v, "diplomacy", int(pa.origin_cell))
	# Déclaration de guerre : hostilité, tempérament, pas de pacte en cours.
	if v < -0.5 and int(r.get("pact_until", -1)) < w.year:
		var aggr := float(sa.agg) + float(sb.agg)
		var religious: bool = not same_faith and (float(da.personality.aggression) > 0.6 or float(db.personality.aggression) > 0.6
			or pa.culture.has("fanatique") or pb.culture.has("fanatique"))
		if w.rng.randf() < 0.3 * aggr + (0.15 if religious else 0.0):
			_declare_war(w, a, b, r, "religion" if religious else "frontière")

static func _declare_war(w, a: int, b: int, r: Dictionary, cause: String) -> void:
	r.war = true
	r.since = w.year
	r.alliance = false
	r.trade = false
	r.war_cause = cause
	var why := "Guerre de religion : %s contre %s" % [w.religions[Civ._main_religion(w, a)].name if Civ._main_religion(w, a) >= 0 else "?", w.religions[Civ._main_religion(w, b)].name if Civ._main_religion(w, b) >= 0 else "?"] if cause == "religion" else "Tensions frontalières, tempéraments agressifs (relation %.2f)" % float(r.value)
	w.add_log("%s : %s contre %s" % ["Guerre de religion" if cause == "religion" else "Guerre", w.peoples[a].name, w.peoples[b].name], why, "war", int(w.peoples[a].origin_cell))
	# Les alliés hostiles à l'ennemi entrent en guerre à leur tour.
	for ally in _allies(w, a):
		if ally != b and float(w.relation(ally, b).value) < 0.0 and not w.relation(ally, b).war:
			var r2: Dictionary = w.relation(ally, b)
			r2.war = true
			r2.since = w.year
			r2.war_cause = "alliance"
			w.add_log("%s rejoint la guerre contre %s" % [w.peoples[ally].name, w.peoples[b].name], "Alliance avec %s" % w.peoples[a].name, "war", int(w.peoples[ally].origin_cell))

static func _allies(w, pid: int) -> Array:
	var out := []
	for k in w.relations:
		var r: Dictionary = w.relations[k]
		if r.alliance:
			var parts: PackedStringArray = k.split(":")
			if int(parts[0]) == pid:
				out.append(int(parts[1]))
			elif int(parts[1]) == pid:
				out.append(int(parts[0]))
	return out

static func _battle(w, a: int, b: int, r: Dictionary) -> void:
	var ma := power_of(w, a)
	var mb := power_of(w, b)
	var total := maxf(ma + mb, 0.1)
	for pair in [[a, mb], [b, ma]]:
		for s in w.people_settlements(pair[0]):
			var loss := float(s.pop) * 0.02 * (float(pair[1]) / total)
			Affinity.apply_deaths(s, loss)
			s.pop = float(s.pop) - loss
	# Conquête : un camp nettement plus fort prend un établissement frontalier.
	var strong := a if ma > mb * 2.0 else (b if mb > ma * 2.0 else -1)
	if strong >= 0 and w.rng.randf() < 0.35:
		_conquer(w, strong, b if strong == a else a, r)
	if w.year - int(r.since) > 10 or w.rng.randf() < 0.08 or w.people_settlements(a).is_empty() or w.people_settlements(b).is_empty():
		_peace(w, a, b, r, ma, mb)

static func _conquer(w, winner: int, loser: int, r: Dictionary) -> void:
	var best: Dictionary = {}
	var bd := 9.0
	var wl: Array = w.people_settlements(winner)
	if wl.is_empty():
		return
	for s in w.people_settlements(loser):
		for o in wl:
			var d: float = w.planet.pos[int(s.cell)].distance_to(w.planet.pos[int(o.cell)])
			if d < bd:
				bd = d
				best = s
	if best.is_empty() or bd > 0.4:
		return
	best.people = winner
	w.invalidate_settlements()
	w.tick_cache.erase("st%d" % int(best.id))
	best.stability = 0.25
	best.statuses["traumatise"] = 5
	# Guerre de religion : la foi du vainqueur s'impose en partie.
	var rel := Civ._main_religion(w, winner)
	if str(r.get("war_cause", "")) == "religion" and rel >= 0:
		best.faith[str(rel)] = float(best.faith.get(str(rel), 0.0)) + 0.25
		Faith._normalize(best)
	w.add_log("%s conquiert %s" % [w.peoples[winner].name, best.name], "Rapport de forces écrasant (%s) ; %s garde sa population (%s)" % ["guerre de religion" if str(r.get("war_cause", "")) == "religion" else "guerre", best.name, w.cat.species[str(best.get("species", w.peoples[loser].species))].name], "war", int(best.cell))
	w.peoples[winner].history.append({"year": w.year, "text": "Conquête de %s." % best.name})

static func _peace(w, a: int, b: int, r: Dictionary, ma: float, mb: float) -> void:
	r.war = false
	r.value = -0.1
	r.pact_until = w.year + 10
	var winner := a if ma >= mb else b
	var loser := b if winner == a else a
	var ratio := maxf(ma, mb) / maxf(minf(ma, mb), 0.1)
	var why := "Épuisement de la guerre ; avantage à %s (forces %.0f contre %.0f)" % [w.peoples[winner].name, maxf(ma, mb), minf(ma, mb)]
	if ratio > 1.3 and not w.people_settlements(loser).is_empty():
		r.tribute = {"payer": loser, "receiver": winner, "until": w.year + TRIBUTE_YEARS, "rate": 0.06}
		why += " ; %s paiera un tribut pendant %d ans" % [w.peoples[loser].name, TRIBUTE_YEARS]
	w.add_log("Paix entre %s et %s" % [w.peoples[a].name, w.peoples[b].name], why, "war", int(w.peoples[a].origin_cell))

## Tributs : une part des réserves de nourriture du perdant passe au vainqueur chaque année.
static func _tributes(w) -> void:
	for k in w.relations:
		var r: Dictionary = w.relations[k]
		var t: Dictionary = r.get("tribute", {})
		if t.is_empty():
			continue
		if int(t.until) < w.year:
			r.tribute = {}
			continue
		var paid := 0.0
		for s in w.people_settlements(int(t.payer)):
			var x := float(s.food) * float(t.rate)
			s.food = float(s.food) - x
			paid += x
		var rec: Array = w.people_settlements(int(t.receiver))
		if rec.size() > 0:
			rec[0].food = float(rec[0].food) + paid

## Commerce : les vivres circulent vers les établissements en famine des partenaires.
static func _trade_effects(w) -> void:
	for k in w.relations:
		var r: Dictionary = w.relations[k]
		if not r.get("trade", false) or r.war:
			continue
		var parts: PackedStringArray = k.split(":")
		for pair in [[int(parts[0]), int(parts[1])], [int(parts[1]), int(parts[0])]]:
			var needy := []
			for s in w.people_settlements(pair[0]):
				if s.statuses.has("famine"):
					needy.append(s)
			if needy.is_empty():
				continue
			for donor in w.people_settlements(pair[1]):
				var surplus := float(donor.food) - float(donor.pop) * 1.0
				if surplus <= 0.0:
					continue
				var gift := surplus * 0.2
				donor.food = float(donor.food) - gift
				needy[0].food = float(needy[0].food) + gift
				w.add_log("%s envoie des vivres à %s" % [donor.name, needy[0].name], "Accord commercial entre %s et %s ; famine à %s" % [w.peoples[pair[1]].name, w.peoples[pair[0]].name, needy[0].name], "diplomacy", int(needy[0].cell))
				break

## Fusion : petit peuple allié de longue date, de même foi, absorbé par son allié : royaume multi-espèces.
static func _mergers(w) -> void:
	if w.year % 10 != 0:
		return
	for k in w.relations.keys():
		var r: Dictionary = w.relations[k]
		if not r.alliance or float(r.value) < 0.85 or w.year - int(r.get("allied_since", w.year)) < 30:
			continue
		var parts: PackedStringArray = k.split(":")
		var a := int(parts[0])
		var b := int(parts[1])
		if Civ._main_religion(w, a) != Civ._main_religion(w, b):
			continue
		var popa: float = w.people_pop(a)
		var popb: float = w.people_pop(b)
		var big := a if popa >= popb else b
		var small := b if big == a else a
		if minf(popa, popb) > maxf(popa, popb) / 3.0 or w.people_settlements(small).is_empty():
			continue
		var n: int = w.people_settlements(small).size()
		for s in w.people_settlements(small).duplicate():
			s.people = big
			w.tick_cache.erase("st%d" % int(s.id))
		w.invalidate_settlements()
		w.peoples[small].extinct = true
		w.peoples[small]["merged_into"] = big
		w.peoples[big].history.append({"year": w.year, "text": "Union avec %s : royaume de plusieurs espèces." % w.peoples[small].name})
		if str(w.peoples[big].polity) == "Tribu" or str(w.peoples[big].polity) == "Chefferie":
			w.peoples[big].polity = "Royaume"
		w.add_log("Union : %s rejoint %s" % [w.peoples[small].name, w.peoples[big].name], "Alliance de %d ans, même foi, relation %.2f ; %d établissement(s) réunis" % [w.year - int(r.allied_since), float(r.value), n], "politics", int(w.peoples[big].origin_cell))
		r.alliance = false
		r.trade = false

# ------------------------------------------------------------------ Diplomatie divine

## Le joueur propose un pacte à un dieu rival. Retourne {ok, msg}.
static func propose_pact(w, from_id: int, to_id: int) -> Dictionary:
	var a: Dictionary = w.deities[from_id]
	var b: Dictionary = w.deities[to_id]
	if not a.has("pacts"):
		a["pacts"] = {}
	if not b.has("pacts"):
		b["pacts"] = {}
	if a.pacts.has(str(to_id)):
		return {"ok": false, "msg": "Un pacte existe déjà."}
	var cost := 5.0
	if float(a.energy) < cost:
		return {"ok": false, "msg": "Il faut %.0f énergie pour présenter une offrande." % cost}
	a.energy = float(a.energy) - cost
	var rel := float(b.relations.get(str(from_id), 0.0))
	var chance := clampf(0.45 + rel * 0.6 + float(b.personality.benevolence) * 0.3 - float(b.personality.aggression) * 0.35, 0.05, 0.95)
	if w.rng.randf() < chance:
		a.pacts[str(to_id)] = w.year
		b.pacts[str(from_id)] = w.year
		a.relations[str(to_id)] = clampf(rel + 0.3, -1.0, 1.0)
		b.relations[str(from_id)] = a.relations[str(to_id)]
		w.add_log("Pacte divin : %s et %s" % [a.name, b.name], "Offrande acceptée (chance %.0f %%) ; leurs peuples se rapprochent" % (chance * 100.0), "diplomacy", -1)
		return {"ok": true, "msg": "%s accepte le pacte (chance %.0f %%)." % [b.name, chance * 100.0]}
	a.relations[str(to_id)] = clampf(rel - 0.05, -1.0, 1.0)
	b.relations[str(from_id)] = a.relations[str(to_id)]
	return {"ok": false, "msg": "%s refuse (chance %.0f %%). L'offrande est perdue." % [b.name, chance * 100.0]}

static func break_pact(w, from_id: int, to_id: int) -> void:
	var a: Dictionary = w.deities[from_id]
	var b: Dictionary = w.deities[to_id]
	a.get("pacts", {}).erase(str(to_id))
	b.get("pacts", {}).erase(str(from_id))
	var v := clampf(float(a.relations.get(str(to_id), 0.0)) - 0.5, -1.0, 1.0)
	a.relations[str(to_id)] = v
	b.relations[str(from_id)] = v
	w.add_log("Pacte rompu : %s trahit %s" % [a.name, b.name], "Rupture unilatérale ; relation %.2f" % v, "diplomacy", -1)
