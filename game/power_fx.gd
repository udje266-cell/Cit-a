extends Node3D
## Effets visuels des pouvoirs : un jeu de particules par type (« visual » dans powers.json),
## posé à la surface et orienté selon la normale locale. Chaque effet se détruit seul.
## Particules CPU : compatibles avec le rendu mobile et le rendu de compatibilité.

const KINDS := {
	# couleur, nombre, durée de vie, vitesse (le long de la normale), gravité, taille, hauteur de départ, forme
	"rain": {"c": Color(0.55, 0.75, 1.0, 0.8), "n": 260, "life": 0.7, "v": -0.25, "g": -0.2, "s": 0.006, "h": 0.12, "stretch": 5.0},
	"sparkles": {"c": Color(1.0, 0.95, 0.6, 0.9), "n": 120, "life": 1.4, "v": 0.06, "g": 0.0, "s": 0.008, "h": 0.01},
	"blessing": {"c": Color(1.0, 0.82, 0.35, 0.9), "n": 160, "life": 1.8, "v": 0.08, "g": 0.02, "s": 0.01, "h": 0.0, "ring": true},
	"aurora": {"c": Color(0.45, 1.0, 0.7, 0.45), "c2": Color(0.75, 0.45, 1.0, 0.45), "n": 90, "life": 2.6, "v": 0.01, "g": 0.0, "s": 0.04, "h": 0.12, "drift": 0.05},
	"sun": {"c": Color(1.0, 0.85, 0.45, 0.55), "n": 70, "life": 2.0, "v": 0.02, "g": 0.0, "s": 0.03, "h": 0.03, "light": Color(1.0, 0.8, 0.45)},
	"spring": {"c": Color(0.5, 0.8, 1.0, 0.9), "n": 140, "life": 1.0, "v": 0.22, "g": -0.45, "s": 0.006, "h": 0.0, "narrow": true},
	"flock": {"c": Color(0.45, 0.33, 0.22, 1.0), "n": 80, "life": 2.4, "v": 0.0, "g": 0.0, "s": 0.006, "h": 0.004, "drift": 0.06},
	"quake": {"c": Color(0.62, 0.52, 0.4, 0.7), "n": 150, "life": 1.4, "v": 0.05, "g": -0.04, "s": 0.02, "h": 0.0, "shake": 0.9},
	"eruption": {"c": Color(1.0, 0.45, 0.12, 1.0), "c2": Color(0.3, 0.28, 0.27, 0.7), "n": 220, "life": 1.6, "v": 0.3, "g": -0.35, "s": 0.012, "h": 0.0, "narrow": true, "shake": 1.2, "light": Color(1.0, 0.4, 0.1)},
	"frost": {"c": Color(0.92, 0.96, 1.0, 0.9), "n": 240, "life": 1.6, "v": -0.06, "g": -0.02, "s": 0.006, "h": 0.12, "drift": 0.02},
	"dna": {"c": Color(0.7, 0.5, 1.0, 0.9), "c2": Color(0.4, 0.9, 1.0, 0.9), "n": 120, "life": 1.8, "v": 0.07, "g": 0.0, "s": 0.008, "h": 0.0, "spiral": true, "narrow": true},
	"bloom": {"c": Color(0.55, 0.95, 0.45, 0.9), "c2": Color(1.0, 0.7, 0.85, 0.9), "n": 140, "life": 1.6, "v": 0.05, "g": 0.0, "s": 0.009, "h": 0.0},
	"heal": {"c": Color(0.75, 1.0, 0.8, 0.85), "n": 120, "life": 1.6, "v": 0.07, "g": 0.0, "s": 0.008, "h": 0.0},
	"rebirth": {"c": Color(0.45, 0.9, 0.4, 0.9), "c2": Color(1.0, 0.9, 0.5, 0.8), "n": 180, "life": 2.0, "v": 0.09, "g": 0.0, "s": 0.01, "h": 0.0, "ring": true},
	"halo": {"c": Color(1.0, 0.9, 0.55, 0.7), "n": 120, "life": 1.8, "v": 0.02, "g": 0.0, "s": 0.012, "h": 0.06, "ring": true},
	"light_beam": {"c": Color(1.0, 0.97, 0.85, 0.75), "n": 160, "life": 1.2, "v": 0.18, "g": 0.0, "s": 0.01, "h": 0.0, "narrow": true, "light": Color(1.0, 0.95, 0.8)},
	"whisper": {"c": Color(0.9, 0.92, 1.0, 0.45), "n": 60, "life": 2.4, "v": 0.01, "g": 0.0, "s": 0.02, "h": 0.02, "drift": 0.03},
	"heat": {"c": Color(1.0, 0.6, 0.25, 0.4), "n": 110, "life": 1.6, "v": 0.05, "g": 0.0, "s": 0.03, "h": 0.0, "drift": 0.03},
	"dust_up": {"c": Color(0.66, 0.55, 0.42, 0.75), "n": 130, "life": 1.3, "v": 0.08, "g": -0.06, "s": 0.016, "h": 0.0, "shake": 0.4},
	"dust_down": {"c": Color(0.58, 0.5, 0.4, 0.75), "n": 130, "life": 1.3, "v": 0.03, "g": -0.05, "s": 0.016, "h": 0.0, "ring": true, "shake": 0.3},
	"curse": {"c": Color(0.45, 0.2, 0.55, 0.75), "n": 140, "life": 1.6, "v": 0.03, "g": 0.0, "s": 0.02, "h": 0.01},
}
const ALIASES := {"growth": "bloom", "dark": "curse", "flood": "rain", "light": "light_beam", "sign": "aurora"}
const DURATION := 2.2

var _shake_left := 0.0
var _soft: Texture2D
var _shake_amp := 0.0

static func kind_for(visual: String) -> String:
	if KINDS.has(visual):
		return visual
	return ALIASES.get(visual, "sparkles")

## center : point à la surface ; normal : verticale locale ; spread : rayon de la zone (unités monde).
func play(visual: String, center: Vector3, normal: Vector3, spread: float) -> Node3D:
	var k: Dictionary = KINDS[kind_for(visual)]
	var root := Node3D.new()
	add_child(root)
	var up := normal.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	root.transform = Transform3D(Basis(side, up, side.cross(up)), center + up * float(k.h))
	_emitter(root, k, k.c, spread, int(k.n))
	if k.has("c2"):
		_emitter(root, k, k.c2, spread, int(k.n) / 2)
	if k.has("light"):
		var l := OmniLight3D.new()
		l.light_color = k.light
		l.light_energy = 1.6
		l.omni_range = spread * 3.0 + 0.05
		root.add_child(l)
		var tw := l.create_tween()
		tw.tween_property(l, "light_energy", 0.0, DURATION)
	if k.has("shake"):
		_shake_left = 0.6
		_shake_amp = float(k.shake) * 0.004
	get_tree().create_timer(DURATION + float(k.life) + 0.2).timeout.connect(root.queue_free)
	return root

func _emitter(root: Node3D, k: Dictionary, color: Color, spread: float, n: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = float(k.life)
	p.one_shot = false
	p.explosiveness = 0.0
	p.local_coords = true
	var narrow: bool = k.get("narrow", false)
	var area := spread * (0.15 if narrow else 1.0)
	if k.get("ring", false):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = area
		p.emission_ring_inner_radius = area * 0.8
		p.emission_ring_height = 0.0
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(area, 0.004, area)
	var v := float(k.v)
	p.direction = Vector3(0, 1 if v >= 0.0 else -1, 0)
	p.spread = 25.0 if narrow else 8.0
	p.initial_velocity_min = absf(v) * 0.7
	p.initial_velocity_max = absf(v) * 1.2
	p.gravity = Vector3(0, float(k.g), 0)
	if k.has("drift"):
		p.direction = Vector3(1, 0.1 if v >= 0.0 else -0.4, 0.3).normalized()
		p.spread = 60.0
		p.initial_velocity_min = float(k.drift) * 0.5
		p.initial_velocity_max = float(k.drift)
	if k.get("spiral", false):
		# Double hélice : émission en anneau étroit, poussée tangentielle (rotation autour de la verticale).
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = spread * 0.25
		p.emission_ring_inner_radius = spread * 0.22
		p.emission_ring_height = 0.0
		p.spread = 0.0
		p.tangential_accel_min = 0.25
		p.tangential_accel_max = 0.3
		p.radial_accel_min = -0.05
		p.radial_accel_max = -0.04
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var quad := QuadMesh.new()
	var s := float(k.s)
	quad.size = Vector2(s, s * float(k.get("stretch", 1.0)))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if color.a < 0.95 else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if k.has("stretch") else BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = color
	m.albedo_texture = _soft_texture()
	m.no_depth_test = false
	quad.material = m
	p.mesh = quad
	root.add_child(p)
	p.emitting = true
	# Arrêt de l'émission après la durée de l'effet : les dernières particules s'éteignent naturellement.
	get_tree().create_timer(DURATION).timeout.connect(func():
		if is_instance_valid(p):
			p.emitting = false)

## Point lumineux doux (dégradé radial) : évite les carrés durs.
func _soft_texture() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.75))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_soft = t
	return _soft

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _shake_left > 0.0:
		_shake_left -= delta
		var a := _shake_amp * clampf(_shake_left / 0.6, 0.0, 1.0)
		cam.h_offset = randf_range(-a, a)
		cam.v_offset = randf_range(-a, a)
		if _shake_left <= 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0

func active_count() -> int:
	return get_child_count()
