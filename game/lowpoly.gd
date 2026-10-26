extends RefCounted
## Constructeur de maillages low poly à facettes plates avec couleurs de sommets.
## Les primitives sont ajoutées dans un repère local (Transform3D) puis converties en ArrayMesh.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()

func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	# Normale calculée dans le sens trigonométrique, sommets émis en sens horaire (faces avant de Godot).
	var n := (b - a).cross(c - a).normalized()
	verts.append(a); verts.append(c); verts.append(b)
	normals.append(n); normals.append(n); normals.append(n)
	colors.append(col); colors.append(col); colors.append(col)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, d, col)

## Prisme (cylindre, cône ou tronc de cône) à `seg` côtés. bottom_r=top_r → cylindre ; top_r=0 → cône.
## Pas de face inférieure : les objets sont toujours posés au sol (économie de triangles).
func prism(t: Transform3D, bottom_r: float, top_r: float, h: float, seg: int, col: Color, cap: bool = true, top_col: Color = Color(0, 0, 0, 0)) -> void:
	var tc := col if top_col.a == 0.0 else top_col
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var b0 := t * Vector3(cos(a0) * bottom_r, 0, sin(a0) * bottom_r)
		var b1 := t * Vector3(cos(a1) * bottom_r, 0, sin(a1) * bottom_r)
		var t0 := t * Vector3(cos(a0) * top_r, h, sin(a0) * top_r)
		var t1 := t * Vector3(cos(a1) * top_r, h, sin(a1) * top_r)
		if top_r <= 0.0001:
			tri(b0, t0, b1, col)
		else:
			quad(b0, t0, t1, b1, col)
			if cap:
				tri(t * Vector3(0, h, 0), t1, t0, tc)


func box(t: Transform3D, size: Vector3, col: Color, top_col: Color = Color(0, 0, 0, 0)) -> void:
	var tc := col if top_col.a == 0.0 else top_col
	var x := size.x * 0.5
	var z := size.z * 0.5
	var y := size.y
	var p := [Vector3(-x, 0, -z), Vector3(x, 0, -z), Vector3(x, 0, z), Vector3(-x, 0, z),
		Vector3(-x, y, -z), Vector3(x, y, -z), Vector3(x, y, z), Vector3(-x, y, z)]
	for i in 8:
		p[i] = t * p[i]
	quad(p[0], p[4], p[5], p[1], col)
	quad(p[1], p[5], p[6], p[2], col.darkened(0.08))
	quad(p[2], p[6], p[7], p[3], col)
	quad(p[3], p[7], p[4], p[0], col.darkened(0.08))
	quad(p[4], p[7], p[6], p[5], tc)

## Toit à deux pans posé sur une base (largeur x, profondeur z).
func gable(t: Transform3D, size: Vector3, col: Color) -> void:
	var x := size.x * 0.5
	var z := size.z * 0.5
	var y := size.y
	var a := t * Vector3(-x, 0, -z)
	var b := t * Vector3(x, 0, -z)
	var c := t * Vector3(x, 0, z)
	var d := t * Vector3(-x, 0, z)
	var r0 := t * Vector3(-x, y, 0)
	var r1 := t * Vector3(x, y, 0)
	quad(a, r0, r1, b, col)
	quad(c, r1, r0, d, col.darkened(0.12))
	tri(a, d, r0, col.darkened(0.2))
	tri(b, r1, c, col.darkened(0.2))

## Sphère low poly (icosaèdre éventuellement subdivisé une fois), déformable par l'échelle de t.
func blob(t: Transform3D, col: Color, detail: int = 0, jitter: float = 0.0, rng: RandomNumberGenerator = null) -> void:
	var g := (1.0 + sqrt(5.0)) / 2.0
	var v: Array = [Vector3(-1, g, 0), Vector3(1, g, 0), Vector3(-1, -g, 0), Vector3(1, -g, 0), Vector3(0, -1, g), Vector3(0, 1, g),
		Vector3(0, -1, -g), Vector3(0, 1, -g), Vector3(g, 0, -1), Vector3(g, 0, 1), Vector3(-g, 0, -1), Vector3(-g, 0, 1)]
	var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in v.size():
		v[i] = v[i].normalized()
	if detail > 0:
		var cache := {}
		var nf := []
		for face in f:
			var m := []
			for k in 3:
				var a: int = face[k]
				var b: int = face[(k + 1) % 3]
				var key := mini(a, b) * 100 + maxi(a, b)
				if not cache.has(key):
					v.append(((v[a] + v[b]) * 0.5).normalized())
					cache[key] = v.size() - 1
				m.append(cache[key])
			nf.append([face[0], m[0], m[2]]); nf.append([face[1], m[1], m[0]]); nf.append([face[2], m[2], m[1]]); nf.append([m[0], m[1], m[2]])
		f = nf
	if jitter > 0.0 and rng != null:
		for i in v.size():
			v[i] = v[i] * (1.0 + rng.randf_range(-jitter, jitter))
	for face in f:
		var a2: Vector3 = t * v[face[0]]
		var b2: Vector3 = t * v[face[1]]
		var c2: Vector3 = t * v[face[2]]
		var shade := 1.0 - 0.06 * float((face[0] + face[1]) % 3)
		tri(a2, b2, c2, Color(col.r * shade, col.g * shade, col.b * shade, col.a))

func to_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	if verts.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func T(pos: Vector3, scale: Vector3 = Vector3.ONE, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(scale), pos)
