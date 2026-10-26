extends RefCounted
## Bibliothèque d'objets low poly : végétation, rochers, bâtiments par espèce et par époque, bannières, habitants.
## Tous les maillages ont leur base en y = 0 et une hauteur d'environ 1 (mis à l'échelle à l'instanciation).

const LowPoly = preload("res://game/lowpoly.gd")

const PROPS := ["conifer", "conifer_b", "broadleaf", "broadleaf_b", "palm", "acacia", "bush", "rock", "rock_b", "cactus", "snow_conifer"]

## Style architectural par espèce : matériaux des murs, forme générale, forme de bannière.
const STYLES := {
	"sylvain": {"wall": Color(0.55, 0.36, 0.2), "roof": Color(0.62, 0.3, 0.2), "shape": "round", "flag": "pennant"},
	"terragne": {"wall": Color(0.62, 0.6, 0.57), "roof": Color(0.36, 0.38, 0.46), "shape": "flat", "flag": "square"},
	"ondin": {"wall": Color(0.86, 0.92, 0.96), "roof": Color(0.18, 0.5, 0.58), "shape": "stilts", "flag": "swallow"},
	"cendre": {"wall": Color(0.86, 0.62, 0.38), "roof": Color(0.78, 0.4, 0.22), "shape": "adobe", "flag": "pennant"},
	"givrin": {"wall": Color(0.93, 0.97, 1.0), "roof": Color(0.55, 0.75, 0.95), "shape": "dome", "flag": "square"},
	"vivace": {"wall": Color(0.95, 0.88, 0.7), "roof": Color(0.86, 0.66, 0.3), "shape": "cottage", "flag": "swallow"},
}

var _cache := {}

func prop_mesh(kind: String) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var b := LowPoly.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var trunk := Color(0.45, 0.3, 0.18)
	match kind:
		"conifer":
			b.prism(LowPoly.T(Vector3.ZERO), 0.07, 0.05, 0.3, 4, trunk)
			b.prism(LowPoly.T(Vector3(0, 0.22, 0)), 0.38, 0.0, 0.5, 6, Color(0.16, 0.48, 0.3))
			b.prism(LowPoly.T(Vector3(0, 0.5, 0)), 0.28, 0.0, 0.5, 6, Color(0.2, 0.56, 0.33))
		"conifer_b":
			b.prism(LowPoly.T(Vector3.ZERO), 0.06, 0.05, 0.25, 4, trunk)
			b.prism(LowPoly.T(Vector3(0, 0.18, 0)), 0.3, 0.0, 0.82, 5, Color(0.12, 0.42, 0.28))
		"snow_conifer":
			b.prism(LowPoly.T(Vector3.ZERO), 0.06, 0.05, 0.25, 4, trunk)
			b.prism(LowPoly.T(Vector3(0, 0.18, 0)), 0.34, 0.0, 0.48, 6, Color(0.2, 0.42, 0.34))
			b.prism(LowPoly.T(Vector3(0, 0.46, 0)), 0.24, 0.0, 0.48, 6, Color(0.92, 0.96, 1.0))
		"broadleaf":
			b.prism(LowPoly.T(Vector3.ZERO), 0.07, 0.05, 0.42, 5, trunk)
			b.blob(LowPoly.T(Vector3(0, 0.62, 0), Vector3(0.34, 0.3, 0.34)), Color(0.36, 0.7, 0.28), 0, 0.12, rng)
		"broadleaf_b":
			b.prism(LowPoly.T(Vector3.ZERO), 0.07, 0.05, 0.38, 5, trunk)
			b.blob(LowPoly.T(Vector3(0.06, 0.55, 0), Vector3(0.3, 0.26, 0.3)), Color(0.28, 0.6, 0.22), 0, 0.15, rng)
			b.blob(LowPoly.T(Vector3(-0.1, 0.7, 0.05), Vector3(0.22, 0.2, 0.22)), Color(0.4, 0.74, 0.3), 0, 0.15, rng)
		"palm":
			for i in 4:
				b.prism(LowPoly.T(Vector3(i * 0.03, i * 0.2, 0)), 0.05, 0.045, 0.2, 4, trunk.lightened(0.1))
			for k in 5:
				var a := TAU * k / 5.0
				var dir := Vector3(cos(a), 0, sin(a))
				var tip := Vector3(0.12, 0.8, 0) + dir * 0.42 + Vector3(0, -0.15, 0)
				var base := Vector3(0.12, 0.82, 0)
				var side := dir.cross(Vector3.UP) * 0.09
				b.tri(base - side, tip, base + side, Color(0.28, 0.66, 0.24))
				b.tri(base + side, tip, base - side, Color(0.24, 0.58, 0.2))
		"acacia":
			b.prism(LowPoly.T(Vector3.ZERO), 0.05, 0.035, 0.5, 4, trunk)
			b.prism(LowPoly.T(Vector3(0, 0.48, 0)), 0.42, 0.3, 0.14, 7, Color(0.46, 0.6, 0.22))
		"bush":
			b.blob(LowPoly.T(Vector3(0, 0.15, 0), Vector3(0.3, 0.2, 0.3)), Color(0.34, 0.6, 0.26), 0, 0.15, rng)
		"rock":
			b.blob(LowPoly.T(Vector3(0, 0.12, 0), Vector3(0.42, 0.3, 0.36)), Color(0.55, 0.52, 0.5), 0, 0.25, rng)
		"rock_b":
			b.blob(LowPoly.T(Vector3(0, 0.25, 0), Vector3(0.3, 0.5, 0.28)), Color(0.5, 0.47, 0.46), 0, 0.3, rng)
			b.blob(LowPoly.T(Vector3(0.28, 0.1, 0.05), Vector3(0.18, 0.16, 0.16)), Color(0.58, 0.55, 0.52), 0, 0.2, rng)
		"cactus":
			b.prism(LowPoly.T(Vector3.ZERO), 0.08, 0.07, 0.7, 6, Color(0.32, 0.6, 0.3))
			b.prism(LowPoly.T(Vector3(0.13, 0.3, 0)), 0.05, 0.045, 0.25, 5, Color(0.3, 0.56, 0.28))
	var m := b.to_mesh()
	_cache[kind] = m
	return m

# ------------------------------------------------------------------ Architecture

## Maison ordinaire d'un peuple à une époque donnée. roof = couleur du peuple (identité).
func house_mesh(species: String, era: int, roof: Color, lean: float) -> ArrayMesh:
	var key := "house_%s_%d_%s_%d" % [species, era, roof.to_html(false), int(sign(lean))]
	if _cache.has(key):
		return _cache[key]
	var st: Dictionary = STYLES.get(species, STYLES.vivace)
	var wall: Color = st.wall
	var people_col := roof
	# Toit : matériau de l'espèce légèrement teinté ; la couleur du peuple est portée par un bandeau.
	roof = (st.roof as Color).lerp(people_col, 0.25)
	var b := LowPoly.new()
	var storeys := 1.0 if era < 3 else 1.7
	b.prism(LowPoly.T(Vector3(0, 0.02, 0)), 0.5, 0.5, 0.07, 8, people_col, false)
	match str(st.shape):
		"round":
			if era == 0:
				b.prism(LowPoly.T(Vector3.ZERO), 0.45, 0.45, 0.35, 7, wall)
				b.prism(LowPoly.T(Vector3(0, 0.35, 0)), 0.55, 0.0, 0.5, 7, roof)
			else:
				b.prism(LowPoly.T(Vector3.ZERO), 0.42, 0.4, 0.5 * storeys, 7, wall)
				b.prism(LowPoly.T(Vector3(0, 0.5 * storeys, 0)), 0.55, 0.0, 0.6, 7, roof)
		"flat":
			if era == 0:
				b.box(LowPoly.T(Vector3.ZERO), Vector3(0.8, 0.35, 0.7), wall)
				b.box(LowPoly.T(Vector3(0, 0.35, 0)), Vector3(0.9, 0.08, 0.8), roof)
			else:
				b.box(LowPoly.T(Vector3.ZERO), Vector3(0.8, 0.55 * storeys, 0.75), wall)
				b.box(LowPoly.T(Vector3(0, 0.55 * storeys, 0)), Vector3(0.9, 0.1, 0.85), roof)
				b.box(LowPoly.T(Vector3(0.25, 0.55 * storeys, 0.2)), Vector3(0.14, 0.3, 0.14), wall.darkened(0.2))
		"stilts":
			for p in [Vector3(-0.3, 0, -0.3), Vector3(0.3, 0, -0.3), Vector3(0.3, 0, 0.3), Vector3(-0.3, 0, 0.3)]:
				b.prism(LowPoly.T(p), 0.04, 0.04, 0.25, 4, Color(0.45, 0.32, 0.2))
			b.box(LowPoly.T(Vector3(0, 0.25, 0)), Vector3(0.75, 0.4 * storeys, 0.75), wall)
			b.blob(LowPoly.T(Vector3(0, 0.25 + 0.4 * storeys, 0), Vector3(0.45, 0.3, 0.45)), roof)
		"adobe":
			b.box(LowPoly.T(Vector3.ZERO), Vector3(0.8, 0.5 * storeys, 0.8), wall, wall.lightened(0.1))
			if era >= 1:
				b.box(LowPoly.T(Vector3(0.2, 0.5 * storeys, -0.15)), Vector3(0.4, 0.3, 0.4), wall.lightened(0.05))
			b.box(LowPoly.T(Vector3(-0.42, 0.25, 0)), Vector3(0.06, 0.3, 0.3), roof)
		"dome":
			b.blob(LowPoly.T(Vector3(0, 0.0, 0), Vector3(0.5, 0.5 * storeys, 0.5)), wall, 1)
			b.box(LowPoly.T(Vector3(0.45, 0, 0)), Vector3(0.3, 0.28, 0.26), wall.darkened(0.08))
			b.prism(LowPoly.T(Vector3(0, 0.45 * storeys, 0)), 0.1, 0.0, 0.25, 5, roof)
		_:
			b.box(LowPoly.T(Vector3.ZERO), Vector3(0.7, 0.45 * storeys, 0.55), wall)
			b.gable(LowPoly.T(Vector3(0, 0.45 * storeys, 0)), Vector3(0.82, 0.45, 0.66), roof)
	# Époques avancées : la voie scientifique ajoute du métal, la voie magique des cristaux.
	if era >= 4:
		if lean >= 0.0:
			b.prism(LowPoly.T(Vector3(-0.25, 0.4, 0.2)), 0.08, 0.08, 0.7 * storeys, 6, Color(0.6, 0.64, 0.7))
		else:
			b.blob(LowPoly.T(Vector3(0, 0.8 * storeys + 0.3, 0), Vector3(0.12, 0.3, 0.12)), Color(0.75, 0.45, 1.0))
	if era >= 5:
		b.prism(LowPoly.T(Vector3(0, 0.6 * storeys, 0)), 0.18, 0.02, 1.2, 6, Color(0.9, 0.95, 1.0))
	var m := b.to_mesh()
	_cache[key] = m
	return m

## Bâtiment central : foyer (tribu), grande salle, temple (si rites/clergé) ou donjon (si fortifications).
func center_mesh(kind: String, species: String, era: int, roof: Color) -> ArrayMesh:
	var key := "center_%s_%s_%d_%s" % [kind, species, era, roof.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var st: Dictionary = STYLES.get(species, STYLES.vivace)
	var wall: Color = st.wall
	var b := LowPoly.new()
	match kind:
		"fire":
			for i in 6:
				var a := TAU * i / 6.0
				b.blob(LowPoly.T(Vector3(cos(a) * 0.25, 0.05, sin(a) * 0.25), Vector3(0.08, 0.06, 0.08)), Color(0.5, 0.48, 0.46))
			b.prism(LowPoly.T(Vector3.ZERO), 0.15, 0.0, 0.4, 5, Color(1.0, 0.55, 0.15))
		"hall":
			b.box(LowPoly.T(Vector3.ZERO), Vector3(1.2, 0.6, 0.8), wall)
			b.gable(LowPoly.T(Vector3(0, 0.6, 0)), Vector3(1.35, 0.55, 0.95), roof)
		"temple":
			b.box(LowPoly.T(Vector3.ZERO), Vector3(1.1, 0.12, 1.1), wall.lightened(0.2))
			for p in [Vector3(-0.4, 0.12, -0.4), Vector3(0.4, 0.12, -0.4), Vector3(0.4, 0.12, 0.4), Vector3(-0.4, 0.12, 0.4)]:
				b.prism(LowPoly.T(p), 0.07, 0.07, 0.6, 6, Color(0.95, 0.93, 0.85))
			b.box(LowPoly.T(Vector3(0, 0.72, 0)), Vector3(1.0, 0.1, 1.0), Color(0.95, 0.93, 0.85))
			b.prism(LowPoly.T(Vector3(0, 0.82, 0)), 0.55, 0.0, 0.45, 4, Color(1.0, 0.8, 0.3))
		"keep":
			b.box(LowPoly.T(Vector3.ZERO), Vector3(0.7, 1.4, 0.7), Color(0.66, 0.64, 0.6))
			for p in [Vector3(-0.3, 1.4, -0.3), Vector3(0.3, 1.4, -0.3), Vector3(0.3, 1.4, 0.3), Vector3(-0.3, 1.4, 0.3)]:
				b.box(LowPoly.T(p), Vector3(0.16, 0.16, 0.16), Color(0.66, 0.64, 0.6))
			b.prism(LowPoly.T(Vector3(0, 1.4, 0)), 0.3, 0.0, 0.5, 4, roof)
		"spire":
			b.prism(LowPoly.T(Vector3.ZERO), 0.45, 0.2, 0.5, 8, Color(0.85, 0.9, 0.95))
			b.prism(LowPoly.T(Vector3(0, 0.5, 0)), 0.2, 0.02, 2.0, 8, Color(0.92, 0.96, 1.0))
			b.blob(LowPoly.T(Vector3(0, 1.4, 0), Vector3(0.35, 0.08, 0.35)), roof)
	var m := b.to_mesh()
	_cache[key] = m
	return m

## Bannière : mât + étendard aux couleurs du peuple, forme propre à l'espèce, emblème aux couleurs du dieu.
func banner_mesh(species: String, people_col: Color, deity_col: Color) -> ArrayMesh:
	var key := "banner_%s_%s_%s" % [species, people_col.to_html(false), deity_col.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var b := LowPoly.new()
	b.prism(LowPoly.T(Vector3.ZERO), 0.03, 0.03, 1.0, 4, Color(0.35, 0.25, 0.15))
	var shape: String = STYLES.get(species, STYLES.vivace).flag
	var top := Vector3(0.03, 0.95, 0)
	match shape:
		"pennant":
			b.tri(top, top + Vector3(0.55, -0.12, 0), top + Vector3(0, -0.3, 0), people_col)
			b.tri(top, top + Vector3(0, -0.3, 0), top + Vector3(0.55, -0.12, 0), people_col)
		"square":
			b.quad(top, top + Vector3(0.45, 0, 0), top + Vector3(0.45, -0.32, 0), top + Vector3(0, -0.32, 0), people_col)
			b.quad(top + Vector3(0, -0.32, 0), top + Vector3(0.45, -0.32, 0), top + Vector3(0.45, 0, 0), top, people_col)
		_:
			# Queue d'aronde : deux pointes.
			var p0 := top
			var p1 := top + Vector3(0.5, 0, 0)
			var p2 := top + Vector3(0.3, -0.16, 0)
			var p3 := top + Vector3(0.5, -0.32, 0)
			var p4 := top + Vector3(0, -0.32, 0)
			for pair in [[p0, p1, p2], [p0, p2, p4], [p4, p2, p3]]:
				b.tri(pair[0], pair[1], pair[2], people_col)
				b.tri(pair[0], pair[2], pair[1], people_col)
	b.blob(LowPoly.T(top + Vector3(0.18, -0.16, 0.02), Vector3(0.07, 0.07, 0.03)), deity_col)
	b.blob(LowPoly.T(Vector3(0, 1.02, 0), Vector3(0.05, 0.05, 0.05)), Color(1.0, 0.85, 0.3))
	var m := b.to_mesh()
	_cache[key] = m
	return m

## Palissade (époques 0–1) ou muraille (2+) : un segment, répété en cercle.
func wall_mesh(stone: bool) -> ArrayMesh:
	var key := "wall_%s" % stone
	if _cache.has(key):
		return _cache[key]
	var b := LowPoly.new()
	if stone:
		b.box(LowPoly.T(Vector3.ZERO), Vector3(1.0, 0.45, 0.18), Color(0.62, 0.6, 0.56))
		b.box(LowPoly.T(Vector3(-0.3, 0.45, 0)), Vector3(0.2, 0.12, 0.2), Color(0.62, 0.6, 0.56))
		b.box(LowPoly.T(Vector3(0.3, 0.45, 0)), Vector3(0.2, 0.12, 0.2), Color(0.62, 0.6, 0.56))
	else:
		for i in 5:
			b.prism(LowPoly.T(Vector3(-0.4 + i * 0.2, 0, 0)), 0.06, 0.0, 0.45, 4, Color(0.5, 0.35, 0.2))
	var m := b.to_mesh()
	_cache[key] = m
	return m

## Habitant représentatif : corps aux couleurs du peuple ; épée pour l'affinité Épée, orbe violet pour Magie.
func figure_mesh(people_col: Color, affinity: String) -> ArrayMesh:
	var key := "fig_%s_%s" % [people_col.to_html(false), affinity]
	if _cache.has(key):
		return _cache[key]
	var b := LowPoly.new()
	b.prism(LowPoly.T(Vector3.ZERO), 0.22, 0.12, 0.62, 6, people_col)
	b.blob(LowPoly.T(Vector3(0, 0.78, 0), Vector3(0.15, 0.15, 0.15)), Color(0.95, 0.8, 0.65))
	if affinity in ["sword", "both"]:
		b.box(LowPoly.T(Vector3(0.24, 0.2, 0)), Vector3(0.05, 0.6, 0.05), Color(0.85, 0.88, 0.95))
		b.box(LowPoly.T(Vector3(0.24, 0.25, 0)), Vector3(0.16, 0.04, 0.05), Color(0.8, 0.6, 0.2))
	if affinity in ["magic", "both"]:
		b.blob(LowPoly.T(Vector3(-0.26, 0.62, 0), Vector3(0.1, 0.1, 0.1)), Color(0.75, 0.4, 1.0))
	var m := b.to_mesh()
	_cache[key] = m
	return m
