extends Node3D
## Rendu low poly de la planète : chaque cellule de la simulation est dessinée comme son polygone de Voronoï
## (même indexation que sim/planet.gd → sélection, territoires et terrain sont cohérents).

const Planet = preload("res://sim/planet.gd")
const Faith = preload("res://sim/faith_system.gd")

const OVERLAYS := {"terrain": "Terrain", "peoples": "Peuples", "borders": "Frontières", "religion": "Religions",
	"resources": "Ressources", "climate": "Climat", "fertility": "Fertilité", "conflicts": "Conflits", "affinity": "Affinités"}
const BIOME_COLORS := {"ocean": Color(0.16, 0.38, 0.62), "lake": Color(0.25, 0.55, 0.78), "ice": Color(0.9, 0.95, 0.98),
	"tundra": Color(0.62, 0.66, 0.58), "taiga": Color(0.25, 0.45, 0.35), "temperate_forest": Color(0.3, 0.58, 0.3),
	"grassland": Color(0.55, 0.72, 0.36), "desert": Color(0.88, 0.78, 0.5), "savanna": Color(0.74, 0.7, 0.38),
	"rainforest": Color(0.16, 0.5, 0.24), "mountain": Color(0.52, 0.47, 0.42), "snow_peak": Color(0.95, 0.96, 0.98)}
const RES_COLORS := {"mana": Color(0.7, 0.35, 0.95), "ore": Color(0.75, 0.35, 0.25), "fish": Color(0.3, 0.6, 0.95),
	"wood": Color(0.2, 0.55, 0.25), "game": Color(0.8, 0.6, 0.3), "stone": Color(0.6, 0.6, 0.6)}
const STAGE_COUNT := 6

var world
var overlay := "terrain"
var height_scale := 0.06
var mesh_instance: MeshInstance3D
var highlight_instance: MeshInstance3D
var markers: Array = []          # MultiMeshInstance3D par époque
var _ring: Array = []            # cellule -> PackedInt32Array de triangles ordonnés
var _ring_nb: Array = []         # cellule -> voisin de l'autre côté de chaque arête du polygone
var _centroid := PackedVector3Array()
var _built_version := -1
var _built_overlay := ""
var last_build_ms := 0.0
var marker_detail := 1.0

func setup(p_world) -> void:
	world = p_world
	height_scale = float(world.cat.cfg("planet", "height_scale", 0.06))
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh_instance.material_override = mat
		add_child(mesh_instance)
		highlight_instance = MeshInstance3D.new()
		var hm := StandardMaterial3D.new()
		hm.vertex_color_use_as_albedo = true
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.cull_mode = BaseMaterial3D.CULL_DISABLED
		highlight_instance.material_override = hm
		add_child(highlight_instance)
		_create_markers()
	_build_topology()
	_built_version = -1
	refresh(true)

func _build_topology() -> void:
	var pl = world.planet
	var n: int = pl.cell_count
	var tri_count: int = pl.tris.size() / 3
	_centroid.resize(tri_count)
	var cell_tris: Array = []
	for i in n:
		cell_tris.append([])
	for t in tri_count:
		var a: int = pl.tris[t * 3]
		var b: int = pl.tris[t * 3 + 1]
		var c: int = pl.tris[t * 3 + 2]
		_centroid[t] = ((pl.pos[a] + pl.pos[b] + pl.pos[c]) / 3.0).normalized()
		cell_tris[a].append(t); cell_tris[b].append(t); cell_tris[c].append(t)
	_ring = []
	_ring_nb = []
	for i in n:
		var normal: Vector3 = pl.pos[i]
		var tangent := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
		var bitangent := normal.cross(tangent)
		var list: Array = cell_tris[i]
		list.sort_custom(func(x, y):
			var vx: Vector3 = _centroid[x] - normal
			var vy: Vector3 = _centroid[y] - normal
			return atan2(vx.dot(bitangent), vx.dot(tangent)) < atan2(vy.dot(bitangent), vy.dot(tangent)))
		_ring.append(PackedInt32Array(list))
		var nbs := PackedInt32Array()
		for k in list.size():
			nbs.append(_shared_vertex(list[k], list[(k + 1) % list.size()], i))
		_ring_nb.append(nbs)

func _shared_vertex(t1: int, t2: int, exclude: int) -> int:
	var pl = world.planet
	for x in 3:
		var v: int = pl.tris[t1 * 3 + x]
		if v == exclude:
			continue
		for y in 3:
			if pl.tris[t2 * 3 + y] == v:
				return v
	return exclude

func cell_radius(i: int) -> float:
	var h: float = world.planet.height[i]
	if h < 0.0:
		return 1.0
	return 1.004 + snappedf(h, 0.08) * height_scale

func cell_surface(i: int) -> Vector3:
	return world.planet.pos[i] * cell_radius(i)

func set_overlay(o: String) -> void:
	overlay = o
	refresh(true)

## Reconstruit le maillage si le terrain ou la carte thématique ont changé.
func refresh(force: bool = false) -> void:
	if world == null:
		return
	if force or world.planet.version != _built_version or overlay != _built_overlay or overlay in ["peoples", "borders", "religion", "conflicts", "affinity"]:
		_build_mesh()
	update_markers()

func _build_mesh() -> void:
	var t0 := Time.get_ticks_usec()
	var pl = world.planet
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var ctx := _overlay_context()
	for i in pl.cell_count:
		var r := cell_radius(i)
		var col := _cell_color(i, ctx)
		var n: Vector3 = pl.pos[i]
		var ring: PackedInt32Array = _ring[i]
		var m := ring.size()
		var center := n * r
		for k in m:
			var a: Vector3 = _centroid[ring[k]] * r
			var b: Vector3 = _centroid[ring[(k + 1) % m]] * r
			verts.append(center); verts.append(b); verts.append(a)
			normals.append(n); normals.append(n); normals.append(n)
			colors.append(col); colors.append(col); colors.append(col)
			# Falaise vers le voisin plus bas.
			var nb: int = _ring_nb[i][k]
			var rn := cell_radius(nb)
			if rn < r - 0.0005:
				var a2: Vector3 = _centroid[ring[k]] * rn
				var b2: Vector3 = _centroid[ring[(k + 1) % m]] * rn
				var wn := ((a + b) * 0.5 - center).normalized()
				var wc := col.darkened(0.25)
				verts.append(a); verts.append(b); verts.append(b2)
				verts.append(a); verts.append(b2); verts.append(a2)
				for q in 6:
					normals.append(wn)
					colors.append(wc)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	_built_version = pl.version
	_built_overlay = overlay
	last_build_ms = (Time.get_ticks_usec() - t0) / 1000.0

func vertex_count() -> int:
	if mesh_instance.mesh == null:
		return 0
	return mesh_instance.mesh.surface_get_array_len(0)

func _overlay_context() -> Dictionary:
	var ctx := {}
	if overlay == "conflicts":
		var war_people := {}
		for k in world.relations:
			if world.relations[k].war:
				for part in k.split(":"):
					war_people[int(part)] = true
		ctx["war"] = war_people
	return ctx

func _cell_color(i: int, ctx: Dictionary) -> Color:
	var pl = world.planet
	var bname: String = pl.biome_name(i)
	var base: Color = BIOME_COLORS.get(bname, Color.MAGENTA)
	if pl.height[i] < 0.0 and bname == "ocean":
		base = base.darkened(clampf(-pl.height[i] * 0.5, 0.0, 0.4))
	var muted := base.lerp(Color(0.5, 0.5, 0.5), 0.55)
	var o: int = world.owner[i]
	var s: Dictionary = world.settlements[o] if o >= 0 else {}
	match overlay:
		"terrain":
			return base
		"peoples":
			if s.is_empty():
				return muted
			var pc: Array = world.peoples[int(s.people)].color
			return Color(pc[0], pc[1], pc[2]).lerp(base, 0.25)
		"borders":
			if s.is_empty():
				return muted
			var pc2: Array = world.peoples[int(s.people)].color
			var edge := false
			for nb in pl.neighbors[i]:
				var on: int = world.owner[nb]
				if on < 0 or int(world.settlements[on].people) != int(s.people):
					edge = true
			return Color(pc2[0], pc2[1], pc2[2]).darkened(0.35) if edge else muted.lerp(Color(pc2[0], pc2[1], pc2[2]), 0.3)
		"religion":
			if s.is_empty():
				return muted
			var m := Faith.main_religion(s)
			if m == "":
				return Color(0.35, 0.35, 0.35)
			var dc: Array = world.deities[int(world.religions[int(m)].deity)].color
			return Color(dc[0], dc[1], dc[2]).lerp(muted, 1.0 - clampf(float(s.faith[m]), 0.2, 1.0))
		"resources":
			for r in ["mana", "ore", "fish", "wood", "game", "stone"]:
				if pl.has_res(i, r):
					return RES_COLORS[r] if pl.is_land(i) or r == "fish" else muted
			return muted
		"climate":
			return Color(0.2, 0.35, 0.95).lerp(Color(0.95, 0.3, 0.15), pl.temperature[i]).lerp(Color(0.2, 0.7, 0.3), pl.moisture[i] * 0.3)
		"fertility":
			if not pl.is_land(i):
				return muted
			return Color(0.6, 0.45, 0.3).lerp(Color(0.2, 0.8, 0.2), pl.fertility[i])
		"conflicts":
			if s.is_empty():
				return muted
			if ctx.war.has(int(s.people)):
				return Color(0.9, 0.15, 0.1)
			return muted.lerp(Color(0.95, 0.95, 0.95), 0.3)
		"affinity":
			if s.is_empty():
				return muted
			var tot := maxf(float(s.aff.none) + float(s.aff.magic) + float(s.aff.sword) + float(s.aff.both), 1.0)
			var mg := (float(s.aff.magic) + float(s.aff.both)) / tot
			var sw := (float(s.aff.sword) + float(s.aff.both)) / tot
			return Color(0.3 + sw * 3.0, 0.3, 0.3 + mg * 3.0).clamp()
	return base

# ------------------------------------------------------------------ Marqueurs d'établissements

func _create_markers() -> void:
	var meshes := []
	var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 0.5; cone.height = 1.0; cone.radial_segments = 6; cone.rings = 1
	var hut := BoxMesh.new(); hut.size = Vector3(0.8, 0.7, 0.8)
	var house := PrismMesh.new(); house.size = Vector3(0.9, 1.1, 0.9)
	var tower := CylinderMesh.new(); tower.top_radius = 0.28; tower.bottom_radius = 0.38; tower.height = 1.8; tower.radial_segments = 6; tower.rings = 1
	var spire := CylinderMesh.new(); spire.top_radius = 0.05; spire.bottom_radius = 0.35; spire.height = 2.4; spire.radial_segments = 5; spire.rings = 1
	var crystal := SphereMesh.new(); crystal.radius = 0.45; crystal.height = 2.6; crystal.radial_segments = 6; crystal.rings = 3
	meshes = [cone, hut, house, tower, spire, crystal]
	for k in STAGE_COUNT:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[k]
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.7
		if k >= 4:
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.7, 1.0)
			mat.emission_energy_multiplier = 0.4
		mmi.material_override = mat
		add_child(mmi)
		markers.append(mmi)

## Niveau de détail : plus de bâtiments affichés quand la caméra est proche.
func update_markers() -> void:
	if world == null or markers.is_empty():
		return
	var per_stage := []
	for k in STAGE_COUNT:
		per_stage.append([])
	for s in world.settlements:
		if not s.alive:
			continue
		var p: Dictionary = world.peoples[int(s.people)]
		var stage := clampi(int(p.era), 0, STAGE_COUNT - 1)
		var pop := float(s.pop)
		var count := clampi(int(sqrt(pop) / 4.0 * marker_detail), 1, 9)
		var col := Color(p.color[0], p.color[1], p.color[2])
		var center_cell := int(s.cell)
		var cells: Array = s.territory
		var rng := RandomNumberGenerator.new()
		rng.seed = int(s.id) * 7919
		for b in count:
			var cell := center_cell
			if b > 0 and cells.size() > 1:
				cell = int(cells[rng.randi_range(0, cells.size() - 1)])
			var dir: Vector3 = world.planet.pos[cell]
			var jitter := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * (0.012 if b > 0 else 0.0)
			dir = (dir + jitter).normalized()
			var size := 0.010 + (0.006 if b == 0 else 0.0) + clampf(pop / 4000.0, 0.0, 0.01)
			var basis := _basis_up(dir).scaled(Vector3.ONE * size)
			var pos := dir * (cell_radius(cell) + size * 0.5)
			per_stage[stage].append([Transform3D(basis, pos), col if b > 0 else col.lightened(0.25)])
	for k in STAGE_COUNT:
		var mm: MultiMesh = markers[k].multimesh
		var items: Array = per_stage[k]
		mm.instance_count = items.size()
		for j in items.size():
			mm.set_instance_transform(j, items[j][0])
			mm.set_instance_color(j, items[j][1])

func _basis_up(up: Vector3) -> Basis:
	var x := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)

# ------------------------------------------------------------------ Surbrillance (sélection, prévisualisation)

func highlight(cells: Array, color: Color) -> void:
	if cells.is_empty():
		highlight_instance.mesh = null
		return
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for c in cells:
		var i := int(c)
		var r := cell_radius(i) + 0.003
		var ring: PackedInt32Array = _ring[i]
		var center: Vector3 = world.planet.pos[i] * r
		for k in ring.size():
			verts.append(center)
			verts.append(_centroid[ring[(k + 1) % ring.size()]] * r)
			verts.append(_centroid[ring[k]] * r)
			for q in 3:
				colors.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	highlight_instance.mesh = mesh
