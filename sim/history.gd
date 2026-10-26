extends RefCounted
## Séries historiques pour les graphiques : population, affinités et traits par peuple, fidèles par dieu.
## Échantillon tous les STEP ans ; au-delà de MAX points, on garde un point sur deux (l'intervalle double).

const STEP := 5
const MAX := 240
const TOP_TRAITS := 6

static func empty() -> Dictionary:
	return {"step": STEP, "years": [], "peoples": {}, "deities": {}}

static func tick(w) -> void:
	var h: Dictionary = w.series
	if w.year % int(h.step) != 0:
		return
	h.years.append(w.year)
	var n: int = h.years.size()
	for p in w.peoples:
		var key := str(int(p.id))
		if p.extinct and not h.peoples.has(key):
			continue
		if not h.peoples.has(key):
			h.peoples[key] = {"pop": [], "magic": [], "sword": [], "traits": {}, "start": n - 1}
		var ps: Dictionary = h.peoples[key]
		var pop := 0.0
		var mg := 0.0
		var sw := 0.0
		var tf := {}
		for s in w.people_settlements(int(p.id)):
			var sp := float(s.pop)
			pop += sp
			mg += float(s.aff.magic) + float(s.aff.both)
			sw += float(s.aff.sword) + float(s.aff.both)
			for t in s.freqs:
				tf[t] = float(tf.get(t, 0.0)) + float(s.freqs[t]) * sp
		ps.pop.append(snappedf(pop, 0.1))
		ps.magic.append(snappedf(mg / maxf(pop, 1.0), 0.001))
		ps.sword.append(snappedf(sw / maxf(pop, 1.0), 0.001))
		# Traits suivis : déjà suivis + les plus fréquents actuels.
		var ranked: Array = tf.keys()
		ranked.sort_custom(func(a, b): return tf[a] > tf[b])
		for t in ranked.slice(0, TOP_TRAITS):
			if not ps.traits.has(t):
				ps.traits[t] = {"start": ps.pop.size() - 1, "v": []}
		for t in ps.traits:
			ps.traits[t].v.append(snappedf(float(tf.get(t, 0.0)) / maxf(pop, 1.0), 0.001))
	for d in w.deities:
		var dk := str(int(d.id))
		if not h.deities.has(dk):
			h.deities[dk] = {"start": n - 1, "v": []}
		h.deities[dk].v.append(int(d.believers))
	if n > MAX:
		_halve(h)

static func _keep_even(a: Array, start: int) -> Array:
	var out := []
	for i in a.size():
		if (start + i) % 2 == 0:
			out.append(a[i])
	return out

static func _halve(h: Dictionary) -> void:
	h.years = _keep_even(h.years, 0)
	h.step = int(h.step) * 2
	for k in h.peoples:
		var ps: Dictionary = h.peoples[k]
		var st := int(ps.start)
		for f in ["pop", "magic", "sword"]:
			ps[f] = _keep_even(ps[f], st)
		for t in ps.traits:
			var tr: Dictionary = ps.traits[t]
			tr.v = _keep_even(tr.v, st + int(tr.start))
			tr.start = int(ceil(float(st + int(tr.start)) / 2.0)) - int(ceil(float(st) / 2.0))
		ps.start = int(ceil(float(st) / 2.0))
	for k in h.deities:
		var ds: Dictionary = h.deities[k]
		ds.v = _keep_even(ds.v, int(ds.start))
		ds.start = int(ceil(float(ds.start) / 2.0))

## Arbre des peuples : liste [{id, depth, text}] (filiation par scission, unions signalées).
static func lineage(w) -> Array:
	var out := []
	for p in w.peoples:
		if int(p.get("parent", -1)) < 0:
			_walk(w, int(p.id), 0, out)
	return out

static func _walk(w, pid: int, depth: int, out: Array) -> void:
	var p: Dictionary = w.peoples[pid]
	var tag := ""
	if int(p.get("merged_into", -1)) >= 0:
		tag = " → uni à %s" % w.peoples[int(p.merged_into)].name
	elif p.extinct:
		tag = " † disparu"
	out.append({"id": pid, "depth": depth, "text": "%s (%s, an %d)%s" % [p.name, w.cat.species[p.species].name, int(p.founded), tag]})
	for c in w.peoples:
		if int(c.get("parent", -1)) == pid:
			_walk(w, int(c.id), depth + 1, out)
