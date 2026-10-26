extends Node3D
## Rendu de la planète.
## La simulation reste une grille de cellules (sim/planet.gd). L'habillage visuel interpole les hauteurs des
## cellules sur une surface continue (aucune fissure possible : chaque sommet ne dépend que de sa direction
## et des cellules de son arête), ajoute du relief, des côtes, un océan à profondeur, de la végétation,
## des rochers et les villages réellement présents dans la simulation.
## La grille hexagonale n'est visible que dans la carte « Grille ».

const Planet = preload("res://sim/planet.gd")
const Faith = preload("res://sim/faith_system.gd")
const Genetics = preload("res://sim/genetics.gd")
const WorldArt = preload("res://game/world_art.gd")

const OVERLAYS := {"terrain": "Terrain", "peoples": "Peuples", "borders": "Frontières", "religion": "Religions",
	"resources": "Ressources", "climate": "Climat", "fertility": "Fertilité", "conflicts": "Conflits",
	"affinity": "Affinités", "grid": "Grille (consultation)"}
const PALETTE := {"ice": Color(0.93, 0.97, 1.0), "tundra": Color(0.7, 0.76, 0.6), "taiga": Color(0.36, 0.6, 0.4),
	"temperate_forest": Color(0.33, 0.58, 0.27), "grassland": Color(0.54, 0.74, 0.32), "desert": Color(0.96, 0.84, 0.52),
	"savanna": Color(0.82, 0.74, 0.36), "rainforest": Color(0.2, 0.58, 0.24), "mountain": Color(0.6, 0.55, 0.5),
	"snow_peak": Color(0.97, 0.98, 1.0), "ocean": Color(0.85, 0.78, 0.55), "lake": Color(0.85, 0.78, 0.55)}
const SAND := Color(0.93, 0.84, 0.6)
const ROCK := Color(0.52, 0.48, 0.45)
const SNOW := Color(0.97, 0.98, 1.0)
const WATER_SHALLOW := Color(0.33, 0.72, 0.78)
const WATER_MID := Color(0.16, 0.46, 0.72)
const WATER_DEEP := Color(0.08, 0.2, 0.45)
const RES_COLORS := {"mana": Color(0.7, 0.35, 0.95), "ore": Color(0.8, 0.35, 0.25), "fish": Color(0.3, 0.6, 0.95),
	"wood": Color(0.15, 0.5, 0.2), "game": Color(0.85, 0.6, 0.3), "stone": Color(0.6, 0.6, 0.6)}
const DETAIL := 4           # subdivisions par arête d'un triangle de simulation (16 facettes)
const OCEAN_DETAIL := 2
const LOD_FAR := 2.55
const LOD_NEAR := 1.6

var world
var art := WorldArt.new()
var overlay := "terrain"
var lod := 0                         # 0 loin, 1 moyen, 2 près
var last_build_ms := 0.0
var marker_detail := 1.0             # conservé pour compatibilité
var _built_version := -1

var _tri_count := 0
var _chunk_div := 1
var _group_div := 1
var _chunk_count := 0
var _group_count := 0
var _cell_tris: Array = []           # cellule -> triangles adjacents
var _cell_chunks: Array = []         # cellule -> chunks concernés
var _ring: Array = []                # cellule -> triangles ordonnés (polygone de Voronoï : grille, surbrillance)
var _chunk_nodes: Array = []
var _ocean_nodes: Array = []
var _chunk_data: Array = []          # {verts, normals, cells, base} par chunk
var _chunk_center: Array = []
var _group_center: Array = []
var _prop_nodes: Array = []          # groupe -> {kind: MultiMeshInstance3D}
var _village_nodes := {}             # clé -> MultiMeshInstance3D
var _cell_overlay := PackedColorArray()
var _snap_height := PackedFloat32Array()
var _snap_biome := PackedInt32Array()
var _settle_cells := {}
var _noise_detail := FastNoiseLite.new()
var _noise_ridge := FastNoiseLite.new()
var _noise_mix := FastNoiseLite.new()
var _terrain_mat: StandardMaterial3D
var _ocean_mat: StandardMaterial3D
var _prop_mat: StandardMaterial3D
var _grid_node: MeshInstance3D
var highlight_instance: MeshInstance3D
var _atmo: MeshInstance3D
var _cam_dir := Vector3.FORWARD
var _cam_dist := 3.0

# ------------------------------------------------------------------ Mise en place

func setup(p_world) -> void:
	world = p_world
	for c in get_children():
		c.queue_free()
	_village_nodes = {}
	_make_materials()
	var pl = world.planet
	_noise_detail.seed = pl.seed_value + 5
	_noise_detail.frequency = 9.0
	_noise_detail.fractal_octaves = 2
	_noise_ridge.seed = pl.seed_value + 9
	_noise_ridge.frequency = 6.0
	_noise_ridge.fractal_octaves = 3
	_noise_mix.seed = pl.seed_value + 13
	_noise_mix.frequency = 22.0
	_noise_mix.fractal_octaves = 1
	_build_topology()
	_chunk_nodes = []
	_ocean_nodes = []
	_chunk_data = []
	# Construction par chunk (80) pour des modifications rapides ; affichage par groupe (20) pour limiter
	# les appels de dessin.
	for k in _chunk_count:
		_chunk_data.append({})
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
	_prop_nodes = []
	for g in _group_count:
		_prop_nodes.append({})
	_grid_node = MeshInstance3D.new()
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1, 1, 1, 0.55)
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
	_snap_height = PackedFloat32Array()
	_cell_overlay = PackedColorArray()
	_settle_cells = {}
	_built_version = -1
	refresh(true)
	if overlay == "grid":
		_build_grid()

func _make_materials() -> void:
	_terrain_mat = StandardMaterial3D.new()
	_terrain_mat.vertex_color_use_as_albedo = true
	_terrain_mat.vertex_color_is_srgb = true
	_terrain_mat.roughness = 0.92
	_ocean_mat = StandardMaterial3D.new()
	_ocean_mat.vertex_color_use_as_albedo = true
	_ocean_mat.vertex_color_is_srgb = true
	_ocean_mat.roughness = 0.22
	_ocean_mat.metallic_specular = 0.45
	_prop_mat = StandardMaterial3D.new()
	_prop_mat.vertex_color_use_as_albedo = true
	_prop_mat.vertex_color_is_srgb = true
	_prop_mat.roughness = 0.85

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
uniform vec4 glow_color : source_color = vec4(0.35, 0.65, 1.0, 1.0);
void fragment() {
	// Coquille vue de l'intérieur : |N·V| vaut 0 au bord extérieur et ~0,45 au ras de la planète.
	float d = abs(dot(NORMAL, VIEW));
	float a = smoothstep(0.0, 0.42, d) * (1.0 - smoothstep(0.42, 0.75, d)) * 0.7;
	ALBEDO = glow_color.rgb * a;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_atmo.material_override = mat
	_atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_atmo)

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

func _tri_center(t: int) -> Vector3:
	var pl = world.planet
	return ((pl.pos[pl.tris[t * 3]] + pl.pos[pl.tris[t * 3 + 1]] + pl.pos[pl.tris[t * 3 + 2]]) / 3.0).normalized()

# ------------------------------------------------------------------ Forme du terrain

## Hauteur visuelle (unités de simulation) au point (wa, wb, wc) du triangle t.
func height_bary(t: int, wa: float, wb: float, wc: float, dir: Vector3) -> float:
	var pl = world.planet
	var ha: float = pl.height[pl.tris[t * 3]]
	var hb: float = pl.height[pl.tris[t * 3 + 1]]
	var hc: float = pl.height[pl.tris[t * 3 + 2]]
	# Poids adoucis : chaque cellule garde un cœur assez plat, transitions progressives entre cellules.
	var pa := pow(maxf(wa, 0.0), 1.6)
	var pb := pow(maxf(wb, 0.0), 1.6)
	var pc := pow(maxf(wc, 0.0), 1.6)
	var h := (ha * pa + hb * pb + hc * pc) / maxf(pa + pb + pc, 0.00001)
	h += _noise_detail.get_noise_3dv(dir) * 0.06
	var m := smoothstep(0.3, 0.62, h)
	if m > 0.0:
		var ridge := 1.0 - absf(_noise_ridge.get_noise_3dv(dir))
		h += m * (ridge * ridge) * 0.55
	return h

static func radius_of(h: float) -> float:
	return 1.0 + h * 0.07 if h >= 0.0 else 1.0 + h * 0.05

## Rayon de la surface dans une direction (pour poser objets et bâtiments). hint = cellule proche.
func surface_radius(dir: Vector3, hint: int) -> float:
	var pl = world.planet
	var cands: Array = _cell_tris[hint].duplicate()
	for nb in pl.neighbors[hint]:
		cands.append_array(_cell_tris[nb])
	for t in cands:
		var w := _bary(dir, t)
		if w.x >= -0.0001 and w.y >= -0.0001 and w.z >= -0.0001:
			return radius_of(height_bary(t, w.x, w.y, w.z, dir))
	return radius_of(pl.height[hint])

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

# ------------------------------------------------------------------ Couleurs

func _facet_color(t: int, w: Vector3, dir: Vector3, h: float, slope: float, min_h: float, facet_id: int) -> Array:
	var pl = world.planet
	# Cellule dominante avec des bords irréguliers (bruit) : transitions naturelles entre biomes.
	var jitter := _noise_mix.get_noise_3dv(dir) * 0.22
	var wa := w.x + jitter
	var wb := w.y - jitter * 0.5
	var wc := w.z - jitter * 0.5
	var k := 0
	if wb > wa and wb >= wc:
		k = 1
	elif wc > wa and wc > wb:
		k = 2
	var cell: int = pl.tris[t * 3 + k]
	var bname: String = pl.biome_name(cell)
	var col: Color = PALETTE.get(bname, Color.MAGENTA)
	var temp: float = pl.temperature[cell]
	if h < 0.0:
		col = SAND.darkened(0.25)
	elif h < 0.045 and min_h < 0.02 and bname not in ["ice", "tundra", "snow_peak"]:
		col = SAND
	if slope > 0.16 and h > 0.05:
		col = col.lerp(ROCK, clampf((slope - 0.16) * 3.5, 0.0, 0.85))
	# Neige : hauts sommets, ou altitude moyenne dans les régions froides.
	var snow_line := 0.95 - (0.45 - clampf(temp, 0.0, 0.45)) * 1.2
	if h > snow_line:
		col = col.lerp(SNOW, clampf((h - snow_line) * 5.0, 0.0, 1.0))
	elif temp < 0.15 and h >= 0.0:
		col = col.lerp(SNOW, 0.55)
	var j := float(absi(facet_id * 2654435761) % 1000) / 1000.0
	col = col.lightened(0.05 * j) if j > 0.5 else col.darkened(0.06 * j)
	return [col, cell]

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

# ------------------------------------------------------------------ Construction des chunks

func _build_chunk(k: int) -> void:
	var pl = world.planet
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cells := PackedInt32Array()
	var base := PackedColorArray()
	var overts := PackedVector3Array()
	var onorms := PackedVector3Array()
	var ocols := PackedColorArray()
	var n := DETAIL
	for t in range(k * _chunk_div, (k + 1) * _chunk_div):
		var A: Vector3 = pl.pos[pl.tris[t * 3]]
		var B: Vector3 = pl.pos[pl.tris[t * 3 + 1]]
		var C: Vector3 = pl.pos[pl.tris[t * 3 + 2]]
		var h0: float = pl.height[pl.tris[t * 3]]
		var h1: float = pl.height[pl.tris[t * 3 + 1]]
		var h2: float = pl.height[pl.tris[t * 3 + 2]]
		var hmin := minf(h0, minf(h1, h2))
		var hmax := maxf(h0, maxf(h1, h2))
		if hmax > -0.25:
			var P := {}
			var H := {}
			var W := {}
			for i in n + 1:
				for j in n + 1 - i:
					var wb := float(i) / n
					var wc := float(j) / n
					var wa := 1.0 - wb - wc
					var dir := (A * wa + B * wb + C * wc).normalized()
					var h := height_bary(t, wa, wb, wc, dir)
					P[i * 16 + j] = dir * radius_of(h)
					H[i * 16 + j] = h
					W[i * 16 + j] = Vector3(wa, wb, wc)
			for i in n:
				for j in n - i:
					_facet(t, P, H, W, i * 16 + j, (i + 1) * 16 + j, i * 16 + j + 1, verts, normals, cells, base)
					if j < n - i - 1:
						_facet(t, P, H, W, (i + 1) * 16 + j, (i + 1) * 16 + j + 1, i * 16 + j + 1, verts, normals, cells, base)
		if hmin < 0.08:
			_ocean_tri(t, A, B, C, overts, onorms, ocols)
	_chunk_data[k] = {"verts": verts, "normals": normals, "cells": cells, "base": base,
		"overts": overts, "onorms": onorms, "ocols": ocols, "colors": PackedColorArray()}
	_apply_colors(k)

func _facet(t: int, P: Dictionary, H: Dictionary, W: Dictionary, ia: int, ib: int, ic: int, verts: PackedVector3Array, normals: PackedVector3Array, cells: PackedInt32Array, base: PackedColorArray) -> void:
	var ha: float = H[ia]
	var hb: float = H[ib]
	var hc: float = H[ic]
	if ha < -0.06 and hb < -0.06 and hc < -0.06:
		return
	var a: Vector3 = P[ia]
	var b: Vector3 = P[ib]
	var c: Vector3 = P[ic]
	var nrm := (b - a).cross(c - a).normalized()
	var dir := ((a + b + c) / 3.0).normalized()
	if nrm.dot(dir) < 0.0:
		nrm = -nrm
		var tmp := b
		b = c
		c = tmp
	var h := (ha + hb + hc) / 3.0
	var w: Vector3 = (W[ia] + W[ib] + W[ic]) / 3.0
	var res := _facet_color(t, w, dir, h, 1.0 - nrm.dot(dir), minf(ha, minf(hb, hc)), t * 64 + ia + ib)
	# Sens horaire vu de l'extérieur (faces avant de Godot).
	verts.append(a); verts.append(c); verts.append(b)
	normals.append(nrm); normals.append(nrm); normals.append(nrm)
	cells.append(res[1])
	base.append(res[0])

func _ocean_tri(t: int, A: Vector3, B: Vector3, C: Vector3, overts: PackedVector3Array, onorms: PackedVector3Array, ocols: PackedColorArray) -> void:
	var pl = world.planet
	var hs := [pl.height[pl.tris[t * 3]], pl.height[pl.tris[t * 3 + 1]], pl.height[pl.tris[t * 3 + 2]]]
	var ts := [pl.temperature[pl.tris[t * 3]], pl.temperature[pl.tris[t * 3 + 1]], pl.temperature[pl.tris[t * 3 + 2]]]
	var n := OCEAN_DETAIL
	var pts := {}
	for i in n + 1:
		for j in n + 1 - i:
			var wb := float(i) / n
			var wc := float(j) / n
			var wa := 1.0 - wb - wc
			var dir := (A * wa + B * wb + C * wc).normalized()
			var h: float = hs[0] * wa + hs[1] * wb + hs[2] * wc
			var temp: float = ts[0] * wa + ts[1] * wb + ts[2] * wc
			var d := clampf(-h, 0.0, 1.0)
			var col := WATER_SHALLOW.lerp(WATER_MID, smoothstep(0.0, 0.25, d)).lerp(WATER_DEEP, smoothstep(0.25, 0.8, d))
			if temp < 0.1:
				col = col.lerp(Color(0.9, 0.95, 1.0), 0.75)
			pts[i * 16 + j] = [dir, col]
	for i in n:
		for j in n - i:
			_ocean_face(pts[i * 16 + j], pts[(i + 1) * 16 + j], pts[i * 16 + j + 1], overts, onorms, ocols)
			if j < n - i - 1:
				_ocean_face(pts[(i + 1) * 16 + j], pts[(i + 1) * 16 + j + 1], pts[i * 16 + j + 1], overts, onorms, ocols)

func _ocean_face(a: Array, b: Array, c: Array, overts: PackedVector3Array, onorms: PackedVector3Array, ocols: PackedColorArray) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	if (pb - pa).cross(pc - pa).dot(pa) < 0.0:
		var tmp := b
		b = c
		c = tmp
	overts.append(a[0]); overts.append(c[0]); overts.append(b[0])
	onorms.append(a[0]); onorms.append(c[0]); onorms.append(b[0])
	ocols.append(a[1]); ocols.append(c[1]); ocols.append(b[1])

## Couleurs finales = couleur de terrain, teintée par la carte thématique de la cellule dominante.
func _apply_colors(k: int) -> void:
	var d: Dictionary = _chunk_data[k]
	if d.is_empty():
		return
	var cells: PackedInt32Array = d.cells
	var base: PackedColorArray = d.base
	var cols := PackedColorArray()
	cols.resize(cells.size() * 3)
	var tint := overlay not in ["terrain", "grid"] and _cell_overlay.size() > 0
	for f in cells.size():
		var c: Color = base[f]
		if tint:
			var oc: Color = _cell_overlay[cells[f]]
			if oc.a > 0.0:
				c = c.lerp(Color(oc.r, oc.g, oc.b), 0.62 * oc.a)
			else:
				c = c.lerp(Color(0.55, 0.55, 0.55), 0.45)
		cols[f * 3] = c
		cols[f * 3 + 1] = c
		cols[f * 3 + 2] = c
	d.colors = cols

## Assemble les chunks d'un groupe en un seul maillage terrain et un seul maillage océan.
func _upload_group(g: int) -> void:
	var per := _group_div / _chunk_div
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	var oc := PackedColorArray()
	for k in range(g * per, (g + 1) * per):
		var d: Dictionary = _chunk_data[k]
		if d.is_empty():
			continue
		v.append_array(d.verts); n.append_array(d.normals); c.append_array(d.colors)
		ov.append_array(d.overts); on.append_array(d.onorms); oc.append_array(d.ocols)
	_chunk_nodes[g].mesh = _mesh(v, n, c)
	_ocean_nodes[g].mesh = _mesh(ov, on, oc)

static func _mesh(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray) -> ArrayMesh:
	var m := ArrayMesh.new()
	if v.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

# ------------------------------------------------------------------ Végétation et rochers (par groupe)

func _build_props(g: int) -> void:
	var pl = world.planet
	var lists := {}
	for kind in WorldArt.PROPS:
		lists[kind] = []
	var rng := RandomNumberGenerator.new()
	for t in range(g * _group_div, (g + 1) * _group_div):
		rng.seed = pl.seed_value * 7919 + t
		var A: Vector3 = pl.pos[pl.tris[t * 3]]
		var B: Vector3 = pl.pos[pl.tris[t * 3 + 1]]
		var C: Vector3 = pl.pos[pl.tris[t * 3 + 2]]
		for s in 14:
			var r1 := rng.randf()
			var r2 := rng.randf()
			var sq := sqrt(r1)
			var w := Vector3(1.0 - sq, sq * (1.0 - r2), sq * r2)
			var k := 0
			if w.y > w.x and w.y >= w.z:
				k = 1
			elif w.z > w.x and w.z > w.y:
				k = 2
			var cell: int = pl.tris[t * 3 + k]
			var kind := _prop_for(pl.biome_name(cell), pl.temperature[cell], rng)
			var yaw := rng.randf() * TAU
			var size := rng.randf_range(0.0055, 0.009)
			if kind == "":
				continue
			var dir := (A * w.x + B * w.y + C * w.z).normalized()
			if _near_settlement(dir):
				continue
			var h := height_bary(t, w.x, w.y, w.z, dir)
			if h < 0.05 and kind != "palm":
				continue
			if h < 0.01 or (h > 0.75 and kind not in ["rock", "rock_b"]):
				continue
			if kind in ["rock", "rock_b"]:
				size *= 1.4
			var basis := _basis_up(dir, yaw).scaled(Vector3.ONE * size)
			lists[kind].append(Transform3D(basis, dir * (radius_of(h) - 0.0012)))
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

func _prop_for(b: String, temp: float, rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	match b:
		"temperate_forest":
			if r < 0.4: return "broadleaf"
			if r < 0.65: return "broadleaf_b"
			if r < 0.85: return "conifer"
			if r < 0.9: return "bush"
		"rainforest":
			if r < 0.45: return "broadleaf_b"
			if r < 0.75: return "broadleaf"
			if r < 0.95: return "palm"
		"taiga":
			if r < 0.5: return "snow_conifer" if temp < 0.33 else "conifer"
			if r < 0.88: return "conifer_b"
			if r < 0.93: return "rock"
		"grassland":
			if r < 0.07: return "broadleaf"
			if r < 0.16: return "bush"
			if r < 0.19: return "rock"
		"savanna":
			if r < 0.14: return "acacia"
			if r < 0.22: return "bush"
		"desert":
			if r < 0.06: return "cactus"
			if r < 0.12: return "rock"
		"tundra":
			if r < 0.12: return "rock"
			if r < 0.2: return "snow_conifer"
		"mountain":
			if r < 0.3: return "rock_b"
			if r < 0.5: return "rock"
			if r < 0.62: return "conifer_b"
		"snow_peak":
			if r < 0.15: return "rock_b"
	return ""

func _near_settlement(dir: Vector3) -> bool:
	for c in _settle_cells:
		if world.planet.pos[c].dot(dir) > 0.9991:
			return true
	return false

static func _basis_up(up: Vector3, yaw: float) -> Basis:
	var x := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z) * Basis(Vector3.UP, yaw)

# ------------------------------------------------------------------ Villages (reflet exact des établissements)

func _build_villages() -> void:
	if world == null:
		return
	var lists := {}
	var banner_scale := 3.2 if lod == 0 else (1.6 if lod == 1 else 1.0)
	var vs := 1.6 if lod == 1 else 1.0   # villages agrandis à distance moyenne (repères)
	for s in world.settlements:
		if not s.alive:
			continue
		var p: Dictionary = world.peoples[int(s.people)]
		var era := clampi(int(p.era), 0, 5)
		var pc := Color(p.color[0], p.color[1], p.color[2])
		var dcol: Array = world.deities[int(p.deity)].color
		var cell := int(s.cell)
		var center: Vector3 = world.planet.pos[cell]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(s.id) * 104729
		var pop := float(s.pop)
		var bsize := 0.016 * banner_scale * clampf(0.8 + sqrt(pop) / 40.0, 0.8, 1.6)
		_add_inst(lists, "banner_%d" % int(p.id), art.banner_mesh(p.species, pc, Color(dcol[0], dcol[1], dcol[2])), _place(center, cell, rng.randf() * TAU, bsize))
		if lod == 0:
			continue
		# Bâtiment central selon les institutions réelles du peuple.
		var ckind := "fire"
		if era >= 5:
			ckind = "spire"
		elif p.techs.has("forteresses"):
			ckind = "keep"
		elif p.techs.has("clerge") or (p.techs.has("rites") and pop > 60):
			ckind = "temple"
		elif era >= 1 or pop > 80:
			ckind = "hall"
		var cdir := (center + _tangent(center, 0.3) * 0.006 * vs).normalized()
		_add_inst(lists, "c_%s_%d_%d" % [ckind, int(p.id), era], art.center_mesh(ckind, p.species, era, pc), _place(cdir, cell, rng.randf() * TAU, 0.0105 * vs))
		# Maisons : nombre selon la population réelle, disposées en spirale.
		var count := clampi(int(round(sqrt(pop) / 2.2)), 1, 16)
		var house := art.house_mesh(p.species, era, pc, float(p.lean))
		for i in count:
			var ang := i * 2.39996 + rng.randf() * 0.3
			var rad := (0.011 + 0.0062 * sqrt(i + 1)) * vs
			var dir := (center + _tangent(center, ang) * rad).normalized()
			_add_inst(lists, "h_%d_%d" % [int(p.id), era], house, _place(dir, cell, rng.randf() * TAU, rng.randf_range(0.009, 0.0115) * vs))
		# Fortifications : palissade, puis muraille avec la technique Fortifications.
		if p.techs.has("forteresses") or (era >= 1 and pop > 150):
			var stone: bool = p.techs.has("forteresses")
			var ring_r := (0.011 + 0.0062 * sqrt(count + 1) + 0.006) * vs
			var segs := 14
			for i in segs:
				var ang2 := TAU * i / segs
				var dir2 := (center + _tangent(center, ang2) * ring_r).normalized()
				var x := _tangent(center, ang2 + PI / 2.0)
				var z := x.cross(dir2).normalized()
				var basis := Basis(x, dir2, z).scaled(Vector3.ONE * 0.0085 * vs)
				_add_inst(lists, "wall_%s" % stone, art.wall_mesh(stone), Transform3D(basis, dir2 * (surface_radius(dir2, cell) - 0.0008)))
		# Habitants représentatifs (de près, établissements face à la caméra), tirés des vraies distributions.
		if lod == 2 and center.dot(_cam_dir) > 0.97:
			var inds: Array = Genetics.representatives(world.cat, s, p.species, 6, int(s.id) * 31 + world.year)
			for i in inds.size():
				var ang3 := TAU * i / inds.size() + 0.4
				var dir3 := (center + _tangent(center, ang3) * 0.0068).normalized()
				var aff: String = inds[i].affinity
				_add_inst(lists, "f_%d_%s" % [int(p.id), aff], art.figure_mesh(pc, aff), _place(dir3, cell, ang3 + PI, 0.0036))
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

func _add_inst(lists: Dictionary, key: String, mesh: Mesh, xf: Transform3D) -> void:
	if not lists.has(key):
		lists[key] = [mesh, []]
	lists[key][1].append(xf)

func _place(dir: Vector3, hint: int, yaw: float, size: float) -> Transform3D:
	var basis := _basis_up(dir, yaw).scaled(Vector3.ONE * size)
	return Transform3D(basis, dir * (surface_radius(dir, hint) - 0.0006))

func _tangent(n: Vector3, ang: float) -> Vector3:
	var x := n.cross(Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := n.cross(x)
	return x * cos(ang) + z * sin(ang)

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
	var d := _tri_center(t)
	return d * maxf(radius_of(height_bary(t, 1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0, d)), 1.0) * 1.002

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

## Reconstruit uniquement ce qui a changé : chunks dont les cellules ont changé, couleurs thématiques modifiées,
## végétation des groupes touchés, villages (léger, lu dans la simulation).
func refresh(force: bool = false) -> void:
	if world == null:
		return
	var t0 := Time.get_ticks_usec()
	var pl = world.planet
	var dirty_chunks := {}
	var dirty_groups := {}
	if _snap_height.size() != pl.cell_count:
		for k in _chunk_count:
			dirty_chunks[k] = true
		for g in _group_count:
			dirty_groups[g] = true
	elif pl.version != _built_version:
		for i in pl.cell_count:
			if _snap_height[i] != pl.height[i] or _snap_biome[i] != pl.biome[i]:
				for k in _cell_chunks[i]:
					dirty_chunks[k] = true
					dirty_groups[k * _chunk_div / _group_div] = true
		if not dirty_chunks.is_empty() and _grid_node.mesh != null:
			_build_grid()
	_snap_height = pl.height.duplicate()
	_snap_biome = pl.biome.duplicate()
	var sc := {}
	for s in world.settlements:
		if s.alive:
			sc[int(s.cell)] = true
	for c in sc:
		if not _settle_cells.has(c):
			for k in _cell_chunks[c]:
				dirty_groups[k * _chunk_div / _group_div] = true
	for c in _settle_cells:
		if not sc.has(c):
			for k in _cell_chunks[c]:
				dirty_groups[k * _chunk_div / _group_div] = true
	_settle_cells = sc
	var new_overlay := _compute_overlay()
	var overlay_changed := force or new_overlay != _cell_overlay
	var old_overlay := _cell_overlay
	_cell_overlay = new_overlay
	var upload := {}
	for k in dirty_chunks:
		_build_chunk(k)
		upload[k * _chunk_div / _group_div] = true
	if overlay_changed:
		var changed := {}
		if force or old_overlay.size() != new_overlay.size():
			for k in _chunk_count:
				changed[k] = true
		else:
			for i in new_overlay.size():
				if new_overlay[i] != old_overlay[i]:
					for k in _cell_chunks[i]:
						changed[k] = true
		for k in changed:
			if not dirty_chunks.has(k):
				_apply_colors(k)
				upload[k * _chunk_div / _group_div] = true
	for g in upload:
		_upload_group(g)
	for g in dirty_groups:
		_build_props(g)
	_build_villages()
	_built_version = pl.version
	last_build_ms = (Time.get_ticks_usec() - t0) / 1000.0

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
	# Végétation : absente de loin, moitié des instances à distance moyenne, tout de près (ombres comprises).
	var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for g in _group_count:
		var gvis: bool = lod >= 1 and _group_center[g].dot(_cam_dir) > horizon - 0.5
		for kind in _prop_nodes[g]:
			var node: MultiMeshInstance3D = _prop_nodes[g][kind]
			node.visible = gvis
			if gvis:
				var mm := node.multimesh
				mm.visible_instance_count = -1 if lod == 2 else mm.instance_count / 2
				node.cast_shadow = shadow

func vertex_count() -> int:
	var n := 0
	for d in _chunk_data:
		if not d.is_empty():
			n += d.verts.size()
	return n
