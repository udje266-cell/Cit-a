extends Node3D
## Rendu de la planète — direction artistique « formes douces » (docs/ART_DIRECTION.md).
##
## La simulation reste une grille de cellules (sim/planet.gd). L'habillage est une surface lisse et partagée :
## chaque triangle de simulation est subdivisé (DETAIL² facettes), mais chaque sommet est unique sur toute
## la planète (clé par coin, arête ou intérieur). Pour chaque sommet :
##   1. hauteur brute interpolée des cellules + bruit de grande échelle ;
##   2. lissage sur le graphe des sommets (collines rondes, aucune trace de la grille) ;
##   3. terrasses courbes qui suivent la sphère (plateaux + contremarches épaisses) ;
##   4. aplanissement sous les villages ;
##   5. normales lissées (moyenne des faces voisines) ;
##   6. couleur par biome, pente, altitude, profondeur, chemins et places de village.
## La grille hexagonale n'est visible que dans la carte « Grille (consultation) ».

const Planet = preload("res://sim/planet.gd")
const Faith = preload("res://sim/faith_system.gd")
const Genetics = preload("res://sim/genetics.gd")
const WorldArt = preload("res://game/world_art.gd")

const OVERLAYS := {"terrain": "Terrain", "peoples": "Peuples", "borders": "Frontières", "religion": "Religions",
	"resources": "Ressources", "climate": "Climat", "fertility": "Fertilité", "conflicts": "Conflits",
	"affinity": "Affinités", "grid": "Grille (consultation)"}

# ---- Palette limitée
const PALETTE := {"ice": Color(0.9, 0.94, 0.99), "tundra": Color(0.68, 0.72, 0.6), "taiga": Color(0.4, 0.55, 0.41),
	"temperate_forest": Color(0.36, 0.5, 0.29), "grassland": Color(0.52, 0.63, 0.37), "desert": Color(0.9, 0.81, 0.6),
	"savanna": Color(0.72, 0.68, 0.45), "rainforest": Color(0.3, 0.46, 0.27), "mountain": Color(0.5, 0.52, 0.44),
	"snow_peak": Color(0.9, 0.94, 0.99), "ocean": Color(0.84, 0.77, 0.6), "lake": Color(0.84, 0.77, 0.6)}
const SAND := Color(0.92, 0.85, 0.66)
const CLIFF := Color(0.64, 0.55, 0.45)
const SNOW := Color(0.91, 0.94, 0.99)
const PATH := Color(0.78, 0.69, 0.52)
const PLAZA := Color(0.82, 0.75, 0.6)
const WATER_SHALLOW := Color(0.36, 0.67, 0.68)
const WATER_MID := Color(0.2, 0.45, 0.6)
const WATER_DEEP := Color(0.13, 0.27, 0.44)
const RES_COLORS := {"mana": Color(0.7, 0.35, 0.95), "ore": Color(0.8, 0.35, 0.25), "fish": Color(0.3, 0.6, 0.95),
	"wood": Color(0.15, 0.5, 0.2), "game": Color(0.85, 0.6, 0.3), "stone": Color(0.6, 0.6, 0.6)}

# ---- Formes
var DETAIL := 6               # subdivisions par arête d'un triangle de simulation
const FACET := 2               # la terre est dessinée sur un sommet sur FACET : grands plans anguleux
const STEP := 0.06             # hauteur d'une terrasse (unités de simulation)
const LAND_SCALE := 0.11
const SEA_SCALE := 0.05
const LOD_FAR := 2.55
const LOD_NEAR := 1.6

var world
var art := WorldArt.new()
var overlay := "terrain"
var lod := 0
var last_build_ms := 0.0
var marker_detail := 1.0
var _built_version := -1

var _tri_count := 0
var _chunk_div := 1
var _group_div := 1
var _chunk_count := 0
var _group_count := 0
var _cell_tris: Array = []
var _cell_chunks: Array = []
var _ring: Array = []
var _chunk_center: Array = []
var _group_center: Array = []

# Sommets globaux
var _gid := {}
var g_t := PackedInt32Array()
var g_w := PackedVector3Array()
var g_dir := PackedVector3Array()
var g_raw := PackedFloat32Array()
var g_s1 := PackedFloat32Array()
var g_s := PackedFloat32Array()
var g_h := PackedFloat32Array()
var g_pos := PackedVector3Array()
var g_nrm := PackedVector3Array()
var g_base := PackedColorArray()
var g_adj: Array = []
var _chunk_faces: Array = []     # chunk -> PackedInt32Array (3 indices globaux par face, ordre Godot)
var _chunk_facets: Array = []    # chunk -> faces de la grille grossière (dessin de la terre)
var _chunk_verts: Array = []     # chunk -> PackedInt32Array
var _chunk_nbrs: Array = []      # chunk -> Array de chunks voisins

var _chunk_nodes: Array = []     # par groupe
var _ocean_nodes: Array = []
var _prop_nodes: Array = []
var _village_nodes := {}
var _villages: Array = []        # [{cell, center, R, level, spokes}]
var _village_sig := {}
var _cell_overlay := PackedColorArray()
var _snap_height := PackedFloat32Array()
var _noise_low := FastNoiseLite.new()
var _noise_ridge := FastNoiseLite.new()
var _noise_tint := FastNoiseLite.new()
var _noise_forest := FastNoiseLite.new()
var _terrain_mat: StandardMaterial3D
var _ocean_mat: StandardMaterial3D
var _prop_mat: StandardMaterial3D
var _grid_node: MeshInstance3D
var highlight_instance: MeshInstance3D
var _atmo: MeshInstance3D
var show_names := false
var show_borders := false
var _labels := {}                # id d'établissement -> Label3D
var _border_node: MeshInstance3D
var _border_sig := ""
var _pulse_left := 0.0
var _cam_dir := Vector3.FORWARD
var _cam_dist := 3.0

# ------------------------------------------------------------------ Mise en place

func setup(p_world) -> void:
	world = p_world
	# Même taille de facette quelle que soit la taille du monde : un monde 4× plus fin est moins subdivisé.
	DETAIL = 6 if int(world.planet.subdivisions) <= 4 else 2
	for c in get_children():
		c.queue_free()
	_village_nodes = {}
	_make_materials()
	var sd: int = world.planet.seed_value
	_noise_low.seed = sd + 5
	_noise_low.frequency = 3.0
	_noise_low.fractal_octaves = 3
	_noise_ridge.seed = sd + 9
	_noise_ridge.frequency = 5.0
	_noise_ridge.fractal_octaves = 2
	_noise_tint.seed = sd + 13
	_noise_tint.frequency = 4.0
	_noise_tint.fractal_octaves = 1
	_noise_forest.seed = sd + 17
	_noise_forest.frequency = 9.0
	_noise_forest.fractal_octaves = 2
	_build_topology()
	_chunk_nodes = []
	_ocean_nodes = []
	_prop_nodes = []
	for g in _group_count:
		var mi := MeshInstance3D.new()
		mi.material_override = _terrain_mat
		add_child(mi)
		_chunk_nodes.append(mi)
		var oi := MeshInstance3D.new()
		oi.material_override = _ocean_mat
		oi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(oi)
		_ocean_nodes.append(oi)
		_prop_nodes.append({})
	_grid_node = MeshInstance3D.new()
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1, 1, 1, 0.5)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grid_node.material_override = gm
	_grid_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid_node.visible = overlay == "grid"
	add_child(_grid_node)
	highlight_instance = MeshInstance3D.new()
	var hm := StandardMaterial3D.new()
	hm.vertex_color_use_as_albedo = true
	hm.vertex_color_is_srgb = true
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.no_depth_test = true
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	highlight_instance.material_override = hm
	highlight_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(highlight_instance)
	_make_atmosphere()
	_border_node = MeshInstance3D.new()
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	bm.vertex_color_is_srgb = true
	_border_node.material_override = bm
	_border_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_border_node)
	_labels = {}
	_border_sig = ""
	_snap_height = PackedFloat32Array()
	_cell_overlay = PackedColorArray()
	_village_sig = {}
	_villages = []
	_chunk_props = []
	_built_version = -1
	refresh(true)
	if overlay == "grid":
		_build_grid()

func _make_materials() -> void:
	_terrain_mat = StandardMaterial3D.new()
	_terrain_mat.vertex_color_use_as_albedo = true
	_terrain_mat.vertex_color_is_srgb = true
	_terrain_mat.roughness = 1.0
	_terrain_mat.metallic_specular = 0.15
	_ocean_mat = StandardMaterial3D.new()
	_ocean_mat.vertex_color_use_as_albedo = true
	_ocean_mat.vertex_color_is_srgb = true
	_ocean_mat.roughness = 0.45
	_ocean_mat.metallic_specular = 0.25
	_prop_mat = StandardMaterial3D.new()
	_prop_mat.vertex_color_use_as_albedo = true
	_prop_mat.vertex_color_is_srgb = true
	_prop_mat.roughness = 1.0
	_prop_mat.metallic_specular = 0.15

func _make_atmosphere() -> void:
	_atmo = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.11
	sm.height = 2.22
	sm.radial_segments = 48
	sm.rings = 24
	_atmo.mesh = sm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;
uniform vec4 glow_color : source_color = vec4(0.42, 0.66, 0.95, 1.0);
void fragment() {
	// Coquille vue de l'intérieur : |N·V| vaut 0 au bord extérieur et ~0,45 au ras de la planète.
	float d = abs(dot(NORMAL, VIEW));
	float a = smoothstep(0.0, 0.42, d) * (1.0 - smoothstep(0.42, 0.75, d)) * 0.55;
	ALBEDO = glow_color.rgb * a;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_atmo.material_override = mat
	_atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_atmo)

# ------------------------------------------------------------------ Topologie (une fois par planète)

func _build_topology() -> void:
	var pl = world.planet
	_tri_count = pl.tris.size() / 3
	var levels: int = pl.subdivisions
	_chunk_div = int(pow(4, maxi(levels - 1, 0)))
	_group_div = int(pow(4, levels))
	_chunk_count = _tri_count / _chunk_div
	_group_count = _tri_count / _group_div
	_cell_tris = []
	_cell_chunks = []
	for i in pl.cell_count:
		_cell_tris.append([])
		_cell_chunks.append({})
	_chunk_center = []
	for k in _chunk_count:
		_chunk_center.append(Vector3.ZERO)
	_group_center = []
	for g in _group_count:
		_group_center.append(Vector3.ZERO)
	for t in _tri_count:
		for k in 3:
			var c: int = pl.tris[t * 3 + k]
			_cell_tris[c].append(t)
			_cell_chunks[c][t / _chunk_div] = true
			_chunk_center[t / _chunk_div] += pl.pos[c]
			_group_center[t / _group_div] += pl.pos[c]
	for k in _chunk_count:
		_chunk_center[k] = _chunk_center[k].normalized()
	for g in _group_count:
		_group_center[g] = _group_center[g].normalized()
	# Sommets partagés et faces par chunk.
	_gid = {}
	g_t = PackedInt32Array()
	g_w = PackedVector3Array()
	g_dir = PackedVector3Array()
	var adj: Array = []
	_chunk_faces = []
	_chunk_facets = []
	_chunk_verts = []
	var n := DETAIL
	var vchunks: Array = []
	for k in _chunk_count:
		var faces := PackedInt32Array()
		var vset := {}
		for t in range(k * _chunk_div, (k + 1) * _chunk_div):
			var ids := {}
			for i in n + 1:
				for j in n + 1 - i:
					ids[i * 16 + j] = _vertex(t, i, j, adj, vchunks)
			for i in n:
				for j in n - i:
					_face(faces, ids[i * 16 + j], ids[(i + 1) * 16 + j], ids[i * 16 + j + 1], adj)
					if j < n - i - 1:
						_face(faces, ids[(i + 1) * 16 + j], ids[(i + 1) * 16 + j + 1], ids[i * 16 + j + 1], adj)
			for v in ids.values():
				vset[v] = true
		_chunk_faces.append(faces)
		# Faces grossières : mêmes sommets partagés, pas FACET.
		var coarse := PackedInt32Array()
		var m := n / FACET
		var dummy := []
		for t in range(k * _chunk_div, (k + 1) * _chunk_div):
			for i in m:
				for j in m - i:
					_face(coarse, _gid[_key(t, i * FACET, j * FACET)], _gid[_key(t, (i + 1) * FACET, j * FACET)], _gid[_key(t, i * FACET, (j + 1) * FACET)], adj)
					if j < m - i - 1:
						_face(coarse, _gid[_key(t, (i + 1) * FACET, j * FACET)], _gid[_key(t, (i + 1) * FACET, (j + 1) * FACET)], _gid[_key(t, i * FACET, (j + 1) * FACET)], adj)
		_chunk_facets.append(coarse)
		_chunk_verts.append(PackedInt32Array(vset.keys()))
		for v in vset:
			if not k in vchunks[v]:
				vchunks[v].append(k)
	g_adj = []
	for v in adj.size():
		g_adj.append(PackedInt32Array(adj[v].keys()))
	_chunk_nbrs = []
	for k in _chunk_count:
		var nb := {}
		for v in _chunk_verts[k]:
			for k2 in vchunks[v]:
				if k2 != k:
					nb[k2] = true
		_chunk_nbrs.append(nb.keys())
	var nv := g_dir.size()
	for arr in [g_raw, g_s1, g_s, g_h]:
		arr.resize(nv)
	g_raw.resize(nv); g_s1.resize(nv); g_s.resize(nv); g_h.resize(nv)
	g_pos.resize(nv); g_nrm.resize(nv); g_base.resize(nv)
	# Polygones de Voronoï (grille de consultation, surbrillance).
	_ring = []
	for i in pl.cell_count:
		var normal: Vector3 = pl.pos[i]
		var tangent := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
		var bitangent := normal.cross(tangent)
		var list: Array = _cell_tris[i].duplicate()
		list.sort_custom(func(x, y):
			var vx := _tri_center(x) - normal
			var vy := _tri_center(y) - normal
			return atan2(vx.dot(bitangent), vx.dot(tangent)) < atan2(vy.dot(bitangent), vy.dot(tangent)))
		_ring.append(list)

## Identifiant unique d'un sommet de subdivision : coin (cellule), arête (paire de cellules + rang) ou intérieur.
func _key(t: int, i: int, j: int) -> int:
	var pl = world.planet
	var n := DETAIL
	var cs := [pl.tris[t * 3], pl.tris[t * 3 + 1], pl.tris[t * 3 + 2]]
	var ks := [n - i - j, i, j]
	var nz := []
	for q in 3:
		if ks[q] > 0:
			nz.append(q)
	var C: int = pl.cell_count
	if nz.size() == 1:
		return cs[nz[0]]
	if nz.size() == 2:
		var a: int = cs[nz[0]]
		var b: int = cs[nz[1]]
		var lo := mini(a, b)
		var hi := maxi(a, b)
		var klo: int = ks[nz[0]] if a == lo else ks[nz[1]]
		return C + (lo * C + hi) * (n + 1) + klo
	return C + C * C * (n + 1) + (t * (n + 1) + i) * (n + 1) + j

func _vertex(t: int, i: int, j: int, adj: Array, vchunks: Array) -> int:
	var key := _key(t, i, j)
	if _gid.has(key):
		return _gid[key]
	var pl = world.planet
	var n := float(DETAIL)
	var w := Vector3(1.0 - (i + j) / n, i / n, j / n)
	var d: Vector3 = (pl.pos[pl.tris[t * 3]] * w.x + pl.pos[pl.tris[t * 3 + 1]] * w.y + pl.pos[pl.tris[t * 3 + 2]] * w.z).normalized()
	var id := g_dir.size()
	_gid[key] = id
	g_t.append(t)
	g_w.append(w)
	g_dir.append(d)
	adj.append({})
	vchunks.append([])
	return id

func _face(faces: PackedInt32Array, a: int, b: int, c: int, adj: Array) -> void:
	var pa := g_dir[a]
	if (g_dir[b] - pa).cross(g_dir[c] - pa).dot(pa) < 0.0:
		var tmp := b
		b = c
		c = tmp
	# Sens horaire vu de l'extérieur (faces avant de Godot).
	faces.append(a); faces.append(c); faces.append(b)
	adj[a][b] = true; adj[a][c] = true
	adj[b][a] = true; adj[b][c] = true
	adj[c][a] = true; adj[c][b] = true

func _tri_center(t: int) -> Vector3:
	var pl = world.planet
	return ((pl.pos[pl.tris[t * 3]] + pl.pos[pl.tris[t * 3 + 1]] + pl.pos[pl.tris[t * 3 + 2]]) / 3.0).normalized()

# ------------------------------------------------------------------ Hauteurs

func _raw(v: int) -> float:
	var pl = world.planet
	var t := g_t[v]
	var w := g_w[v]
	var ha: float = pl.height[pl.tris[t * 3]]
	var hb: float = pl.height[pl.tris[t * 3 + 1]]
	var hc: float = pl.height[pl.tris[t * 3 + 2]]
	var pa := pow(w.x, 1.5)
	var pb := pow(w.y, 1.5)
	var pc := pow(w.z, 1.5)
	var h := (ha * pa + hb * pb + hc * pc) / maxf(pa + pb + pc, 0.00001)
	var dir := g_dir[v]
	h += _noise_low.get_noise_3dv(dir) * 0.07
	var m := smoothstep(0.3, 0.65, h)
	if m > 0.0:
		var ridge := 1.0 - absf(_noise_ridge.get_noise_3dv(dir))
		h += m * ridge * ridge * ridge * 0.7   # arêtes franches, sommets marqués
	return h

## Terrasses : plateaux plats reliés par des contremarches courtes et lisses.
static func terrace(s: float) -> float:
	if s <= 0.0:
		return s
	# Basses terres étirées : plus de paliers dans les plaines habitées.
	var lv := (s * 1.35 + 0.03) / STEP
	var fl := floorf(lv)
	return (fl + smoothstep(0.55, 0.95, lv - fl)) * STEP + 0.02

static func radius_of(h: float) -> float:
	return 1.0 + h * LAND_SCALE if h >= 0.0 else 1.0 + h * SEA_SCALE

func _village_level(cell: int) -> float:
	return terrace(maxf(world.planet.height[cell], 0.0)) if world.planet.height[cell] >= 0.0 else 0.02

## Recalcule hauteurs, positions, normales et couleurs des chunks donnés, puis met à jour leurs groupes.
func _rebuild_chunks(dirty: Dictionary) -> Dictionary:
	var vset := {}
	for k in dirty:
		for v in _chunk_verts[k]:
			vset[v] = true
	var verts: Array = vset.keys()
	for v in verts:
		g_raw[v] = _raw(v)
	var ring := {}
	for v in verts:
		ring[v] = true
		for nb in g_adj[v]:
			ring[nb] = true
	for v in ring:
		var acc := 0.0
		var nbs: PackedInt32Array = g_adj[v]
		for nb in nbs:
			acc += g_raw[nb]
		g_s1[v] = g_raw[v] * 0.55 + acc / maxf(nbs.size(), 1) * 0.45
	for v in verts:
		var acc2 := 0.0
		var nbs2: PackedInt32Array = g_adj[v]
		for nb in nbs2:
			acc2 += g_s1[nb]
		g_s[v] = g_s1[v] * 0.7 + acc2 / maxf(nbs2.size(), 1) * 0.3
	# Villages proches de ces chunks.
	var near := {}
	for k in dirty:
		var lst := []
		for vi in _villages:
			if (vi.center as Vector3).dot(_chunk_center[k]) > 0.93:
				lst.append(vi)
		near[k] = lst
	var vill := {}
	for k in dirty:
		for v in _chunk_verts[k]:
			if not vill.has(v):
				vill[v] = near[k]
	for v in verts:
		var h := terrace(g_s[v])
		for vi in vill[v]:
			var d := (g_dir[v] - (vi.center as Vector3)).length()
			var fw := 1.0 - smoothstep(float(vi.R) * 1.8, float(vi.R) * 2.3, d)
			if fw > 0.0:
				h = lerpf(h, float(vi.level), fw)
		g_h[v] = h
	# Léger lissage après terrasses : arrondit les contours (pas de marches en dents de scie).
	var h2 := {}
	for v in verts:
		if g_h[v] <= 0.0:
			continue
		var acc3 := 0.0
		var nb3: PackedInt32Array = g_adj[v]
		for nb in nb3:
			acc3 += g_h[nb]
		h2[v] = g_h[v] * 0.75 + acc3 / maxf(nb3.size(), 1) * 0.25
	for v in h2:
		g_h[v] = h2[v]
	for v in verts:
		g_pos[v] = g_dir[v] * radius_of(g_h[v])
	# Normales : faces des chunks modifiés et de leurs voisins.
	var fchunks := dirty.duplicate()
	for k in dirty:
		for k2 in _chunk_nbrs[k]:
			fchunks[k2] = true
	for v in verts:
		g_nrm[v] = Vector3.ZERO
	for k in fchunks:
		var faces: PackedInt32Array = _chunk_faces[k]
		for f in range(0, faces.size(), 3):
			var a := faces[f]
			var b := faces[f + 1]
			var c := faces[f + 2]
			if not (vset.has(a) or vset.has(b) or vset.has(c)):
				continue
			var fn := (g_pos[c] - g_pos[a]).cross(g_pos[b] - g_pos[a])
			if vset.has(a): g_nrm[a] += fn
			if vset.has(b): g_nrm[b] += fn
			if vset.has(c): g_nrm[c] += fn
	for v in verts:
		var nn := g_nrm[v]
		g_nrm[v] = nn.normalized() if nn.length_squared() > 0.0 else g_dir[v]
		g_base[v] = _vertex_color(v, vill[v])
	var groups := {}
	for k in fchunks:
		groups[k * _chunk_div / _group_div] = true
	return groups

# ------------------------------------------------------------------ Couleurs

func _vertex_color(v: int, villages: Array) -> Color:
	var pl = world.planet
	var t := g_t[v]
	var w := g_w[v]
	var h := g_h[v]
	var dir := g_dir[v]
	if h < 0.0:
		return SAND.darkened(0.2)
	# Biomes : poids accentués pour de grands aplats, transitions douces.
	var col := Color(0, 0, 0)
	var tot := 0.0
	var temp := 0.0
	for q in 3:
		var c: int = pl.tris[t * 3 + q]
		var wq: float = [w.x, w.y, w.z][q]
		var p := pow(wq, 4.0)
		col += (PALETTE.get(pl.biome_name(c), PALETTE.grassland) as Color) * p
		temp += pl.temperature[c] * wq
		tot += p
	col = col / maxf(tot, 0.00001)
	# Plages : terre basse au contact de l'eau.
	if h < 0.045:
		var wet := false
		for nb in g_adj[v]:
			if g_s[nb] < 0.0:
				wet = true
				break
		if wet or g_s[v] < 0.01:
			col = SAND
	# Contremarches et falaises : terre/roche chaude selon la pente.
	var slope := 1.0 - g_nrm[v].dot(dir)
	col = col.lerp(CLIFF, smoothstep(0.14, 0.3, slope))
	# Neige selon l'altitude et la température.
	var snow_line := 0.95 - (0.45 - clampf(temp, 0.0, 0.45)) * 1.5
	if h > snow_line:
		col = col.lerp(SNOW, smoothstep(snow_line, snow_line + 0.06, h))
	# Variation très discrète de grande échelle (pas de bruit par triangle).
	var k := _noise_tint.get_noise_3dv(dir) * 0.04
	return col.lightened(k) if k > 0.0 else col.darkened(-k)

func _overlay_color(i: int, ctx: Dictionary) -> Color:
	var pl = world.planet
	var o: int = world.owner[i]
	var s: Dictionary = world.settlements[o] if o >= 0 else {}
	var none := Color(0, 0, 0, 0)
	match overlay:
		"peoples":
			if s.is_empty():
				return none
			var pc: Array = world.peoples[int(s.people)].color
			return Color(pc[0], pc[1], pc[2])
		"borders":
			if s.is_empty():
				return none
			var pc2: Array = world.peoples[int(s.people)].color
			for nb in pl.neighbors[i]:
				var on: int = world.owner[nb]
				if on < 0 or int(world.settlements[on].people) != int(s.people):
					return Color(pc2[0], pc2[1], pc2[2])
			return Color(pc2[0], pc2[1], pc2[2], 0.35)
		"religion":
			if s.is_empty():
				return none
			var m := Faith.main_religion(s)
			if m == "":
				return Color(0.3, 0.3, 0.3)
			var dc: Array = world.deities[int(world.religions[int(m)].deity)].color
			return Color(dc[0], dc[1], dc[2], clampf(float(s.faith[m]), 0.3, 1.0))
		"resources":
			for r in ["mana", "ore", "fish", "wood", "game", "stone"]:
				if pl.has_res(i, r) and pl.is_land(i):
					return RES_COLORS[r]
			return none
		"climate":
			return Color(0.2, 0.35, 0.95).lerp(Color(0.95, 0.3, 0.15), pl.temperature[i])
		"fertility":
			return Color(0.6, 0.45, 0.3).lerp(Color(0.2, 0.85, 0.2), pl.fertility[i]) if pl.is_land(i) else none
		"conflicts":
			if s.is_empty():
				return none
			return Color(0.95, 0.15, 0.1) if ctx.war.has(int(s.people)) else Color(0.95, 0.95, 0.95, 0.4)
		"affinity":
			if s.is_empty():
				return none
			var tot := maxf(float(s.aff.none) + float(s.aff.magic) + float(s.aff.sword) + float(s.aff.both), 1.0)
			var mg := (float(s.aff.magic) + float(s.aff.both)) / tot
			var sw := (float(s.aff.sword) + float(s.aff.both)) / tot
			return Color(0.3 + sw * 3.0, 0.3, 0.3 + mg * 3.0).clamp()
	return none

func _compute_overlay() -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(world.planet.cell_count)
	if overlay in ["terrain", "grid"]:
		return out
	var ctx := {"war": {}}
	for k in world.relations:
		if world.relations[k].war:
			for part in k.split(":"):
				ctx.war[int(part)] = true
	for i in world.planet.cell_count:
		out[i] = _overlay_color(i, ctx)
	return out

## Cellule dominante d'un sommet (pour la teinte thématique).
func _dominant_cell(v: int) -> int:
	var w := g_w[v]
	var t := g_t[v]
	var q := 0
	if w.y > w.x and w.y >= w.z:
		q = 1
	elif w.z > w.x and w.z > w.y:
		q = 2
	return world.planet.tris[t * 3 + q]

# ------------------------------------------------------------------ Maillages par groupe

func _upload_group(g: int) -> void:
	var per := _group_div / _chunk_div
	# Terre : facettes franches (normale par face) mais couleurs par sommet continues → pas de mosaïque.
	var lv := PackedVector3Array()
	var ln := PackedVector3Array()
	var lc := PackedColorArray()
	# Eau : surface douce (normales lissées, indexée) pour contraster avec les terres.
	var olocal := {}
	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	var oc := PackedColorArray()
	var oidx := PackedInt32Array()
	var tint := overlay not in ["terrain", "grid"] and _cell_overlay.size() > 0
	for k in range(g * per, (g + 1) * per):
		var cf: PackedInt32Array = _chunk_facets[k]
		for f in range(0, cf.size(), 3):
			var a := cf[f]
			var b := cf[f + 1]
			var c := cf[f + 2]
			if g_h[a] > -0.06 or g_h[b] > -0.06 or g_h[c] > -0.06:
				var fn := (g_pos[c] - g_pos[a]).cross(g_pos[b] - g_pos[a]).normalized()
				for v in [a, b, c]:
					lv.append(g_pos[v])
					ln.append(fn)
					var col := g_base[v]
					if tint:
						var oc2: Color = _cell_overlay[_dominant_cell(v)]
						col = col.lerp(Color(oc2.r, oc2.g, oc2.b), 0.6 * oc2.a) if oc2.a > 0.0 else col.lerp(Color(0.55, 0.55, 0.55), 0.45)
					lc.append(col)
		var faces: PackedInt32Array = _chunk_faces[k]
		for f in range(0, faces.size(), 3):
			var a := faces[f]
			var b := faces[f + 1]
			var c := faces[f + 2]
			if g_s[a] < 0.04 or g_s[b] < 0.04 or g_s[c] < 0.04:
				for v in [a, b, c]:
					if not olocal.has(v):
						olocal[v] = ov.size()
						ov.append(g_dir[v])
						on.append(g_dir[v])
						oc.append(_water_color(v))
					oidx.append(olocal[v])
	_chunk_nodes[g].mesh = _mesh_flat(lv, ln, lc)
	_ocean_nodes[g].mesh = _mesh(ov, on, oc, oidx)

static func _mesh_flat(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray) -> ArrayMesh:
	var m := ArrayMesh.new()
	if v.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _water_color(v: int) -> Color:
	var d := clampf(-g_s[v], 0.0, 1.0)
	var col := WATER_SHALLOW.lerp(WATER_MID, smoothstep(0.02, 0.22, d)).lerp(WATER_DEEP, smoothstep(0.22, 0.7, d))
	var pl = world.planet
	var c := _dominant_cell(v)
	if pl.temperature[c] < 0.1:
		col = col.lerp(Color(0.88, 0.93, 0.98), 0.7)
	return col

static func _mesh(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	if idx.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

# ------------------------------------------------------------------ Échantillonnage de la surface

## Rayon et normale de la surface au point (t, poids barycentriques).
func sample(t: int, w: Vector3) -> Array:
	var n := DETAIL / FACET
	var x := w.y * n
	var y := w.z * n
	var i := clampi(int(floor(x)), 0, n - 1)
	var j := clampi(int(floor(y)), 0, n - 1 - i)
	var fx := x - i
	var fy := y - j
	var ids: Array
	var bw: Vector3
	var F := FACET
	if fx + fy <= 1.0 or i + j >= n - 1:
		ids = [_gid[_key(t, i * F, j * F)], _gid[_key(t, (i + 1) * F, j * F)], _gid[_key(t, i * F, (j + 1) * F)]]
		bw = Vector3(1.0 - fx - fy, fx, fy)
	else:
		ids = [_gid[_key(t, (i + 1) * F, (j + 1) * F)], _gid[_key(t, i * F, (j + 1) * F)], _gid[_key(t, (i + 1) * F, j * F)]]
		bw = Vector3(fx + fy - 1.0, 1.0 - fx, 1.0 - fy)
	var r := g_pos[ids[0]].length() * bw.x + g_pos[ids[1]].length() * bw.y + g_pos[ids[2]].length() * bw.z
	var nrm := (g_nrm[ids[0]] * bw.x + g_nrm[ids[1]] * bw.y + g_nrm[ids[2]] * bw.z).normalized()
	var h := g_h[ids[0]] * bw.x + g_h[ids[1]] * bw.y + g_h[ids[2]] * bw.z
	return [r, nrm, h]

func _locate(dir: Vector3, hint: int) -> Array:
	var pl = world.planet
	var cands: Array = _cell_tris[hint].duplicate()
	for nb in pl.neighbors[hint]:
		cands.append_array(_cell_tris[nb])
	for t in cands:
		var w := _bary(dir, t)
		if w.x >= -0.0001 and w.y >= -0.0001 and w.z >= -0.0001:
			return [t, Vector3(maxf(w.x, 0.0), maxf(w.y, 0.0), maxf(w.z, 0.0))]
	return []

func surface_radius(dir: Vector3, hint: int) -> float:
	var loc := _locate(dir, hint)
	if loc.is_empty():
		return radius_of(world.planet.height[hint])
	return sample(loc[0], loc[1])[0]

func _bary(dir: Vector3, t: int) -> Vector3:
	var pl = world.planet
	var a: Vector3 = pl.pos[pl.tris[t * 3]]
	var b: Vector3 = pl.pos[pl.tris[t * 3 + 1]]
	var c: Vector3 = pl.pos[pl.tris[t * 3 + 2]]
	var n := (b - a).cross(c - a)
	var den := n.dot(dir)
	if absf(den) < 0.000001:
		return Vector3(-1, -1, -1)
	var p := dir * (n.dot(a) / den)
	var area2 := n.length_squared()
	var wa := (b - p).cross(c - p).dot(n) / area2
	var wb := (c - p).cross(a - p).dot(n) / area2
	return Vector3(wa, wb, 1.0 - wa - wb)

# ------------------------------------------------------------------ Végétation : forêts, bosquets, clairières

var _chunk_props: Array = []      # chunk -> {kind: [Transform3D]}

## Végétation d'un chunk (mise en cache) ; les groupes concatènent les listes de leurs chunks.
func _build_chunk_props(k: int) -> void:
	var pl = world.planet
	var lists := {}
	for kind in WorldArt.PROPS:
		lists[kind] = []
	var near := []
	for vi in _villages:
		if (vi.center as Vector3).dot(_chunk_center[k]) > 0.9:
			near.append(vi)
	var rng := RandomNumberGenerator.new()
	for t in range(k * _chunk_div, (k + 1) * _chunk_div):
		rng.seed = pl.seed_value * 7919 + t
		var A: Vector3 = pl.pos[pl.tris[t * 3]]
		var B: Vector3 = pl.pos[pl.tris[t * 3 + 1]]
		var C: Vector3 = pl.pos[pl.tris[t * 3 + 2]]
		var forest_tri := false
		for q0 in 3:
			if pl.biome_name(pl.tris[t * 3 + q0]) in ["temperate_forest", "rainforest", "taiga"]:
				forest_tri = true
		# Densité constante par unité de surface quelle que soit la taille du monde.
		var area_k := pow(4.0, 4 - int(pl.subdivisions))
		for s in int((40 if forest_tri else 14) * area_k + 0.5):
			var r1 := rng.randf()
			var r2 := rng.randf()
			var yaw := rng.randf() * TAU
			var size := rng.randf_range(0.015, 0.021)
			var pick := rng.randf()
			var sq := sqrt(r1)
			var w := Vector3(1.0 - sq, sq * (1.0 - r2), sq * r2)
			var q := 0
			if w.y > w.x and w.y >= w.z:
				q = 1
			elif w.z > w.x and w.z > w.y:
				q = 2
			var cell: int = pl.tris[t * 3 + q]
			var dir := (A * w.x + B * w.y + C * w.z).normalized()
			var mask := _noise_forest.get_noise_3dv(dir)
			var kind := _prop_for(pl.biome_name(cell), pl.temperature[cell], mask, pick)
			if kind == "":
				continue
			var blocked := false
			for vi in near:
				if (dir - (vi.center as Vector3)).length() < float(vi.R) * 2.0:
					blocked = true
					break
			if blocked:
				continue
			var smp := sample(t, w)
			var h: float = smp[2]
			var nrm: Vector3 = smp[1]
			if h < 0.03 and kind != "palm":
				continue
			if nrm.dot(dir) < 0.94 and kind not in ["rock", "rock_b"]:
				continue
			if kind in ["rock", "rock_b"]:
				size *= 0.55
			var basis := _basis_up(dir, yaw).scaled(Vector3.ONE * size)
			lists[kind].append(Transform3D(basis, dir * (float(smp[0]) - 0.0008)))
	while _chunk_props.size() < _chunk_count:
		_chunk_props.append({})
	_chunk_props[k] = lists

func _build_props(g: int) -> void:
	var per := _group_div / _chunk_div
	var lists := {}
	for kind in WorldArt.PROPS:
		lists[kind] = []
	for k in range(g * per, (g + 1) * per):
		if k >= _chunk_props.size() or _chunk_props[k].is_empty():
			_build_chunk_props(k)
		for kind in _chunk_props[k]:
			lists[kind].append_array(_chunk_props[k][kind])
	var nodes: Dictionary = _prop_nodes[g]
	for kind in lists:
		var items: Array = lists[kind]
		if items.is_empty() and not nodes.has(kind):
			continue
		if not nodes.has(kind):
			var mmi := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = art.prop_mesh(kind)
			mmi.multimesh = mm
			mmi.material_override = _prop_mat
			add_child(mmi)
			nodes[kind] = mmi
		var mmesh: MultiMesh = nodes[kind].multimesh
		mmesh.instance_count = items.size()
		for i in items.size():
			mmesh.set_instance_transform(i, items[i])

## Forêts denses là où le masque est haut, bosquets épars ailleurs, clairières là où il est bas.
func _prop_for(b: String, temp: float, mask: float, r: float) -> String:
	var forest := smoothstep(-0.15, 0.25, mask)
	var grove := smoothstep(0.3, 0.5, mask)
	match b:
		"temperate_forest":
			if r < forest * 0.95:
				return "broadleaf" if r < forest * 0.5 else ("broadleaf_b" if r < forest * 0.8 else "conifer")
			if r > 0.97: return "bush"
		"rainforest":
			if r < forest * 0.85:
				return "broadleaf_b" if r < forest * 0.5 else ("broadleaf" if r < forest * 0.7 else "palm")
		"taiga":
			if r < forest * 0.8:
				if temp < 0.33:
					return "snow_conifer" if r < forest * 0.4 else "conifer_b"
				return "conifer" if r < forest * 0.45 else "conifer_b"
			if r > 0.97: return "rock"
		"grassland":
			if r < grove * 0.35:
				return "broadleaf" if r < grove * 0.25 else "bush"
			if r > 0.985: return "rock"
		"savanna":
			if r < grove * 0.2 + 0.03: return "acacia"
			if r > 0.96: return "bush"
		"desert":
			if r < 0.03: return "cactus"
			if r > 0.96: return "rock"
		"tundra":
			if r < 0.025: return "rock"
			if r < 0.06 + grove * 0.2: return "snow_conifer"
		"mountain":
			if r < 0.05: return "rock_b"
			if r < 0.1: return "rock"
			if r < 0.1 + forest * 0.35: return "conifer_b"
		"snow_peak":
			if r < 0.08: return "rock_b"
	return ""

static func _basis_up(up: Vector3, yaw: float) -> Basis:
	var x := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z) * Basis(Vector3.UP, yaw)

# ------------------------------------------------------------------ Villages

## Rayon visuel d'un village par paliers de population (évite de reconstruire le terrain à chaque naissance).
static func village_tier(pop: float) -> int:
	return clampi(int(floor(sqrt(maxf(pop, 1.0)) / 3.0)), 0, 6)

func _village_list() -> Array:
	var out := []
	for s in world.settlements:
		if not s.alive:
			continue
		var cell := int(s.cell)
		var c: Vector3 = world.planet.pos[cell]
		var tier := village_tier(float(s.pop))
		var tx := c.cross(Vector3.UP if absf(c.y) < 0.95 else Vector3.RIGHT).normalized()
		var tz := c.cross(tx)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(s.id) * 7717
		var a0 := rng.randf() * TAU
		out.append({"id": int(s.id), "cell": cell, "center": c, "R": 0.016 + tier * 0.0035, "tier": tier,
			"level": _village_level(cell), "spokes": [a0, a0 + TAU / 3.0, a0 + 2.0 * TAU / 3.0], "tx": tx, "tz": tz})
	return out

func _build_villages() -> void:
	if world == null:
		return
	var lists := {}
	var banner_scale := 3.2 if lod == 0 else (1.5 if lod == 1 else 1.0)
	var by_id := {}
	for vi in _villages:
		by_id[int(vi.id)] = vi
	for s in world.settlements:
		if not s.alive or not by_id.has(int(s.id)):
			continue
		var vi: Dictionary = by_id[int(s.id)]
		var p: Dictionary = world.peoples[int(s.people)]
		var era := clampi(int(p.era), 0, 5)
		var pc := Color(p.color[0], p.color[1], p.color[2])
		var dcol: Array = world.deities[int(p.deity)].color
		var cell := int(s.cell)
		var center: Vector3 = vi.center
		var R := float(vi.R)
		var pop := float(s.pop)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(s.id) * 104729
		var bsize := 0.02 * banner_scale
		_add_inst(lists, "banner_%d" % int(p.id), art.banner_mesh(p.species, pc, Color(dcol[0], dcol[1], dcol[2])), _place(center, cell, 0.3, bsize))
		if lod == 0:
			continue
		var sp: Array = vi.spokes
		var bsc := 0.0105
		# Place centrale et chemins (surfaces posées au sol, plus fines que la grille du terrain).
		_add_inst(lists, "plaza", art.prop_mesh("plaza"), _flat(center, center, 0.0, Vector3(R * 0.62, 1.0, R * 0.62), cell))

		# Bâtiment collectif et lieu de culte sur la place, selon les données réelles.
		if pop > 40 or str(p.polity) != "Tribu":
			var a := float(sp[0]) + PI / 3.0
			_add_inst(lists, _bkey("collective", p, era), _bmesh("collective", p, era, pc), _place_facing(center, a, R * 0.5, cell, vi, bsc * 1.15))
		if p.techs.has("rites") or p.techs.has("clerge"):
			var a2 := float(sp[1]) + PI / 3.0
			_add_inst(lists, _bkey("cult", p, era), _bmesh("cult", p, era, pc), _place_facing(center, a2, R * 0.5, cell, vi, bsc * 1.1))
		# Production : grenier si poterie/agriculture, sinon atelier si outils.
		if p.techs.has("poterie") or p.techs.has("agriculture") or p.techs.has("outils_pierre"):
			var a3 := float(sp[2]) + PI / 3.0
			_add_inst(lists, _bkey("production", p, era), _bmesh("production", p, era, pc), _place_facing(center, a3, R * 0.82, cell, vi, bsc))
		# Habitations : nombre ∝ √population, sur des anneaux, hors des chemins, portes vers la place.
		var count := clampi(int(round(sqrt(pop) / 1.7)), 1, 24)
		var placed := 0
		var ring_r := R * 0.62
		var tries := 0
		while placed < count and tries < count * 6:
			tries += 1
			var ang := rng.randf() * TAU
			var rad := ring_r + rng.randf() * R * 0.38
			var ok := true
			for spa in sp:
				if absf(wrapf(ang - float(spa), -PI, PI)) * rad < R * 0.16:
					ok = false
			if not ok:
				continue
			_add_inst(lists, _bkey("house", p, era) + str(s.get("species", "")), _bmesh("house", p, era, pc, str(s.get("species", ""))), _place_facing(center, ang, rad, cell, vi, bsc * rng.randf_range(0.85, 1.0)))
			# Abords : terre battue entre la porte et la place.
			var ydir := (center + _tangent(vi, ang) * (rad - R * 0.17)).normalized()
			_add_inst(lists, "path", art.prop_mesh("path"), _flat(ydir, center, ang, Vector3(R * 0.13, 1.0, R * 0.2), cell))
			placed += 1
		# Champs autour du village si l'agriculture est connue (sinon quelques jardins).
		var fields := clampi(int(pop / 45.0), 2, 9) if p.techs.has("agriculture") else (2 if pop > 30 else 0)
		for f in fields:
			var af := float(sp[f % 3]) + PI / 3.0 + rng.randf_range(-0.5, 0.5)
			var rf := R * rng.randf_range(1.35, 1.75)
			var dirf := (center + _tangent(vi, af) * rf).normalized()
			var loc := _locate(dirf, cell)
			if loc.is_empty():
				continue
			var smp := sample(loc[0], loc[1])
			if float(smp[2]) < 0.03 or (smp[1] as Vector3).dot(dirf) < 0.985:
				continue
			var kind := "field_wheat" if f % 2 == 0 else "field_green"
			var bf := _basis_up(dirf, af)
			var basis := Basis(bf.x * R * 0.55, bf.y * 0.01, bf.z * R * 0.42)
			_add_inst(lists, kind, art.prop_mesh(kind), Transform3D(basis, dirf * (float(smp[0]) + 0.0002)))
		# Fortifications.
		if p.techs.has("forteresses") or (era >= 1 and pop > 200):
			var stone: bool = p.techs.has("forteresses")
			var segs := 18
			for i in segs:
				var ang2 := TAU * i / segs
				var on_path := false
				for spa in sp:
					if absf(wrapf(ang2 - float(spa), -PI, PI)) < 0.2:
						on_path = true
				if on_path:
					continue
				var dir2 := (center + _tangent(vi, ang2) * R * 1.12).normalized()
				var x := _tangent(vi, ang2 + PI / 2.0)
				var z := x.cross(dir2).normalized()
				var basis2 := Basis(x, dir2, z).scaled(Vector3.ONE * R * 0.36)
				_add_inst(lists, "wall_%s" % stone, art.wall_mesh(stone), Transform3D(basis2, dir2 * (surface_radius(dir2, cell) - 0.0004)))
		# Habitants représentatifs (de près), tirés des distributions réelles de l'établissement.
		if lod == 2 and center.dot(_cam_dir) > 0.97:
			var inds: Array = Genetics.representatives(world.cat, s, str(s.get("species", p.species)), 6, int(s.id) * 31 + world.year)
			for i in inds.size():
				var ang3 := TAU * i / inds.size() + 0.4
				var dir3 := (center + _tangent(vi, ang3) * R * 0.2).normalized()
				var aff: String = inds[i].affinity
				_add_inst(lists, "f_%d_%s" % [int(p.id), aff], art.figure_mesh(pc, aff), _place(dir3, cell, ang3 + PI, 0.0042))
	for key in _village_nodes:
		_village_nodes[key].visible = lists.has(key)
	for key in lists:
		if not _village_nodes.has(key):
			var mmi := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mmi.multimesh = mm
			mmi.material_override = _prop_mat
			add_child(mmi)
			_village_nodes[key] = mmi
		var node: MultiMeshInstance3D = _village_nodes[key]
		node.visible = true
		node.multimesh.mesh = lists[key][0]
		var items: Array = lists[key][1]
		node.multimesh.instance_count = items.size()
		for i in items.size():
			node.multimesh.set_instance_transform(i, items[i])

## Surface plate posée sur le terrain, axe +Z local orienté selon `ang` autour du centre.
func _flat(dir: Vector3, center: Vector3, ang: float, scale: Vector3, hint: int) -> Transform3D:
	var radial := (dir - center)
	radial = radial - dir * radial.dot(dir)
	var z := radial.normalized() if radial.length() > 0.0001 else _basis_up(dir, 0.0).z
	var x := dir.cross(z).normalized()
	var basis := Basis(x * scale.x, dir * scale.y, z * scale.z)   # échelle locale (Basis.scaled serait globale)
	return Transform3D(basis, dir * (surface_radius(dir, hint) + 0.0004))

func _bkey(kind: String, p: Dictionary, era: int) -> String:
	return "b_%s_%d_%d" % [kind, int(p.id), era]

func _bmesh(kind: String, p: Dictionary, era: int, pc: Color, species: String = "") -> Mesh:
	return art.building_mesh(kind, species if species != "" else p.species, era, pc, float(p.lean))

func _add_inst(lists: Dictionary, key: String, mesh: Mesh, xf: Transform3D) -> void:
	if not lists.has(key):
		lists[key] = [mesh, []]
	lists[key][1].append(xf)

func _place(dir: Vector3, hint: int, yaw: float, size: float) -> Transform3D:
	var basis := _basis_up(dir, yaw).scaled(Vector3.ONE * size)
	return Transform3D(basis, dir * (surface_radius(dir, hint) - 0.0003))

## Bâtiment à l'angle `ang` et à la distance `rad` du centre, porte (axe +Z local) tournée vers la place.
func _place_facing(center: Vector3, ang: float, rad: float, hint: int, vi: Dictionary, size: float) -> Transform3D:
	var dir := (center + _tangent(vi, ang) * rad).normalized()
	var to_center := (center - dir)
	to_center = (to_center - dir * to_center.dot(dir)).normalized()
	var x := dir.cross(to_center).normalized()
	var basis := Basis(x, dir, to_center).scaled(Vector3.ONE * size)
	return Transform3D(basis, dir * (surface_radius(dir, hint) - 0.0003))

func _tangent(vi: Dictionary, ang: float) -> Vector3:
	return (vi.tx as Vector3) * cos(ang) + (vi.tz as Vector3) * sin(ang)

# ------------------------------------------------------------------ Grille et surbrillance

func _build_grid() -> void:
	var pl = world.planet
	var pts := PackedVector3Array()
	var seen := {}
	for i in pl.cell_count:
		var ring: Array = _ring[i]
		for k in ring.size():
			var t0: int = ring[k]
			var t1: int = ring[(k + 1) % ring.size()]
			var key := mini(t0, t1) * 100000 + maxi(t0, t1)
			if seen.has(key):
				continue
			seen[key] = true
			pts.append(_tri_point(t0))
			pts.append(_tri_point(t1))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	_grid_node.mesh = m

func _tri_point(t: int) -> Vector3:
	var smp := sample(t, Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0))
	return _tri_center(t) * maxf(float(smp[0]), 1.0) * 1.002

func highlight(cells: Array, color: Color) -> void:
	if cells.is_empty():
		highlight_instance.mesh = null
		return
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for c in cells:
		var i := int(c)
		var ring: Array = _ring[i]
		var center: Vector3 = world.planet.pos[i] * maxf(surface_radius(world.planet.pos[i], i), 1.0) * 1.003
		for k in ring.size():
			verts.append(center)
			verts.append(_tri_point(ring[(k + 1) % ring.size()]))
			verts.append(_tri_point(ring[k]))
			for q in 3:
				colors.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	highlight_instance.mesh = mesh

# ------------------------------------------------------------------ Rafraîchissement

func set_overlay(o: String) -> void:
	overlay = o
	_grid_node.visible = o == "grid"
	if o == "grid" and _grid_node.mesh == null:
		_build_grid()
	refresh(true)

## Ne reconstruit que ce qui a changé : terrain des cellules modifiées, abords des villages apparus ou agrandis,
## couleurs thématiques, végétation des groupes touchés, bâtiments (lus dans la simulation).
func refresh(force: bool = false) -> void:
	if world == null:
		return
	var t0 := Time.get_ticks_usec()
	var pl = world.planet
	var dirty := {}
	var full: bool = _snap_height.size() != pl.cell_count
	# Villages : paliers de taille.
	var new_list := _village_list()
	var sig := {}
	for vi in new_list:
		sig[int(vi.cell)] = int(vi.tier)
	if full:
		for k in _chunk_count:
			dirty[k] = true
	else:
		if pl.version != _built_version:
			for i in pl.cell_count:
				if _snap_height[i] != pl.height[i]:
					for k in _cell_chunks[i]:
						dirty[k] = true
		for c in sig:
			if not _village_sig.has(c) or _village_sig[c] != sig[c]:
				for k in _village_chunks(c):
					dirty[k] = true
		for c in _village_sig:
			if not sig.has(c):
				for k in _village_chunks(c):
					dirty[k] = true
	_villages = new_list
	_village_sig = sig
	_snap_height = pl.height.duplicate()
	var groups := {}
	if not dirty.is_empty():
		groups = _rebuild_chunks(dirty)
		for k in dirty:
			_build_chunk_props(k)
		if _grid_node.mesh != null:
			_build_grid()
	var new_overlay := _compute_overlay()
	if force or new_overlay != _cell_overlay:
		var old := _cell_overlay
		_cell_overlay = new_overlay
		if force or old.size() != new_overlay.size():
			for g in _group_count:
				groups[g] = true
		else:
			for i in new_overlay.size():
				if new_overlay[i] != old[i]:
					for k in _cell_chunks[i]:
						groups[k * _chunk_div / _group_div] = true
	var prop_groups := {}
	for k in dirty:
		prop_groups[k * _chunk_div / _group_div] = true
	for g in groups:
		_upload_group(g)
	for g in prop_groups:
		_build_props(g)
	_build_villages()
	_update_labels()
	_update_borders()
	_built_version = pl.version
	last_build_ms = (Time.get_ticks_usec() - t0) / 1000.0

func _village_chunks(cell: int) -> Array:
	var out := {}
	for c in world.planet.cells_within(cell, 1, 10):
		for k in _cell_chunks[c]:
			out[k] = true
	return out.keys()

func update_markers() -> void:
	_build_villages()

## À chaque image : niveau de détail et masquage de la face cachée de la planète.
func update_view(cam_pos: Vector3) -> void:
	if world == null:
		return
	_cam_dist = cam_pos.length()
	_cam_dir = cam_pos.normalized()
	var new_lod := 0 if _cam_dist > LOD_FAR else (1 if _cam_dist > LOD_NEAR else 2)
	if new_lod != lod:
		lod = new_lod
		_build_villages()
	var horizon := 1.0 / _cam_dist
	for g in _group_count:
		var vis: bool = _group_center[g].dot(_cam_dir) > horizon - 0.6
		_chunk_nodes[g].visible = vis
		_ocean_nodes[g].visible = vis
	var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for g in _group_count:
		var gvis: bool = lod >= 1 and _group_center[g].dot(_cam_dir) > horizon - 0.5
		for kind in _prop_nodes[g]:
			var node: MultiMeshInstance3D = _prop_nodes[g][kind]
			node.visible = gvis
			if gvis:
				var mm := node.multimesh
				mm.visible_instance_count = -1 if lod == 2 else int(mm.instance_count * 0.7)
				node.cast_shadow = shadow

func vertex_count() -> int:
	return g_pos.size()


# ------------------------------------------------------------------ Repères : noms, frontières, retour visuel

func set_names(on: bool) -> void:
	show_names = on
	_update_labels()

func set_borders(on: bool) -> void:
	show_borders = on
	_border_sig = ""
	_update_borders()

func _update_labels() -> void:
	var alive := {}
	if show_names:
		for vi in _villages:
			var s: Dictionary = world.settlements[int(vi.id)]
			var p: Dictionary = world.peoples[int(s.people)]
			alive[int(vi.id)] = true
			var lb: Label3D = _labels.get(int(vi.id))
			if lb == null:
				lb = Label3D.new()
				lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lb.fixed_size = true
				lb.pixel_size = 0.0011
				lb.font_size = 26
				lb.outline_size = 8
				lb.outline_modulate = Color(0, 0, 0, 0.85)
				lb.no_depth_test = false
				add_child(lb)
				_labels[int(vi.id)] = lb
			lb.text = "%s · %d" % [s.name, int(s.pop)]
			lb.modulate = Color(p.color[0], p.color[1], p.color[2]).lightened(0.35)
			var c: Vector3 = vi.center
			lb.position = c * (surface_radius(c, int(vi.cell)) + 0.035)
	for id in _labels.keys():
		if not alive.has(id):
			_labels[id].queue_free()
			_labels.erase(id)

## Frontières : segments entre cellules de peuples différents, aux couleurs du peuple.
func _update_borders() -> void:
	if not show_borders:
		_border_node.mesh = null
		return
	var pl = world.planet
	var people := PackedInt32Array()
	people.resize(pl.cell_count)
	for i in pl.cell_count:
		var o: int = world.owner[i]
		people[i] = -1 if o < 0 else int(world.settlements[o].people)
	var sig := str(hash(people))
	if sig == _border_sig:
		return
	_border_sig = sig
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for i in pl.cell_count:
		var pi := people[i]
		if pi < 0:
			continue
		var ring: Array = _ring[i]
		var col := Color(world.peoples[pi].color[0], world.peoples[pi].color[1], world.peoples[pi].color[2])
		for k in ring.size():
			var t0: int = ring[k]
			var t1: int = ring[(k + 1) % ring.size()]
			var other := -1
			for q in 3:
				var v: int = pl.tris[t0 * 3 + q]
				if v != i and (pl.tris[t1 * 3] == v or pl.tris[t1 * 3 + 1] == v or pl.tris[t1 * 3 + 2] == v):
					other = v
			if other >= 0 and people[other] == pi:
				continue
			var a := _tri_point(t0) * 1.0025
			var b := _tri_point(t1) * 1.0025
			# Léger retrait vers l'intérieur : deux peuples voisins gardent chacun leur trait.
			var ci: Vector3 = pl.pos[i]
			pts.append(a.lerp(ci * a.length(), 0.08))
			pts.append(b.lerp(ci * b.length(), 0.08))
			cols.append(col)
			cols.append(col)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	if pts.size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	_border_node.mesh = m

## Retour visuel bref sur la zone touchée par un pouvoir.
func pulse(cells: Array, color: Color) -> void:
	highlight(cells, color)
	_pulse_left = 1.6

func _process(delta: float) -> void:
	if _pulse_left > 0.0:
		_pulse_left -= delta
		if highlight_instance.mesh != null:
			(highlight_instance.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, clampf(_pulse_left / 1.6, 0.0, 1.0))
		if _pulse_left <= 0.0:
			highlight_instance.mesh = null
			(highlight_instance.material_override as StandardMaterial3D).albedo_color = Color.WHITE

## Point de la surface visé par un rayon (marche le long du rayon jusqu'au relief).
func ray_hit(origin: Vector3, dir: Vector3) -> Vector3:
	var b := origin.dot(dir)
	var c := origin.dot(origin) - 1.12 * 1.12
	var disc := b * b - c
	if disc < 0.0:
		return Vector3.ZERO
	var t := -b - sqrt(disc)
	var hint: int = world.planet.nearest_cell(origin + dir * t)
	for i in 80:
		var p := origin + dir * t
		var d := p.normalized()
		if i % 8 == 0:
			hint = world.planet.nearest_cell(d)
		if p.length() <= surface_radius(d, hint):
			return p
		t += 0.0025
	return origin + dir * (-b - sqrt(maxf(b * b - (origin.dot(origin) - 1.0), 0.0)))
