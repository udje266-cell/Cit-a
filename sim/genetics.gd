extends RefCounted
## Hérédité agrégée : chaque établissement porte des fréquences (0–1) de traits héréditaires.
## Les traits acquis appartiennent à la culture du peuple ; les traits temporaires sont des statuts.
## Les affinités Magie/Épée ne passent JAMAIS par ce module (voir affinity.gd).

const SELECTION_RATE := 0.35
const MUTATION_BASE := 0.08       # probabilité par génération et par établissement
const MUTATION_START_FREQ := 0.03
const LOST_THRESHOLD := 0.005

## Fréquences initiales à partir des traits des deux fondateurs (présent chez les deux = 1, chez un seul = 0,5).
static func founders_to_freqs(founder_traits: Array) -> Dictionary:
	var freqs := {}
	var n := float(founder_traits.size())
	for f in founder_traits:
		for t in f:
			freqs[t] = freqs.get(t, 0.0) + 1.0 / n
	return freqs

## Statistiques effectives : base de l'espèce + traits héréditaires (pondérés) + culture + statuts temporaires.
static func effective_stats(cat, species_id: String, freqs: Dictionary, culture: Dictionary, statuses: Dictionary) -> Dictionary:
	var st := {}
	var base: Dictionary = cat.species[species_id].base
	for s in cat.stats:
		st[s] = float(base.get(s, 0.4))
	for t in freqs:
		if not cat.traits.has(t):
			continue
		var f := float(freqs[t])
		var fx: Dictionary = cat.traits[t].fx
		for s in fx:
			st[s] = st.get(s, 0.0) + float(fx[s]) * f
	for t in culture:
		if not cat.traits.has(t):
			continue
		var fx2: Dictionary = cat.traits[t].fx
		for s in fx2:
			st[s] = st.get(s, 0.0) + float(fx2[s]) * float(culture[t])
	for k in statuses:
		if cat.temporary.has(k):
			var fx3: Dictionary = cat.temporary[k].fx
			for s in fx3:
				st[s] = st.get(s, 0.0) + float(fx3[s])
	for s in st:
		st[s] = clampf(st[s], 0.0, 1.5)
	return st

## Pression de sélection du milieu : pour chaque statistique, à quel point elle aide à survivre ici.
static func environment_pressure(planet, cell: int, crowding: float, famine: bool) -> Dictionary:
	var t: float = planet.temperature[cell]
	var b: String = planet.biome_name(cell)
	var env := {
		"cold": maxf(0.0, 0.45 - t) * 2.0,
		"heat": maxf(0.0, t - 0.7) * 2.5,
		"aqua": 0.6 if planet.is_coastal(cell) else 0.0,
		"forest": 0.6 if b in ["taiga", "temperate_forest", "rainforest"] else 0.0,
		"mount": 0.8 if b in ["mountain", "snow_peak"] else 0.0,
		"desert": 0.8 if b == "desert" else 0.0,
		"food": 0.3 + (0.8 if famine else 0.0) + maxf(0.0, crowding - 0.8),
		"end": 0.2 + (0.5 if famine else 0.0),
		"disease": maxf(0.0, crowding - 0.5) * 0.6,
		"fert": 0.15,
		"coop": 0.1,
	}
	return env

static func trait_fitness(cat, trait_id: String, env: Dictionary) -> float:
	var fx: Dictionary = cat.traits[trait_id].fx
	var f := 0.0
	for s in fx:
		f += float(fx[s]) * env.get(s, 0.0)
	return f

## Une génération. Retourne la liste des changements notables : [{type, trait, freq}].
static func generation_step(cat, freqs: Dictionary, env: Dictionary, pop: float, rng: RandomNumberGenerator, intensity: float = 1.0) -> Array:
	var events := []
	var n_eff := maxf(pop, 4.0)
	for t in freqs.keys():
		var f := float(freqs[t])
		var before := f
		# Sélection (logistique) + dérive génétique (plus forte dans les petites populations).
		f += SELECTION_RATE * intensity * trait_fitness(cat, t, env) * f * (1.0 - f)
		var sigma := sqrt(maxf(f * (1.0 - f), 0.0) / (2.0 * n_eff))
		f += rng.randfn(0.0, sigma)
		f = clampf(f, 0.0, 1.0)
		if f < LOST_THRESHOLD:
			freqs.erase(t)
			events.append({"type": "lost", "trait": t, "freq": 0.0})
			continue
		freqs[t] = f
		if before < 0.5 and f >= 0.5:
			events.append({"type": "dominant", "trait": t, "freq": f})
	# Mutation : apparition d'un trait héréditaire absent, pondérée par sa rareté.
	if rng.randf() < MUTATION_BASE * intensity * clampf(pop / 200.0, 0.3, 2.0):
		var t2 := pick_mutation(cat, freqs, rng)
		if t2 != "":
			freqs[t2] = MUTATION_START_FREQ
			events.append({"type": "mutation", "trait": t2, "freq": MUTATION_START_FREQ})
	enforce_incompat(cat, freqs)
	return events

static func pick_mutation(cat, freqs: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	var pool := []
	for t in cat.trait_order:
		var tr: Dictionary = cat.traits[t]
		if tr.kind != "heritable" or freqs.has(t) or float(tr.rarity) <= 0.0:
			continue
		pool.append(t)
		total += float(tr.rarity)
	if pool.is_empty():
		return ""
	var r := rng.randf() * total
	for t in pool:
		r -= float(cat.traits[t].rarity)
		if r <= 0.0:
			return t
	return pool[pool.size() - 1]

## Deux traits incompatibles ne coexistent pas chez un même individu : leurs fréquences somment au plus à 1.
static func enforce_incompat(cat, freqs: Dictionary) -> void:
	for a in freqs.keys():
		if not freqs.has(a):
			continue
		for b in cat.traits[a].get("incompat", []):
			if freqs.has(b):
				var s := float(freqs[a]) + float(freqs[b])
				if s > 1.0:
					freqs[a] = float(freqs[a]) / s
					freqs[b] = float(freqs[b]) / s

## Copie avec effet fondateur (petite population qui part fonder ailleurs).
static func founder_effect(freqs: Dictionary, rng: RandomNumberGenerator, strength: float = 0.08) -> Dictionary:
	var out := {}
	for t in freqs:
		var f := clampf(float(freqs[t]) + rng.randf_range(-strength, strength), 0.0, 1.0)
		if f >= LOST_THRESHOLD:
			out[t] = f
	return out

## Individus représentatifs tirés de la distribution (affichage uniquement, non simulés).
static func representatives(cat, s: Dictionary, species_id: String, count: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := []
	var aff: Dictionary = s.aff
	var total := maxf(float(aff.none) + float(aff.magic) + float(aff.sword) + float(aff.both), 1.0)
	var longevity := float(cat.species[species_id].longevity)
	for i in count:
		var traits := []
		var keys: Array = s.freqs.keys()
		keys.sort()
		for t in keys:
			if rng.randf() < float(s.freqs[t]):
				var ok := true
				for o in traits:
					if cat.incompatible(t, o):
						ok = false
				if ok:
					traits.append(t)
		var r := rng.randf() * total
		var a := "none"
		for k in ["both", "magic", "sword", "none"]:
			r -= float(aff[k])
			if r <= 0.0:
				a = k
				break
		# Origine de l'affinité, tirée des comptes réels de l'établissement (naturelle, règle, ordre, don).
		var origin := ""
		if a != "none" and s.has("aff_src"):
			var srcs: Dictionary = s.aff_src.get(a, {})
			var tot := 0.0
			for k in srcs:
				tot += maxf(float(srcs[k]), 0.0)
			var r2 := rng.randf() * tot
			for k in srcs:
				r2 -= maxf(float(srcs[k]), 0.0)
				if r2 <= 0.0 and tot > 0.0:
					origin = k
					break
		out.append({"name": make_name(rng, species_id), "age": int(rng.randf_range(0.05, 0.8) * longevity),
			"traits": traits, "affinity": a, "origin": origin,
			"mastery_magic": float(s.mastery.magic) * rng.randf_range(0.5, 1.3) if a in ["magic", "both"] else 0.0,
			"mastery_sword": float(s.mastery.sword) * rng.randf_range(0.5, 1.3) if a in ["sword", "both"] else 0.0,
			"weapon_training": float(s.training) * rng.randf_range(0.5, 1.3)})
	return out

const SYLLABLES := {
	"sylvain": ["ae", "lin", "thal", "wen", "ys", "ra", "fel", "ith", "or"],
	"terragne": ["dur", "grom", "ka", "bor", "thun", "ak", "rim", "dok", "gar"],
	"ondin": ["ma", "lu", "ne", "oa", "ri", "sel", "wa", "qui", "na"],
	"cendre": ["zar", "ka", "ish", "ru", "tah", "sar", "ek", "mo", "ra"],
	"givrin": ["ska", "vel", "nor", "hil", "da", "frey", "is", "ka", "ul"],
	"vivace": ["pip", "ti", "lo", "mi", "bo", "zi", "ka", "nu", "pa"],
}

static func make_name(rng: RandomNumberGenerator, species_id: String) -> String:
	var syl: Array = SYLLABLES.get(species_id, SYLLABLES.vivace)
	var n := rng.randi_range(2, 3)
	var s := ""
	for i in n:
		s += syl[rng.randi_range(0, syl.size() - 1)]
	return s.capitalize()
