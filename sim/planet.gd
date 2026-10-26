extends RefCounted
## Planète : grille géodésique (icosaèdre subdivisé). Chaque sommet est une cellule.
## Source unique de vérité pour le rendu, les territoires, les déplacements et la sélection.

const BIOMES := ["ocean", "lake", "ice", "tundra", "taiga", "temperate_forest", "grassland", "desert", "savanna", "rainforest", "mountain", "snow_peak"]
const BIOME_NAMES := {"ocean": "Océan", "lake": "Lac", "ice": "Glacier", "tundra": "Toundra", "taiga": "Taïga",
	"temperate_forest": "Forêt tempérée", "grassland": "Prairie", "desert": "Désert", "savanna": "Savane",
	"rainforest": "Jungle", "mountain": "Montagne", "snow_peak": "Sommet enneigé"}
const BIOME_FOOD := {"ocean": 0.0, "lake": 0.0, "ice": 0.05, "tundra": 0.3, "taiga": 0.55, "temperate_forest": 0.8,
	"grassland": 1.0, "desert": 0.15, "savanna": 0.7, "rainforest": 0.85, "mountain": 0.3, "snow_peak": 0.05}
const RES := ["wood", "stone", "ore", "game", "fish", "mana"]
const RES_NAMES := {"wood": "Bois", "stone": "Pierre", "ore": "Minerai", "game": "Gibier", "fish": "Poisson", "mana": "Cristaux de mana"}

var seed_value: int = 0
var subdivisions: int = 4
var cell_count: int = 0
var pos := PackedVector3Array()
var neighbors: Array = []            # Array[PackedInt32Array]
var tris := PackedInt32Array()       # triangles (3 indices) de la grille
var base_height := PackedFloat32Array()
var height_delta := PackedFloat32Array()   # modifications du joueur et des pouvoirs
var temp_offset := PackedFloat32Array()
var moist_offset := PackedFloat32Array()
var fert_offset := PackedFloat32Array()
var res_extra := PackedInt32Array()        # ressources ajoutées par les pouvoirs (masque)
# Dérivés (recalculés)
var height := PackedFloat32Array()
var temperature := PackedFloat32Array()
var moisture := PackedFloat32Array()
var fertility := PackedFloat32Array()
var biome := PackedInt32Array()
var resources := PackedInt32Array()
var water_dist := PackedInt32Array()
var _moist_noise := PackedFloat32Array()
var _mana_noise := PackedFloat32Array()
var _ore_noise := PackedFloat32Array()
var version: int = 0                       # incrémenté à chaque modification (pour le rendu)

func generate(p_seed: int, p_subdivisions: int = 4) -> void:
	seed_value = p_seed
	subdivisions = p_subdivisions
	_build_grid(p_subdivisions)
	var n := cell_count
	height_delta.resize(n); temp_offset.resize(n); moist_offset.resize(n); fert_offset.resize(n); res_extra.resize(n)
	height_delta.fill(0.0); temp_offset.fill(0.0); moist_offset.fill(0.0); fert_offset.fill(0.0); res_extra.fill(0)
	_generate_noise()
	recompute()

# --- Grille ---------------------------------------------------------------

func _build_grid(levels: int) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for _l in levels:
		var cache := {}
		var nf: Array = []
		for f in faces:
			var a := _midpoint(f[0], f[1], verts, cache)
			var b := _midpoint(f[1], f[2], verts, cache)
			var c := _midpoint(f[2], f[0], verts, cache)
			nf.append([f[0], a, c]); nf.append([f[1], b, a]); nf.append([f[2], c, b]); nf.append([a, b, c])
		faces = nf
	cell_count = verts.size()
	pos = PackedVector3Array(verts)
	tris = PackedInt32Array()
	var nb: Array = []
	for i in cell_count:
		nb.append({})
	for f in faces:
		tris.append(f[0]); tris.append(f[1]); tris.append(f[2])
		for k in 3:
			nb[f[k]][f[(k + 1) % 3]] = true
			nb[f[k]][f[(k + 2) % 3]] = true
	neighbors = []
	for i in cell_count:
		neighbors.append(PackedInt32Array(nb[i].keys()))

func _midpoint(a: int, b: int, verts: Array, cache: Dictionary) -> int:
	var key := mini(a, b) * 1000003 + maxi(a, b)
	if cache.has(key):
		return cache[key]
	verts.append(((verts[a] + verts[b]) * 0.5).normalized())
	cache[key] = verts.size() - 1
	return verts.size() - 1

# --- Génération -----------------------------------------------------------

func _make_noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var nz := FastNoiseLite.new()
	nz.seed = s
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = freq
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = octaves
	return nz

func _generate_noise() -> void:
	var n := cell_count
	var continent := _make_noise(seed_value, 0.9, 4)
	var detail := _make_noise(seed_value + 17, 2.6, 3)
	var moist := _make_noise(seed_value + 101, 1.4, 3)
	var mana := _make_noise(seed_value + 211, 2.2, 2)
	var ore := _make_noise(seed_value + 307, 3.0, 2)
	var raw := PackedFloat32Array()
	raw.resize(n)
	_moist_noise.resize(n); _mana_noise.resize(n); _ore_noise.resize(n)
	for i in n:
		var p := pos[i] * 1.6
		raw[i] = continent.get_noise_3dv(p) + 0.35 * detail.get_noise_3dv(p)
		_moist_noise[i] = moist.get_noise_3dv(p) * 0.5 + 0.5
		_mana_noise[i] = mana.get_noise_3dv(p) * 0.5 + 0.5
		_ore_noise[i] = ore.get_noise_3dv(p) * 0.5 + 0.5
	# Niveau de la mer au 62e centile : ~38 % de terres.
	var sorted := raw.duplicate()
	sorted.sort()
	var sea := sorted[int(n * 0.62)]
	var top := sorted[n - 1] - sea
	var bottom := sea - sorted[0]
	base_height.resize(n)
	for i in n:
		var h := raw[i] - sea
		base_height[i] = h / top if h >= 0.0 else h / bottom

# --- Climat, biomes, ressources ---------------------------------------------

func recompute() -> void:
	var n := cell_count
	height.resize(n); temperature.resize(n); moisture.resize(n); fertility.resize(n)
	biome.resize(n); resources.resize(n); water_dist.resize(n)
	for i in n:
		height[i] = clampf(base_height[i] + height_delta[i], -1.0, 1.0)
	_compute_water_distance()
	var lake := _find_lakes()
	for i in n:
		var lat := absf(pos[i].y)
		var h := height[i]
		var t := 1.0 - pow(lat, 1.4) * 1.05 - maxf(h, 0.0) * 0.55 + temp_offset[i]
		temperature[i] = clampf(t, 0.0, 1.0)
		var m := _moist_noise[i] * 0.75 + 0.35 * exp(-float(water_dist[i]) / 3.0) - 0.1 + moist_offset[i]
		moisture[i] = clampf(m, 0.0, 1.0)
		var b := _classify(i, lake.has(i))
		biome[i] = b
		var bname: String = BIOMES[b]
		fertility[i] = clampf(BIOME_FOOD[bname] * (0.5 + moisture[i] * 0.6) + fert_offset[i], 0.0, 1.0) if h >= 0.0 else 0.0
		resources[i] = _natural_resources(i, bname) | res_extra[i]
	version += 1

func _classify(i: int, is_lake: bool) -> int:
	var h := height[i]
	var t := temperature[i]
	var m := moisture[i]
	if h < 0.0:
		if t < 0.08:
			return BIOMES.find("ice")
		return BIOMES.find("lake") if is_lake else BIOMES.find("ocean")
	if h > 0.62:
		return BIOMES.find("snow_peak") if t < 0.4 else BIOMES.find("mountain")
	if h > 0.42:
		return BIOMES.find("mountain")
	if t < 0.12:
		return BIOMES.find("ice")
	if t < 0.3:
		return BIOMES.find("tundra")
	if t < 0.45:
		return BIOMES.find("taiga") if m > 0.35 else BIOMES.find("tundra")
	if t < 0.72:
		if m < 0.25:
			return BIOMES.find("desert")
		return BIOMES.find("grassland") if m < 0.52 else BIOMES.find("temperate_forest")
	if m < 0.3:
		return BIOMES.find("desert")
	return BIOMES.find("savanna") if m < 0.55 else BIOMES.find("rainforest")

func _natural_resources(i: int, bname: String) -> int:
	var r := 0
	if height[i] < 0.0:
		return (1 << RES.find("fish")) if bname != "ice" else 0
	if bname in ["taiga", "temperate_forest", "rainforest"]:
		r |= 1 << RES.find("wood")
	if bname in ["mountain", "snow_peak"] or height[i] > 0.3:
		r |= 1 << RES.find("stone")
	if (bname in ["mountain", "snow_peak"] or height[i] > 0.25) and _ore_noise[i] > 0.5:
		r |= 1 << RES.find("ore")
	if bname in ["grassland", "temperate_forest", "savanna", "taiga", "rainforest"]:
		r |= 1 << RES.find("game")
	if water_dist[i] == 1:
		r |= 1 << RES.find("fish")
	if _mana_noise[i] > 0.7:
		r |= 1 << RES.find("mana")
	return r

func _compute_water_distance() -> void:
	var n := cell_count
	water_dist.fill(9999)
	var queue: Array = []
	for i in n:
		if height[i] < 0.0:
			water_dist[i] = 0
			queue.append(i)
	var head := 0
	while head < queue.size():
		var c: int = queue[head]
		head += 1
		for nb in neighbors[c]:
			if water_dist[nb] > water_dist[c] + 1:
				water_dist[nb] = water_dist[c] + 1
				queue.append(nb)

## Composantes d'eau de petite taille = lacs.
func _find_lakes() -> Dictionary:
	var seen := {}
	var lakes := {}
	var limit := maxi(4, int(cell_count * 0.015))
	for i in cell_count:
		if height[i] >= 0.0 or seen.has(i):
			continue
		var comp: Array = [i]
		seen[i] = true
		var head := 0
		while head < comp.size():
			var c: int = comp[head]
			head += 1
			for nb in neighbors[c]:
				if height[nb] < 0.0 and not seen.has(nb):
					seen[nb] = true
					comp.append(nb)
		if comp.size() <= limit:
			for c in comp:
				lakes[c] = true
	return lakes

# --- Requêtes ----------------------------------------------------------------

func is_land(i: int) -> bool:
	return height[i] >= 0.0

func biome_name(i: int) -> String:
	return BIOMES[biome[i]]

func has_res(i: int, res: String) -> bool:
	return resources[i] & (1 << RES.find(res)) != 0

func res_list(i: int) -> Array:
	var out := []
	for r in RES:
		if has_res(i, r):
			out.append(r)
	return out

func is_coastal(i: int) -> bool:
	return water_dist[i] == 1

## Cellules à moins de `radius` sauts (BFS), limitée à `max_cells`.
func cells_within(center: int, radius: int, max_cells: int = 400) -> Array:
	var dist := {center: 0}
	var out: Array = [center]
	var head := 0
	while head < out.size() and out.size() < max_cells:
		var c: int = out[head]
		head += 1
		if dist[c] >= radius:
			continue
		for nb in neighbors[c]:
			if not dist.has(nb):
				dist[nb] = dist[c] + 1
				out.append(nb)
	return out

func nearest_cell(dir: Vector3) -> int:
	var d := dir.normalized()
	var best := 0
	var best_dot := -2.0
	for i in cell_count:
		var v := pos[i].dot(d)
		if v > best_dot:
			best_dot = v
			best = i
	return best

# --- Modifications (pouvoirs, pinceaux) ----------------------------------

func add_height(cells: Array, amount: float, falloff: bool = true, noise_rng: RandomNumberGenerator = null) -> void:
	var center: Vector3 = pos[cells[0]]
	for c in cells:
		var f := 1.0
		if falloff and cells.size() > 1:
			f = clampf(1.0 - pos[c].distance_to(center) * 4.0, 0.35, 1.0)
		var a := amount * f
		if noise_rng != null:
			a *= noise_rng.randf_range(-1.0, 1.0)
		height_delta[c] = clampf(height_delta[c] + a, -2.0, 2.0)

func add_offset(arr_name: String, cells: Array, amount: float) -> void:
	var arr: PackedFloat32Array = get(arr_name)
	for c in cells:
		arr[c] = clampf(arr[c] + amount, -1.0, 1.0)
	set(arr_name, arr)

func add_resource(cells: Array, res: String) -> void:
	var bit := 1 << RES.find(res)
	for c in cells:
		if res == "fish":
			if height[c] < 0.0 or is_coastal(c):
				res_extra[c] |= bit
		elif height[c] >= 0.0:
			res_extra[c] |= bit

# --- Sérialisation -------------------------------------------------------
# On ne sauvegarde que la graine et les deltas : tout le reste est recalculé.

func to_dict() -> Dictionary:
	return {"seed": seed_value, "subdivisions": subdivisions,
		"height_delta": _sparse(height_delta), "temp_offset": _sparse(temp_offset),
		"moist_offset": _sparse(moist_offset), "fert_offset": _sparse(fert_offset),
		"res_extra": _sparse_int(res_extra)}

func from_dict(d: Dictionary) -> void:
	generate(int(d.seed), int(d.get("subdivisions", 4)))
	_unsparse(height_delta, d.get("height_delta", {}))
	_unsparse(temp_offset, d.get("temp_offset", {}))
	_unsparse(moist_offset, d.get("moist_offset", {}))
	_unsparse(fert_offset, d.get("fert_offset", {}))
	for k in d.get("res_extra", {}):
		res_extra[int(k)] = int(d.res_extra[k])
	recompute()

func _sparse(arr: PackedFloat32Array) -> Dictionary:
	var out := {}
	for i in arr.size():
		if absf(arr[i]) > 0.0001:
			out[str(i)] = arr[i]
	return out

func _sparse_int(arr: PackedInt32Array) -> Dictionary:
	var out := {}
	for i in arr.size():
		if arr[i] != 0:
			out[str(i)] = arr[i]
	return out

func _unsparse(arr: PackedFloat32Array, d: Dictionary) -> void:
	for k in d:
		arr[int(k)] = float(d[k])

func edited_cell_count() -> int:
	var c := 0
	for i in cell_count:
		if absf(height_delta[i]) > 0.0001 or absf(temp_offset[i]) > 0.0001 or absf(moist_offset[i]) > 0.0001 or absf(fert_offset[i]) > 0.0001 or res_extra[i] != 0:
			c += 1
	return c
