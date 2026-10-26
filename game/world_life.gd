extends Node3D
## Vie visible du monde, sans effet sur la simulation :
## - routes entre établissements voisins d'un même peuple (terre battue, puis pavées à partir de l'époque 2) ;
## - ports et bateaux pour les établissements côtiers qui connaissent la navigation ;
## - convois de colons, du village d'origine (champ « from ») jusqu'au nouvel établissement ;
## - habitants qui circulent dans les villages proches de la caméra.

const ROAD_MAX := 0.3          # distance maximale (corde) entre deux villages reliés
const ROAD_W := 0.0045
const CONVOY_SECONDS := 4.0
const WALKERS := 8

var view                        # PlanetView
var world
var _road_node: MeshInstance3D
var _road_mat: StandardMaterial3D
var _docks: MultiMeshInstance3D
var _boats := {}                # clé de maillage -> MultiMeshInstance3D
var _boat_list: Array = []      # [{key, idx, center (dir), up, r, ang, speed}]
var _walk_nodes := {}           # couleur -> MultiMeshInstance3D
var _walk_list: Array = []      # [{key, idx, vi, ang, speed, ring: PackedFloat32Array (rayons du sol)}]
var _convoys: Array = []        # [{node, a, b, t}]
var _known := {}                # id d'établissement -> vrai
var _sig := ""
var _walk_dir := Vector3.ZERO

func setup(p_view, p_world) -> void:
	view = p_view
	world = p_world
	for c in get_children():
		c.queue_free()
	_boats = {}
	_walk_nodes = {}
	_convoys = []
	_road_mat = StandardMaterial3D.new()
	_road_mat.vertex_color_use_as_albedo = true
	_road_mat.vertex_color_is_srgb = true
	_road_mat.roughness = 1.0
	_road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_road_node = MeshInstance3D.new()
	_road_node.material_override = _road_mat
	_road_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_road_node)
	_docks = _mm(view.art.dock_mesh())
	_known = {}
	for s in world.settlements:
		_known[int(s.id)] = true
	_sig = ""

func _mm(mesh: Mesh) -> MultiMeshInstance3D:
	var n := MultiMeshInstance3D.new()
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.mesh = mesh
	n.multimesh = m
	n.material_override = view._prop_mat
	add_child(n)
	return n

## Après chaque reconstruction de la vue : routes, ports, convois des établissements nouveaux.
func rebuild() -> void:
	if world == null:
		return
	var alive: Array = world.alive_settlements()
	# Convois : un nouvel établissement fondé par des colons part de son village d'origine.
	for s in alive:
		if not _known.has(int(s.id)):
			_known[int(s.id)] = true
			if s.has("from") and int(s.from) >= 0 and int(s.from) < world.settlements.size():
				_spawn_convoy(world.settlements[int(s.from)], s)
	var sig := "%d|%d|%d" % [alive.size(), view.lod, world.planet.version]
	for s in alive:
		sig += ",%d:%d:%d" % [int(s.id), int(s.people), int(world.peoples[int(s.people)].era)]
	if sig == _sig:
		return
	_sig = sig
	_build_roads(alive)
	_build_ports(alive)
	_build_walkers()

# ------------------------------------------------------------------ Routes

func _build_roads(alive: Array) -> void:
	if view.lod == 0:
		_road_node.mesh = null
		return
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var done := {}
	var pl = world.planet
	for s in alive:
		var a := int(s.cell)
		# Relie chaque village à ses deux plus proches voisins du même peuple.
		var near := []
		for o in world.people_settlements(int(s.people)):
			if int(o.id) == int(s.id):
				continue
			var d: float = pl.pos[a].distance_to(pl.pos[int(o.cell)])
			if d < ROAD_MAX:
				near.append([d, o])
		near.sort_custom(func(x, y): return x[0] < y[0])
		var era := int(world.peoples[int(s.people)].era)
		var col := Color(0.62, 0.52, 0.39) if era < 2 else Color(0.6, 0.57, 0.52)
		for e in near.slice(0, 2):
			var o: Dictionary = e[1]
			var key := "%d_%d" % [mini(int(s.id), int(o.id)), maxi(int(s.id), int(o.id))]
			if done.has(key):
				continue
			done[key] = true
			_road_segment(pl.pos[a], pl.pos[int(o.cell)], a, col, verts, cols, norms)
	if verts.is_empty():
		_road_node.mesh = null
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_NORMAL] = norms
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_road_node.mesh = m

## Ruban posé sur le relief ; s'arrête à l'eau (pas de route sur la mer).
func _road_segment(pa: Vector3, pb: Vector3, hint: int, col: Color, verts: PackedVector3Array, cols: PackedColorArray, norms: PackedVector3Array) -> void:
	var steps := maxi(6, int(pa.distance_to(pb) / 0.008))
	var pts := []
	var h := hint
	for i in steps + 1:
		var d: Vector3 = pa.slerp(pb, float(i) / steps).normalized()
		h = world.planet.nearest_cell(d) if i % 3 == 0 else h
		if not world.planet.is_land(h):
			return
		pts.append(d * (view.surface_radius(d, h) + 0.0012))
	for i in steps:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var up := p0.normalized()
		var side := (p1 - p0).cross(up).normalized() * ROAD_W
		var a0 := p0 - side
		var a1 := p0 + side
		var b0 := p1 - side
		var b1 := p1 + side
		for v in [a0, b0, a1, a1, b0, b1]:
			verts.append(v)
			cols.append(col)
			norms.append(up)

# ------------------------------------------------------------------ Ports et bateaux

func _build_ports(alive: Array) -> void:
	var pl = world.planet
	var docks := []
	var boat_lists := {}
	_boat_list = []
	if view.lod >= 1:
		for s in alive:
			var p: Dictionary = world.peoples[int(s.people)]
			if not p.techs.has("navigation") or not pl.is_coastal(int(s.cell)):
				continue
			var water := -1
			for n in pl.neighbors[int(s.cell)]:
				if not pl.is_land(int(n)):
					water = int(n)
					break
			if water < 0:
				continue
			var land: Vector3 = pl.pos[int(s.cell)]
			var sea: Vector3 = pl.pos[water]
			var shore := land.slerp(sea, 0.55).normalized()
			var up := shore
			var fwd := (sea - land)
			fwd = (fwd - up * fwd.dot(up)).normalized()
			var x := up.cross(fwd).normalized()
			docks.append(Transform3D(Basis(x, up, fwd) * Basis().scaled(Vector3.ONE * 0.022), shore * 1.0015))
			var era := int(p.era)
			var key := "%s_%d" % [Color(p.color[0], p.color[1], p.color[2]).to_html(false), mini(era, 4)]
			var nb := 1 if float(s.pop) < 150 else 2
			for i in nb:
				if not boat_lists.has(key):
					boat_lists[key] = {"mesh": view.art.boat_mesh(Color(p.color[0], p.color[1], p.color[2]), era), "n": 0}
				_boat_list.append({"key": key, "idx": int(boat_lists[key].n), "center": sea.normalized(), "r": 0.02 + i * 0.012,
					"ang": float(int(s.id) * 1.7 + i * 2.1), "speed": 0.25 + 0.1 * i})
				boat_lists[key].n = int(boat_lists[key].n) + 1
	_docks.multimesh.instance_count = docks.size()
	for i in docks.size():
		_docks.multimesh.set_instance_transform(i, docks[i])
	for k in _boats:
		_boats[k].multimesh.instance_count = 0
	for k in boat_lists:
		if not _boats.has(k):
			_boats[k] = _mm(boat_lists[k].mesh)
		_boats[k].multimesh.instance_count = int(boat_lists[k].n)

# ------------------------------------------------------------------ Convois de colons

func _spawn_convoy(from: Dictionary, to: Dictionary) -> void:
	if view.lod == 0:
		return
	var p: Dictionary = world.peoples[int(to.people)]
	var node := MeshInstance3D.new()
	node.mesh = view.art.cart_mesh(Color(p.color[0], p.color[1], p.color[2]))
	node.material_override = view._prop_mat
	add_child(node)
	_convoys.append({"node": node, "a": world.planet.pos[int(from.cell)], "b": world.planet.pos[int(to.cell)], "t": 0.0, "hint": int(from.cell)})

func convoy_count() -> int:
	return _convoys.size()

# ------------------------------------------------------------------ Habitants

func _build_walkers() -> void:
	_walk_dir = view._cam_dir
	for k in _walk_nodes:
		_walk_nodes[k].multimesh.instance_count = 0
	_walk_list = []
	if view.lod < 2:
		return
	var counts := {}
	var by_id := {}
	for s in world.alive_settlements():
		by_id[int(s.id)] = s
	for vi in view._villages:
		if (vi.center as Vector3).dot(view._cam_dir) < 0.97 or not by_id.has(int(vi.id)):
			continue
		var s: Dictionary = by_id[int(vi.id)]
		var p: Dictionary = world.peoples[int(s.people)]
		var key := Color(p.color[0], p.color[1], p.color[2]).to_html(false)
		if not _walk_nodes.has(key):
			_walk_nodes[key] = _mm(view.art.figure_mesh(Color(p.color[0], p.color[1], p.color[2]), "none"))
		# Hauteur du sol le long de l'anneau des chemins, calculée une fois.
		var ring := PackedFloat32Array()
		for j in 24:
			var a := TAU * j / 24.0
			var d: Vector3 = ((vi.center as Vector3) + view._tangent(vi, a) * float(vi.R) * 0.42).normalized()
			ring.append(view.surface_radius(d, int(vi.cell)))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(vi.id) * 7919
		var n := clampi(int(sqrt(float(s.pop)) / 2.0), 2, WALKERS)
		for i in n:
			_walk_list.append({"key": key, "idx": int(counts.get(key, 0)), "vi": vi, "ang": rng.randf() * TAU,
				"speed": rng.randf_range(0.12, 0.25) * (1.0 if i % 2 == 0 else -1.0), "ring": ring, "rr": rng.randf_range(0.36, 0.5)})
			counts[key] = int(counts.get(key, 0)) + 1
	for k in counts:
		_walk_nodes[k].multimesh.instance_count = int(counts[k])

func walker_count() -> int:
	return _walk_list.size()

func boat_count() -> int:
	return _boat_list.size()

# ------------------------------------------------------------------ Animation

func _process(delta: float) -> void:
	if world == null:
		return
	# La caméra s'est déplacée vers d'autres villages : nouveaux passants.
	if view.lod == 2 and view._cam_dir.dot(_walk_dir) < 0.9995:
		_build_walkers()
	for b in _boat_list:
		b.ang = float(b.ang) + float(b.speed) * delta
		var c: Vector3 = b.center
		var x := c.cross(Vector3.UP if absf(c.y) < 0.95 else Vector3.RIGHT).normalized()
		var z := x.cross(c).normalized()
		var a := float(b.ang)
		var d := (c + (x * cos(a) + z * sin(a)) * float(b.r)).normalized()
		var fwd := (x * -sin(a) + z * cos(a)) * signf(float(b.speed))
		fwd = (fwd - d * fwd.dot(d)).normalized()
		var side := d.cross(fwd).normalized()
		var bob := sin(a * 7.0) * 0.0002
		_boats[b.key].multimesh.set_instance_transform(int(b.idx), Transform3D(Basis(side, d, fwd) * Basis().scaled(Vector3.ONE * 0.013), d * (1.0008 + bob)))
	for w in _walk_list:
		w.ang = wrapf(float(w.ang) + float(w.speed) * delta, 0.0, TAU)
		var vi: Dictionary = w.vi
		var a2 := float(w.ang)
		var t: Vector3 = view._tangent(vi, a2)
		var d2 := ((vi.center as Vector3) + t * float(vi.R) * float(w.rr)).normalized()
		var ring: PackedFloat32Array = w.ring
		var f := a2 / TAU * 24.0
		var j0 := int(f) % 24
		var r := lerpf(ring[j0], ring[(j0 + 1) % 24], f - floor(f))
		var fwd2: Vector3 = view._tangent(vi, a2 + PI / 2.0) * signf(float(w.speed))
		fwd2 = (fwd2 - d2 * fwd2.dot(d2)).normalized()
		var step := absf(sin(a2 * 60.0)) * 0.0004
		_walk_nodes[w.key].multimesh.set_instance_transform(int(w.idx), Transform3D(Basis(d2.cross(fwd2).normalized(), d2, fwd2) * Basis().scaled(Vector3.ONE * 0.0065), d2 * (r + step)))
	var i := 0
	while i < _convoys.size():
		var c2: Dictionary = _convoys[i]
		c2.t = float(c2.t) + delta / CONVOY_SECONDS
		if float(c2.t) >= 1.0:
			c2.node.queue_free()
			_convoys.remove_at(i)
			continue
		var pa: Vector3 = c2.a
		var pb: Vector3 = c2.b
		var dd := pa.slerp(pb, float(c2.t)).normalized()
		var ahead := pa.slerp(pb, minf(float(c2.t) + 0.02, 1.0)).normalized()
		var fw := (ahead - dd)
		fw = (fw - dd * fw.dot(dd)).normalized() if fw.length() > 0.00001 else dd.cross(Vector3.UP).normalized()
		var rr := maxf(view.surface_radius(dd, int(c2.hint)), 1.0005)
		c2.node.transform = Transform3D(Basis(dd.cross(fw).normalized(), dd, fw) * Basis().scaled(Vector3.ONE * 0.012), dd * rr)
		i += 1
