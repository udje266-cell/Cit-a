extends Node
## Défilement au doigt pour un ScrollContainer, quel que soit l'élément touché (case à cocher, bouton, texte).
## - Un appui dans la zone est retenu ; s'il bouge de plus de DEADZONE pixels, c'est un glisser : la liste défile
##   (avec inertie) et aucun bouton n'est activé.
## - S'il est relâché sans bouger, l'appui et le relâchement sont rejoués : le bouton touché réagit normalement.
## Fonctionne avec la souris et avec le toucher (Android transforme le toucher en événements de souris pour l'interface).

const DEADZONE := 12.0
const FRICTION := 6.0

static var _replaying := 0

var scroll: ScrollContainer
var _down := false
var _dragging := false
var _start := Vector2.ZERO
var _press: InputEventMouseButton
var _velocity := Vector2.ZERO

static func attach(sc: ScrollContainer) -> void:
	var n = load("res://game/touch_scroll.gd").new()
	n.scroll = sc
	n.name = "TouchScroll"
	sc.add_child(n)

func _input(event: InputEvent) -> void:
	if _replaying > 0 or scroll == null or not scroll.is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _owns_point(event.position):
				_down = true
				_dragging = false
				_start = event.position
				_press = event.duplicate()
				_velocity = Vector2.ZERO
				get_viewport().set_input_as_handled()
		elif _down:
			_down = false
			get_viewport().set_input_as_handled()
			if not _dragging:
				_replay(_press, event)
			_dragging = false
	elif event is InputEventMouseMotion and _down:
		if not _dragging and event.position.distance_to(_start) > DEADZONE:
			_dragging = true
		if _dragging:
			_scroll_by(-event.relative)
			_velocity = -event.relative * 60.0
		get_viewport().set_input_as_handled()

## Le point touché appartient-il à cette liste (et pas à un panneau posé par-dessus) ?
func _owns_point(p: Vector2) -> bool:
	if not scroll.get_global_rect().has_point(p):
		return false
	var top := _pick(get_tree().root, p)
	return top != null and (top == scroll or scroll.is_ancestor_of(top))

## Contrôle visible le plus haut sous le point (ordre de dessin : derniers enfants au-dessus).
func _pick(node: Node, p: Vector2) -> Control:
	for i in range(node.get_child_count() - 1, -1, -1):
		var c := node.get_child(i)
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		var hit := _pick(c, p)
		if hit != null:
			return hit
	if node is Control:
		var ctl := node as Control
		if ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE and ctl.get_global_rect().has_point(p) and ctl.is_visible_in_tree():
			return ctl
	return null

func _scroll_by(d: Vector2) -> void:
	if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.scroll_vertical += int(round(d.y))
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.scroll_horizontal += int(round(d.x))

func _replay(press0: InputEventMouseButton, release0: InputEventMouseButton) -> void:
	# Les événements reçus ici sont en coordonnées d'interface ; Input les attend en coordonnées de fenêtre
	# (différentes dès que l'interface est mise à l'échelle, c'est-à-dire sur presque tous les téléphones).
	var xf := get_tree().root.get_final_transform()
	var press: InputEventMouseButton = press0.duplicate()
	var release: InputEventMouseButton = release0.duplicate()
	for e in [press, release]:
		e.position = xf * e.position
		e.global_position = xf * e.global_position
	_replaying += 1
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	_replaying -= 1
	# Le relâchement arrive à l'image suivante, comme un vrai toucher.
	await get_tree().process_frame
	_replaying += 1
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	_replaying -= 1

func _process(delta: float) -> void:
	if _down or _velocity.length() < 5.0:
		return
	_scroll_by(_velocity * delta)
	_velocity = _velocity.lerp(Vector2.ZERO, clampf(FRICTION * delta, 0.0, 1.0))
