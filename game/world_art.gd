extends RefCounted
## Bibliothèque d'objets stylisés : végétation, rochers, famille architecturale par espèce, champs, bannières,
## habitants. Formes arrondies et lissées, palette limitée (voir docs/ART_DIRECTION.md).
## Tous les maillages ont leur base en y = 0 et une hauteur d'environ 1 (mis à l'échelle à l'instanciation).

const LowPoly = preload("res://game/lowpoly.gd")

const PROPS := ["broadleaf", "broadleaf_b", "conifer", "conifer_b", "snow_conifer", "palm", "acacia", "bush", "rock", "rock_b", "cactus", "field_wheat", "field_green"]

## Palette des objets (accordée à celle du terrain).
const TRUNK := Color(0.42, 0.31, 0.22)
const LEAF := Color(0.31, 0.53, 0.25)
const LEAF_LIGHT := Color(0.42, 0.62, 0.3)
const LEAF_DEEP := Color(0.21, 0.42, 0.24)
const NEEDLE := Color(0.18, 0.38, 0.27)
const NEEDLE_LIGHT := Color(0.24, 0.46, 0.31)
const SNOW := Color(0.93, 0.96, 1.0)
const ROCK := Color(0.53, 0.5, 0.46)
const ROCK_DARK := Color(0.45, 0.42, 0.39)

## Style architectural par espèce : murs, toits, boiseries, forme générale et bannière.
const STYLES := {
	"sylvain": {"wall": Color(0.82, 0.72, 0.56), "roof": Color(0.47, 0.33, 0.24), "trim": Color(0.42, 0.3, 0.2), "shape": "round", "flag": "pennant"},
	"terragne": {"wall": Color(0.72, 0.69, 0.64), "roof": Color(0.4, 0.42, 0.48), "trim": Color(0.48, 0.45, 0.42), "shape": "stone", "flag": "square"},
	"ondin": {"wall": Color(0.93, 0.92, 0.86), "roof": Color(0.27, 0.5, 0.56), "trim": Color(0.45, 0.36, 0.26), "shape": "stilts", "flag": "swallow"},
	"cendre": {"wall": Color(0.88, 0.74, 0.55), "roof": Color(0.74, 0.43, 0.29), "trim": Color(0.6, 0.42, 0.3), "shape": "adobe", "flag": "pennant"},
	"givrin": {"wall": Color(0.92, 0.94, 0.96), "roof": Color(0.56, 0.68, 0.8), "trim": Color(0.6, 0.66, 0.72), "shape": "dome", "flag": "square"},
	"vivace": {"wall": Color(0.94, 0.89, 0.76), "roof": Color(0.74, 0.4, 0.28), "trim": Color(0.48, 0.35, 0.24), "shape": "cottage", "flag": "swallow"},
}

var _cache := {}

func prop_mesh(kind: String) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var b := LowPoly.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		"broadleaf":
			b.smooth_prism(LowPoly.T(Vector3.ZERO), 0.07, 0.05, 0.42, 6, TRUNK)
			b.smooth_blob(LowPoly.T(Vector3(0, 0.66, 0), Vector3(0.36, 0.32, 0.36)), LEAF, 1)
			b.smooth_blob(LowPoly.T(Vector3(0.14, 0.84, 0.05), Vector3(0.22, 0.2, 0.22)), LEAF_LIGHT, 1)
		"broadleaf_b":
			b.smooth_prism(LowPoly.T(Vector3.ZERO), 0.07, 0.05, 0.5, 6, TRUNK)
			b.smooth_blob(LowPoly.T(Vector3(0, 0.78, 0), Vector3(0.3, 0.36, 0.3)), LEAF_DEEP, 1)
			b.smooth_blob(LowPoly.T(Vector3(-0.12, 0.62, 0.08), Vector3(0.2, 0.18, 0.2)), LEAF, 1)
		"conifer":
			b.smooth_prism(LowPoly.T(Vector3.ZERO), 0.06, 0.05, 0.22, 6, TRUNK)
			b.smooth_prism(LowPoly.T(Vector3(0, 0.16, 0)), 0.36, 0.0, 0.46, 8, NEEDLE)
			b.smooth_prism(LowPoly.T(Vector3(0, 0.42, 0)), 0.28, 0.0, 0.42, 8, NEEDLE_LIGHT)
			b.smooth_prism(LowPoly.T(Vector3(0, 0.66, 0)), 0.18, 0.0, 0.36, 8, NEEDLE)
		"conifer_b":
			b.smooth_prism(LowPoly.T(Vector3.ZERO), 0.05, 0.04, 0.2, 6, TRUNK)
			b.smooth_prism(LowPoly.T(Vector3(0, 0.14, 0)), 0.24, 0.0, 0.86, 8, NEEDLE)
		"snow_conifer":
			b.smooth_prism(LowPoly.T(Vector3.ZERO), 0.06, 0.05, 0.22, 6, TRUNK)
			b.smooth_prism(LowPoly.T(Vector3(0, 0.16, 0)), 0.34, 0.0, 0.46, 8, NEEDLE)
			b.smooth_prism(LowPoly.T(Vector3(0, 0.44, 0)), 0.25, 0.0, 0.4, 8, SNOW)
		"palm":
			for i in 4:
				b.smooth_prism(LowPoly.T(Vector3(i * 0.03, i * 0.19, 0)), 0.05, 0.045, 0.2, 5, TRUNK.lightened(0.12))
			for k in 6:
				var a := TAU * k / 6.0
				var dir := Vector3(cos(a), 0, sin(a))
				var base := Vector3(0.12, 0.8, 0)
				var tip := base + dir * 0.4 + Vector3(0, -0.14, 0)
				var side := dir.cross(Vector3.UP) * 0.08
				var up := Vector3.UP
				b.tri_n(base - side, tip, base + side, up, up, up, LEAF_LIGHT)
				b.tri_n(base + side, tip, base - side, -up, -up, -up, LEAF)
		"acacia":
			b.smooth_prism(LowPoly.T(Vector3.ZERO), 0.05, 0.035, 0.5, 6, TRUNK)
			b.smooth_blob(LowPoly.T(Vector3(0, 0.56, 0), Vector3(0.44, 0.12, 0.4)), Color(0.5, 0.58, 0.28), 1)
		"bush":
			b.smooth_blob(LowPoly.T(Vector3(0, 0.12, 0), Vector3(0.3, 0.2, 0.28)), LEAF, 1)
			b.smooth_blob(LowPoly.T(Vector3(0.2, 0.08, 0.1), Vector3(0.18, 0.13, 0.17)), LEAF_LIGHT, 1)
		"rock":
			b.smooth_blob(LowPoly.T(Vector3(0, 0.08, 0), Vector3(0.42, 0.26, 0.36)), ROCK, 1, 0.12, rng)
		"rock_b":
			b.smooth_blob(LowPoly.T(Vector3(0, 0.2, 0), Vector3(0.3, 0.42, 0.28)), ROCK_DARK, 1, 0.15, rng)
			b.smooth_blob(LowPoly.T(Vector3(0.28, 0.06, 0.05), Vector3(0.2, 0.15, 0.18)), ROCK, 1, 0.1, rng)
		"cactus":
			b.smooth_prism(LowPoly.T(Vector3.ZERO), 0.08, 0.07, 0.7, 8, Color(0.36, 0.56, 0.32))
			b.smooth_prism(LowPoly.T(Vector3(0.13, 0.3, 0)), 0.05, 0.045, 0.25, 6, Color(0.34, 0.53, 0.3))
		"plaza":
			var up := Vector3.UP
			for k in 16:
				var a0 := TAU * k / 16.0
				var a1 := TAU * (k + 1) / 16.0
				b.tri_n(Vector3(0, 0.01, 0), Vector3(cos(a0) * 0.5, 0.01, sin(a0) * 0.5), Vector3(cos(a1) * 0.5, 0.01, sin(a1) * 0.5), up, up, up, Color(0.7, 0.63, 0.5))
		"path":
			# Sentier : losange étiré aux extrémités adoucies.
			var up2 := Vector3.UP
			b.tri_n(Vector3(0, 0.01, -0.62), Vector3(0.5, 0.01, -0.5), Vector3(-0.5, 0.01, -0.5), up2, up2, up2, Color(0.64, 0.58, 0.42))
			b.tri_n(Vector3(0, 0.01, 0.62), Vector3(-0.5, 0.01, 0.5), Vector3(0.5, 0.01, 0.5), up2, up2, up2, Color(0.64, 0.58, 0.42))
			b.tri_n(Vector3(-0.5, 0.01, -0.5), Vector3(0.5, 0.01, -0.5), Vector3(0.5, 0.01, 0.5), up2, up2, up2, Color(0.64, 0.58, 0.42))
			b.tri_n(Vector3(-0.5, 0.01, -0.5), Vector3(0.5, 0.01, 0.5), Vector3(-0.5, 0.01, 0.5), up2, up2, up2, Color(0.64, 0.58, 0.42))
		"field_wheat", "field_green":
			# Parcelle cultivée : sillons alternés, posée à plat.
			var c1 := Color(0.86, 0.74, 0.42) if kind == "field_wheat" else Color(0.5, 0.66, 0.3)
			var c2 := c1.darkened(0.12)
			for r in 6:
				var z0 := -0.5 + r / 6.0
				var z1 := z0 + 1.0 / 6.0
				var col := c1 if r % 2 == 0 else c2
				var up := Vector3.UP
				b.tri_n(Vector3(-0.5, 0.02, z0), Vector3(0.5, 0.02, z0), Vector3(0.5, 0.02, z1), up, up, up, col)
				b.tri_n(Vector3(-0.5, 0.02, z0), Vector3(0.5, 0.02, z1), Vector3(-0.5, 0.02, z1), up, up, up, col)
	if kind in ["plaza", "path", "field_wheat", "field_green"]:
		_double_sided(b)
	var m := b.to_mesh()
	_cache[kind] = m
	return m

## Surfaces posées au sol : visibles quel que soit l'ordre des sommets.
func _double_sided(b) -> void:
	var n: int = b.verts.size()
	for i in range(0, n, 3):
		b.verts.append(b.verts[i]); b.verts.append(b.verts[i + 2]); b.verts.append(b.verts[i + 1])
		b.normals.append(b.normals[i]); b.normals.append(b.normals[i + 2]); b.normals.append(b.normals[i + 1])
		b.colors.append(b.colors[i]); b.colors.append(b.colors[i + 2]); b.colors.append(b.colors[i + 1])

# ------------------------------------------------------------------ Famille architecturale

## kind : house | production | cult | collective. era : 0–5. Couleur du peuple sur le bandeau et la bannière.
func building_mesh(kind: String, species: String, era: int, people_col: Color, lean: float) -> ArrayMesh:
	var key := "b_%s_%s_%d_%s_%d" % [kind, species, era, people_col.to_html(false), int(sign(lean))]
	if _cache.has(key):
		return _cache[key]
	var st: Dictionary = STYLES.get(species, STYLES.vivace)
	var wall: Color = st.wall
	var roof: Color = st.roof
	var trim: Color = st.trim
	var b := LowPoly.new()
	var tall := 1.0 if era < 3 else 1.5
	match kind:
		"house":
			_house(b, str(st.shape), wall, roof, trim, people_col, tall)
		"production":
			# Grenier rond et petit atelier (silhouette distincte : cylindre + cône).
			b.smooth_prism(LowPoly.T(Vector3(-0.15, 0, 0)), 0.32, 0.32, 0.62 * tall, 10, wall.darkened(0.06))
			b.smooth_prism(LowPoly.T(Vector3(-0.15, 0.62 * tall, 0)), 0.4, 0.0, 0.42, 10, roof)
			b.box(LowPoly.T(Vector3(0.3, 0, 0.05)), Vector3(0.42, 0.36, 0.4), wall)
			b.gable(LowPoly.T(Vector3(0.3, 0.36, 0.05)), Vector3(0.52, 0.24, 0.5), roof.darkened(0.08))
			b.box(LowPoly.T(Vector3(0.3, 0, 0.26)), Vector3(0.14, 0.2, 0.02), trim.darkened(0.3))
		"cult":
			# Lieu de culte : socle de pierre, colonnes, toit doré ; clocher à partir de l'âge des royaumes.
			b.box(LowPoly.T(Vector3.ZERO), Vector3(1.0, 0.12, 0.8), Color(0.78, 0.76, 0.7))
			for p in [Vector3(-0.38, 0.12, -0.28), Vector3(0.38, 0.12, -0.28), Vector3(0.38, 0.12, 0.28), Vector3(-0.38, 0.12, 0.28)]:
				b.smooth_prism(LowPoly.T(p), 0.06, 0.06, 0.5, 8, Color(0.94, 0.92, 0.86))
			b.box(LowPoly.T(Vector3(0, 0.12, 0)), Vector3(0.5, 0.42, 0.36), wall)
			b.box(LowPoly.T(Vector3(0, 0.62, 0)), Vector3(0.92, 0.08, 0.72), Color(0.9, 0.88, 0.82))
			b.gable(LowPoly.T(Vector3(0, 0.7, 0)), Vector3(1.0, 0.34, 0.8), Color(0.86, 0.66, 0.3))
			if era >= 2:
				b.box(LowPoly.T(Vector3(0, 0.7, -0.3)), Vector3(0.2, 0.55, 0.2), Color(0.9, 0.88, 0.82))
				b.smooth_prism(LowPoly.T(Vector3(0, 1.25, -0.3)), 0.16, 0.0, 0.32, 6, Color(0.86, 0.66, 0.3))
		"collective":
			# Grande halle : long volume, grand toit, porche et bandeau aux couleurs du peuple.
			b.box(LowPoly.T(Vector3.ZERO), Vector3(1.3, 0.48 * tall, 0.74), wall)
			b.box(LowPoly.T(Vector3(0, 0.38 * tall, 0)), Vector3(1.32, 0.07, 0.76), people_col)
			b.gable(LowPoly.T(Vector3(0, 0.48 * tall, 0)), Vector3(1.5, 0.5, 0.96), roof)
			b.box(LowPoly.T(Vector3(0, 0, 0.42)), Vector3(0.36, 0.3, 0.1), trim)
			b.box(LowPoly.T(Vector3(0, 0, 0.47)), Vector3(0.16, 0.24, 0.02), trim.darkened(0.35))
	# Époques avancées : métal (voie scientifique) ou cristal (voie magique).
	if era >= 4:
		if lean >= 0.0:
			b.smooth_prism(LowPoly.T(Vector3(-0.3, 0.3, 0.2)), 0.07, 0.07, 0.8 * tall, 8, Color(0.62, 0.65, 0.7))
		else:
			b.smooth_blob(LowPoly.T(Vector3(0, 0.9 * tall + 0.3, 0), Vector3(0.1, 0.26, 0.1)), Color(0.72, 0.5, 0.95), 0)
	if era >= 5:
		b.smooth_prism(LowPoly.T(Vector3(0, 0.6 * tall, 0)), 0.16, 0.02, 1.1, 8, Color(0.9, 0.94, 0.98))
	var m := b.to_mesh()
	_cache[key] = m
	return m

func _house(b, shape: String, wall: Color, roof: Color, trim: Color, people_col: Color, tall: float) -> void:
	match shape:
		"round":
			b.smooth_prism(LowPoly.T(Vector3.ZERO), 0.4, 0.38, 0.46 * tall, 10, wall)
			b.smooth_prism(LowPoly.T(Vector3(0, 0.36 * tall, 0)), 0.41, 0.41, 0.06, 10, people_col)
			b.smooth_prism(LowPoly.T(Vector3(0, 0.46 * tall, 0)), 0.52, 0.0, 0.5, 10, roof)
			b.box(LowPoly.T(Vector3(0, 0, 0.38)), Vector3(0.16, 0.26, 0.04), trim.darkened(0.3))
		"stone":
			b.box(LowPoly.T(Vector3.ZERO), Vector3(0.78, 0.5 * tall, 0.66), wall)
			b.box(LowPoly.T(Vector3(0, 0.42 * tall, 0)), Vector3(0.8, 0.06, 0.68), people_col)
			b.box(LowPoly.T(Vector3(0, 0.5 * tall, 0)), Vector3(0.88, 0.1, 0.76), roof)
			b.box(LowPoly.T(Vector3(0.24, 0.6 * tall, 0.18)), Vector3(0.14, 0.24, 0.14), trim)
			b.box(LowPoly.T(Vector3(0, 0, 0.34)), Vector3(0.16, 0.26, 0.02), trim.darkened(0.35))
		"stilts":
			for p in [Vector3(-0.28, 0, -0.26), Vector3(0.28, 0, -0.26), Vector3(0.28, 0, 0.26), Vector3(-0.28, 0, 0.26)]:
				b.smooth_prism(LowPoly.T(p), 0.04, 0.04, 0.22, 6, trim)
			b.box(LowPoly.T(Vector3(0, 0.22, 0)), Vector3(0.72, 0.38 * tall, 0.64), wall)
			b.box(LowPoly.T(Vector3(0, 0.52 * tall, 0)), Vector3(0.74, 0.05, 0.66), people_col)
			b.gable(LowPoly.T(Vector3(0, 0.22 + 0.38 * tall, 0)), Vector3(0.9, 0.36, 0.82), roof)
		"adobe":
			b.box(LowPoly.T(Vector3.ZERO), Vector3(0.78, 0.48 * tall, 0.74), wall, wall.lightened(0.06))
			b.box(LowPoly.T(Vector3(0.18, 0.48 * tall, -0.14)), Vector3(0.38, 0.26, 0.38), wall.lightened(0.04))
			b.box(LowPoly.T(Vector3(0, 0.4 * tall, 0)), Vector3(0.8, 0.05, 0.76), people_col)
			b.box(LowPoly.T(Vector3(0, 0, 0.38)), Vector3(0.18, 0.28, 0.02), trim.darkened(0.3))
		"dome":
			b.smooth_blob(LowPoly.T(Vector3.ZERO, Vector3(0.48, 0.46 * tall, 0.48)), wall, 1)
			b.smooth_prism(LowPoly.T(Vector3(0.42, 0, 0)), 0.16, 0.14, 0.24, 8, wall.darkened(0.05))
			b.smooth_prism(LowPoly.T(Vector3(0, 0.4 * tall, 0)), 0.1, 0.0, 0.2, 6, people_col)
		_:
			b.box(LowPoly.T(Vector3.ZERO), Vector3(0.72, 0.46 * tall, 0.56), wall)
			b.box(LowPoly.T(Vector3(0, 0.38 * tall, 0)), Vector3(0.74, 0.05, 0.58), people_col)
			b.gable(LowPoly.T(Vector3(0, 0.46 * tall, 0)), Vector3(0.88, 0.42, 0.72), roof)
			b.box(LowPoly.T(Vector3(0.22, 0.5 * tall, -0.1)), Vector3(0.1, 0.3, 0.1), trim)
			b.box(LowPoly.T(Vector3(0, 0, 0.29)), Vector3(0.14, 0.24, 0.02), trim.darkened(0.35))

## Bannière : mât + étendard aux couleurs du peuple, forme propre à l'espèce, emblème aux couleurs du dieu.
func banner_mesh(species: String, people_col: Color, deity_col: Color) -> ArrayMesh:
	var key := "banner_%s_%s_%s" % [species, people_col.to_html(false), deity_col.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var b := LowPoly.new()
	b.smooth_prism(LowPoly.T(Vector3.ZERO), 0.025, 0.02, 1.0, 6, Color(0.4, 0.3, 0.2))
	var shape: String = STYLES.get(species, STYLES.vivace).flag
	var top := Vector3(0.02, 0.95, 0)
	var pts: Array
	match shape:
		"pennant":
			pts = [[top, top + Vector3(0.55, -0.12, 0), top + Vector3(0, -0.3, 0)]]
		"square":
			pts = [[top, top + Vector3(0.45, 0, 0), top + Vector3(0.45, -0.32, 0)], [top, top + Vector3(0.45, -0.32, 0), top + Vector3(0, -0.32, 0)]]
		_:
			pts = [[top, top + Vector3(0.5, 0, 0), top + Vector3(0.3, -0.16, 0)], [top, top + Vector3(0.3, -0.16, 0), top + Vector3(0, -0.32, 0)],
				[top + Vector3(0, -0.32, 0), top + Vector3(0.3, -0.16, 0), top + Vector3(0.5, -0.32, 0)]]
	for p in pts:
		var n := Vector3.BACK
		b.tri_n(p[0], p[1], p[2], n, n, n, people_col)
		b.tri_n(p[0], p[2], p[1], -n, -n, -n, people_col.darkened(0.1))
	b.smooth_blob(LowPoly.T(top + Vector3(0.18, -0.16, 0.02), Vector3(0.07, 0.07, 0.03)), deity_col, 0)
	b.smooth_blob(LowPoly.T(Vector3(0, 1.02, 0), Vector3(0.05, 0.05, 0.05)), Color(0.92, 0.78, 0.36), 0)
	var m := b.to_mesh()
	_cache[key] = m
	return m

## Palissade (époques 0–1) ou muraille : un segment, répété en cercle.
func wall_mesh(stone: bool) -> ArrayMesh:
	var key := "wall_%s" % stone
	if _cache.has(key):
		return _cache[key]
	var b := LowPoly.new()
	if stone:
		b.box(LowPoly.T(Vector3.ZERO), Vector3(1.0, 0.42, 0.2), Color(0.7, 0.67, 0.62))
		b.box(LowPoly.T(Vector3(-0.3, 0.42, 0)), Vector3(0.22, 0.12, 0.22), Color(0.7, 0.67, 0.62))
		b.box(LowPoly.T(Vector3(0.3, 0.42, 0)), Vector3(0.22, 0.12, 0.22), Color(0.7, 0.67, 0.62))
	else:
		for i in 5:
			b.smooth_prism(LowPoly.T(Vector3(-0.4 + i * 0.2, 0, 0)), 0.06, 0.0, 0.42, 6, TRUNK.lightened(0.05))
	var m := b.to_mesh()
	_cache[key] = m
	return m

## Habitant représentatif : corps aux couleurs du peuple ; épée pour l'affinité Épée, orbe violet pour Magie.
func figure_mesh(people_col: Color, affinity: String) -> ArrayMesh:
	var key := "fig_%s_%s" % [people_col.to_html(false), affinity]
	if _cache.has(key):
		return _cache[key]
	var b := LowPoly.new()
	b.smooth_prism(LowPoly.T(Vector3.ZERO), 0.22, 0.12, 0.62, 8, people_col)
	b.smooth_blob(LowPoly.T(Vector3(0, 0.78, 0), Vector3(0.15, 0.15, 0.15)), Color(0.93, 0.8, 0.66), 1)
	if affinity in ["sword", "both"]:
		b.box(LowPoly.T(Vector3(0.24, 0.2, 0)), Vector3(0.05, 0.6, 0.05), Color(0.85, 0.88, 0.95))
		b.box(LowPoly.T(Vector3(0.24, 0.25, 0)), Vector3(0.16, 0.04, 0.05), Color(0.8, 0.62, 0.3))
	if affinity in ["magic", "both"]:
		b.smooth_blob(LowPoly.T(Vector3(-0.26, 0.62, 0), Vector3(0.1, 0.1, 0.1)), Color(0.72, 0.48, 0.95), 1)
	var m := b.to_mesh()
	_cache[key] = m
	return m
