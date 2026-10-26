extends Node3D
## Orchestration : menus, création, boucle de temps, sauvegarde automatique, absence, tutoriel.

const Catalog = preload("res://sim/catalog.gd")
const World = preload("res://sim/world.gd")
const SaveSystem = preload("res://sim/save_system.gd")
const Powers = preload("res://sim/powers.gd")
const CameraRig = preload("res://game/camera_rig.gd")
const PlanetView = preload("res://game/planet_view.gd")
const UI = preload("res://game/ui.gd")
const FounderScreen = preload("res://game/founder_screen.gd")

const TUTORIAL := [
	"Faites glisser un doigt pour tourner la planète, pincez pour zoomer.",
	"Touchez le village de votre peuple (marqueur le plus clair) pour l'observer.",
	"Ouvrez « ◎ Manifestations religieuses » en bas et utilisez « Signe céleste » sur votre village.",
	"Ouvrez « Affinités » en haut : activez une règle, ou réservez des naissances depuis la fiche d'un village.",
	"Ouvrez le Journal : chaque événement indique sa cause. Le monde vit sans vous — à vous d'intervenir.",
]

var cat
var world
var world_id := ""
var state := "menu"          # menu | founders | play | catchup
var speed := 1
var rig
var view
var ui
var founder_screen
var _acc := 0.0
var _autosave_acc := 0.0
var _hud_acc := 0.0
var _mesh_acc := 0.0
var _power := ""
var _power_opts := {}
var _preview_cell := -1
var _brush := false
var _last_paint_cell := -1
var _last_paint_ms := 0
var _catchup_left := 0
var _catchup_before := {}
var _tuto_timer := 0.0

func _ready() -> void:
	cat = Catalog.shared()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.04, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.75)
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.8, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	rig = CameraRig.new()
	add_child(rig)
	rig.tapped.connect(_on_tap)
	rig.painted.connect(_on_paint)
	view = PlanetView.new()
	add_child(view)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = UI.new()
	layer.add_child(ui)
	ui.build(self)
	rig.ui_blocker = ui.blocks
	_show_menu()

# ------------------------------------------------------------------ Menus et création

func _show_menu() -> void:
	state = "menu"
	ui.set_play_visible(false)
	ui.show_main_menu(SaveSystem.list_worlds(), _list_exports())

func _list_exports() -> Array:
	var out := []
	var dir := DirAccess.open(SaveSystem.EXPORTS)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(SaveSystem.EXT):
			out.append(SaveSystem.EXPORTS + "/" + f)
	return out

func new_world(seed_text: String) -> void:
	var s := int(seed_text) if seed_text.strip_edges().is_valid_int() else randi() % 1000000
	world = World.new(cat)
	world.create_planet(s)
	world.world_name = "Monde %d" % s
	world_id = SaveSystem.new_world_id()
	_start_founders()

func _start_founders() -> void:
	ui.close_modal()
	view.setup(world)
	state = "founders"
	founder_screen = FounderScreen.new()
	ui.add_child(founder_screen)
	founder_screen.build(cat, 15.0)
	founder_screen.confirmed.connect(_on_founders)

func _on_founders(species_id: String, people_name: String, deity_name: String, founders: Array) -> void:
	founder_screen.queue_free()
	founder_screen = null
	var pid: int = world.create_player_people(species_id, people_name, founders, {"name": deity_name})
	var d: Dictionary = world.deities[world.player_deity]
	for f in founders:
		if f.affinity != "none":
			d.energy = float(d.energy) - float(cat.config.affinity.cost[f.affinity])
			d.affinities_granted = int(d.affinities_granted) + 1
			world.add_log("%s reçoit le don : %s" % [f.name, f.affinity], "Attribution divine lors de la création des fondateurs", "deity", int(world.peoples[pid].origin_cell))
	world.create_rivals(int(cat.cfg("rivals", "count", 2)))
	world.world_name = people_name
	SaveSystem.save_world(world, world_id)
	_enter_play()

func continue_world(id: String) -> void:
	var w = SaveSystem.load_world(id)
	if w == null:
		ui.show_message("Erreur", ["Sauvegarde illisible."])
		return
	world = w
	world_id = id
	_enter_play()
	_start_offline_catchup()

func delete_world(id: String) -> void:
	SaveSystem.delete_world(id)
	_show_menu()

func import_world(path: String) -> void:
	var r := SaveSystem.import_file(path)
	if r.has("error"):
		ui.show_message("Import impossible", [r.error])
		return
	world = r.world
	world_id = SaveSystem.new_world_id()
	if r.kind == "seed":
		_start_founders()
	else:
		SaveSystem.save_world(world, world_id)
		_enter_play()

func back_to_menu() -> void:
	save_now()
	ui.close_modal()
	world = null
	_show_menu()

func _enter_play() -> void:
	ui.close_modal()
	view.setup(world)
	ui.set_world(world)
	ui.set_play_visible(true)
	state = "play"
	set_speed(1)
	var ps: Array = world.people_settlements(0)
	if ps.size() > 0:
		rig.focus_on(world.planet.pos[int(ps[0].cell)], 2.2)
	_update_tutorial()

# ------------------------------------------------------------------ Absence

func _start_offline_catchup() -> void:
	var now := int(Time.get_unix_time_from_system())
	var info := SaveSystem.offline_years(world, now)
	if info.clock_issue:
		world.add_log("Horloge incohérente détectée", "L'heure de l'appareil est antérieure à la dernière sauvegarde : aucune progression d'absence", "deity", -1)
	if int(info.years) <= 0:
		return
	SaveSystem.consume_offline(world, now)   # consommé avant calcul : jamais appliqué deux fois
	_catchup_before = world.snapshot()
	_catchup_left = int(info.years)
	state = "catchup"

func _process_catchup() -> void:
	var per_frame := int(cat.cfg("offline", "years_per_frame", 10))
	for i in mini(per_frame, _catchup_left):
		world.tick()
	_catchup_left -= mini(per_frame, _catchup_left)
	ui.refresh_hud(speed, "Pendant votre absence… encore %d ans à simuler" % _catchup_left)
	if _catchup_left <= 0:
		state = "play"
		view.refresh(true)
		SaveSystem.save_world(world, world_id)
		ui.show_message("Pendant votre absence", SaveSystem.summary(world, _catchup_before, world.snapshot()))

# ------------------------------------------------------------------ Boucle

func _process(delta: float) -> void:
	if world == null:
		return
	if state == "catchup":
		_process_catchup()
		return
	if state != "play":
		return
	if speed > 0:
		_acc += delta * speed
		var spt := float(cat.cfg("time", "seconds_per_tick", 1.0))
		var guard := 0
		while _acc >= spt and guard < 4:
			world.tick()
			_acc -= spt
			guard += 1
			ui.mark_dirty()
	_autosave_acc += delta
	if _autosave_acc >= float(cat.cfg("time", "autosave_seconds", 60)):
		_autosave_acc = 0.0
		save_now()
	_hud_acc += delta
	if _hud_acc >= 0.25:
		_hud_acc = 0.0
		ui.refresh_hud(speed)
		_update_tutorial()
	_mesh_acc += delta
	view.marker_detail = lerpf(1.6, 0.4, rig.zoom_level())
	if _mesh_acc >= 1.0 or world.planet.version != view._built_version:
		_mesh_acc = 0.0
		view.refresh()

func set_speed(s: int) -> void:
	speed = s
	ui.update_speed(s)

func set_overlay(o: String) -> void:
	view.set_overlay(o)

# ------------------------------------------------------------------ Sélection et pouvoirs

func _cell_at(screen_pos: Vector2) -> int:
	var p: Vector3 = rig.pick_direction(screen_pos)
	if p == Vector3.ZERO:
		return -1
	return world.planet.nearest_cell(p)

func _on_tap(screen_pos: Vector2) -> void:
	if state != "play" or ui.modal != null:
		return
	var c := _cell_at(screen_pos)
	if c < 0:
		return
	if _power != "":
		preview_at(c)
	else:
		view.highlight([c], Color(1, 1, 1, 0.35))
		ui.show_cell(c)
		var s: Dictionary = world.settlement_at(c)
		if not s.is_empty() and int(s.people) == 0:
			_tutorial_done(1)

func clear_selection() -> void:
	view.highlight([], Color.WHITE)

func select_power(pid: String, opts: Dictionary = {}) -> void:
	_power = pid
	_power_opts = opts
	_preview_cell = -1
	ui.show_targeting(pid)

func preview_at(cell: int) -> void:
	if _power == "":
		return
	_preview_cell = cell
	var pv := Powers.preview(world, world.player_deity, _power, cell, _power_opts)
	view.highlight(pv.cells, Color(1.0, 0.85, 0.3, 0.45) if pv.ok else Color(1.0, 0.3, 0.3, 0.45))
	ui.show_preview(pv, cat.powers[_power].get("delayed", []))

func confirm_power() -> void:
	if _power == "" or _preview_cell < 0:
		return
	var r := Powers.apply(world, world.player_deity, _power, _preview_cell, _power_opts)
	if r.ok:
		_tutorial_done(2)
		view.refresh(true)
		ui.mark_dirty()
	cancel_power()
	if not r.ok:
		ui.show_message("Impossible", [r.msg])

func cancel_power() -> void:
	_power = ""
	_power_opts = {}
	_preview_cell = -1
	view.highlight([], Color.WHITE)
	ui.hide_targeting()

func set_brush(on: bool) -> void:
	_brush = on
	rig.paint_mode = on

## Pinceau tactile : applique le pouvoir de terrain sélectionné en glissant (coût à chaque application).
func _on_paint(screen_pos: Vector2) -> void:
	if not _brush or _power == "" or cat.powers[_power].family != "terrain":
		return
	var c := _cell_at(screen_pos)
	if c < 0 or c == _last_paint_cell or Time.get_ticks_msec() - _last_paint_ms < 150:
		return
	_last_paint_cell = c
	_last_paint_ms = Time.get_ticks_msec()
	var r := Powers.apply(world, world.player_deity, _power, c)
	if r.ok:
		view.refresh(true)
		ui.mark_dirty()
	else:
		ui.show_preview(Powers.preview(world, world.player_deity, _power, c), [])

func on_rules_changed() -> void:
	_tutorial_done(3)
	ui.mark_dirty()

func on_log_opened() -> void:
	_tutorial_done(4)

# ------------------------------------------------------------------ Tutoriel

func _tutorial_done(step: int) -> void:
	if world == null:
		return
	if not step in world.tutorial.done:
		world.tutorial.done.append(step)
	_update_tutorial()

func _update_tutorial() -> void:
	if world == null:
		return
	if rig.user_moved and not 0 in world.tutorial.done and state == "play":
		_tuto_timer += 0.25
		if _tuto_timer > 1.5:
			world.tutorial.done.append(0)
	for i in TUTORIAL.size():
		if not i in world.tutorial.done:
			ui.set_tutorial("Tutoriel %d/%d — %s" % [i + 1, TUTORIAL.size(), TUTORIAL[i]])
			return
	ui.set_tutorial("")

# ------------------------------------------------------------------ Sauvegarde

func save_now() -> void:
	if world != null and world_id != "" and state in ["play", "catchup"]:
		SaveSystem.save_world(world, world_id)

func export_world(kind: String) -> String:
	var path := SaveSystem.export_world(world, kind)
	if path == "":
		return "Échec de l'export."
	return "Fichier créé : %s\n(chemin réel : %s)" % [path, ProjectSettings.globalize_path(path)]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_now()

func perf_text() -> String:
	return "[b]Mesures[/b]\nIPS %d · dernier tick %.2f ms · maillage %d sommets (reconstruit en %.0f ms)\nMémoire statique %.1f Mo · objets %d · appels de dessin %d\nÉtablissements %d · cellules %d" % [
		Engine.get_frames_per_second(), float(world.tick_ms_last), view.vertex_count(), view.last_build_ms,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), world.alive_settlements().size(), world.planet.cell_count]
