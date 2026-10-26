extends Node3D
## Caméra orbitale autour de la planète.
## Tactile : 1 doigt = rotation (ou pinceau en mode peinture), 2 doigts = zoom (pincer), toucher bref = sélection.
## Souris : clic gauche glissé = rotation, molette = zoom, clic bref = sélection.

signal tapped(screen_pos: Vector2)
signal painted(screen_pos: Vector2)
signal moved

const MIN_DIST := 1.12
const MAX_DIST := 5.0
const TAP_MAX_MOVE := 14.0
const TAP_MAX_MS := 350

var camera: Camera3D
var yaw := 0.4
var pitch := 0.35
var distance := 3.2
var paint_mode := false
var user_moved := false            # vrai dès que le joueur a tourné ou zoomé lui-même
var ui_blocker: Callable           # (Vector2) -> bool : le point est-il sur l'interface ?

var _touches := {}          # index -> position
var _touch_start := {}      # index -> {pos, time}
var _pinch_dist := 0.0
var _mouse_down := false
var _mouse_start := Vector2.ZERO
var _mouse_start_ms := 0
var _touchscreen := false

func _ready() -> void:
	camera = Camera3D.new()
	camera.near = 0.02
	camera.far = 50.0
	camera.fov = 50.0
	add_child(camera)
	_touchscreen = DisplayServer.is_touchscreen_available()
	_apply()

func zoom_level() -> float:
	return inverse_lerp(MIN_DIST, MAX_DIST, distance)

func _apply() -> void:
	pitch = clampf(pitch, -1.45, 1.45)
	distance = clampf(distance, MIN_DIST, MAX_DIST)
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	var north := Vector3(-sin(pitch) * sin(yaw), cos(pitch), -sin(pitch) * cos(yaw))
	# De près, la caméra vise la surface et s'incline vers l'horizon ; de loin, elle vise le centre.
	var nf := near_factor()
	var target := dir * clampf(nf * 3.0, 0.0, 1.02)
	var tilt := nf * 0.85
	var height := distance - target.length()
	camera.position = target + (dir * cos(tilt) - north * sin(tilt)) * height
	camera.look_at(target, north if nf > 0.01 else Vector3.UP)
	moved.emit()

## 0 de loin, 1 au plus près.
func near_factor() -> float:
	return clampf((2.1 - distance) / (2.1 - MIN_DIST), 0.0, 1.0)

func _rotate_by(delta: Vector2) -> void:
	# Rotation plus lente quand on est proche : précision au niveau des villages.
	var k := 0.0045 * (distance - 0.9)
	user_moved = true
	yaw -= delta.x * k
	pitch += delta.y * k
	_apply()

func zoom_by(factor: float) -> void:
	user_moved = true
	distance *= factor
	_apply()

func focus_on(dir: Vector3, dist: float = -1.0) -> void:
	var d := dir.normalized()
	pitch = asin(clampf(d.y, -1.0, 1.0))
	yaw = atan2(d.x, d.z)
	if dist > 0.0:
		distance = dist
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif not _touchscreen:
		if event is InputEventMouseButton:
			_on_mouse_button(event)
		elif event is InputEventMouseMotion and _mouse_down:
			if paint_mode:
				painted.emit(event.position)
			else:
				_rotate_by(event.relative)

func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if ui_blocker.is_valid() and ui_blocker.call(e.position):
			return
		_touches[e.index] = e.position
		_touch_start[e.index] = {"pos": e.position, "time": Time.get_ticks_msec()}
		if _touches.size() == 2:
			_pinch_dist = _pinch_distance()
	else:
		var st = _touch_start.get(e.index)
		if st != null and _touches.size() == 1 and e.position.distance_to(st.pos) < TAP_MAX_MOVE and Time.get_ticks_msec() - int(st.time) < TAP_MAX_MS:
			tapped.emit(e.position)
		_touches.erase(e.index)
		_touch_start.erase(e.index)
	get_viewport().set_input_as_handled()

func _on_drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	_touches[e.index] = e.position
	if _touches.size() >= 2:
		var d := _pinch_distance()
		if _pinch_dist > 0.0 and d > 0.0:
			zoom_by(_pinch_dist / d)
		_pinch_dist = d
	elif paint_mode:
		painted.emit(e.position)
	else:
		_rotate_by(e.relative)
	get_viewport().set_input_as_handled()

func _pinch_distance() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1])

func _on_mouse_button(e: InputEventMouseButton) -> void:
	match e.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			zoom_by(0.9)
		MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.1)
		MOUSE_BUTTON_LEFT:
			if e.pressed:
				if ui_blocker.is_valid() and ui_blocker.call(e.position):
					return
				_mouse_down = true
				_mouse_start = e.position
				_mouse_start_ms = Time.get_ticks_msec()
				if paint_mode:
					painted.emit(e.position)
			else:
				_mouse_down = false
				if e.position.distance_to(_mouse_start) < TAP_MAX_MOVE and Time.get_ticks_msec() - _mouse_start_ms < TAP_MAX_MS:
					tapped.emit(e.position)

## Rayon écran → cellule de la planète (-1 si on vise le vide).
func pick_direction(screen_pos: Vector2, radius: float = 1.02) -> Vector3:
	var o := camera.project_ray_origin(screen_pos)
	var d := camera.project_ray_normal(screen_pos)
	var b := o.dot(d)
	var c := o.dot(o) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return Vector3.ZERO
	var t := -b - sqrt(disc)
	return o + d * t
