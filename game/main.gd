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
const Audio = preload("res://game/audio.gd")
const I18n = preload("res://game/i18n.gd")

const TUTORIAL := [
	"Tournez la planète : glissez un doigt (ou le bouton gauche de la souris). Zoomez : pincez (ou molette).",
	"Touchez la bannière d'un village de votre peuple pour ouvrir sa fiche (nom, population, besoins, activité).",
	"Ouvrez « Pouvoirs » à droite, choisissez la catégorie « Signes », puis « Signe céleste ». Touchez votre village et validez.",
	"Ouvrez « Affinités » : activez une règle d'attribution, ou réservez des naissances depuis la fiche d'un village.",
	"Ouvrez le « Journal » : chaque événement indique sa cause. Touchez ▶ pour laisser le monde vivre.",
]

var cat
var world
var world_id := ""
var state := "menu"          # menu | founders | play | catchup
var speed := 1
var rig
var sun: DirectionalLight3D
var view
var audio
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
	get_tree().set_quit_on_go_back(false)
	I18n.apply(I18n.saved_locale(), cat)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.025, 0.03, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.68, 0.75, 0.88)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 5.0
	e.tonemap_exposure = 1.0
	env.environment = e
	add_child(env)
	rig = CameraRig.new()
	add_child(rig)
	# Soleil attaché à la caméra : la face observée est toujours éclairée, de biais (lecture des volumes).
	sun = DirectionalLight3D.new()
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 2.5
	sun.shadow_bias = 0.015
	sun.shadow_normal_bias = 1.5
	sun.shadow_blur = 1.6
	sun.rotation = Vector3(-0.62, -0.95, 0.0)
	rig.camera.add_child(sun)
	rig.tapped.connect(_on_tap)
	rig.painted.connect(_on_paint)
	view = PlanetView.new()
	add_child(view)
	audio = Audio.new()
	add_child(audio)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = UI.new()
	layer.add_child(ui)
	ui.build(self)
	rig.ui_blocker = ui.blocks
	view.ui_blocker = ui.blocks
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

func new_world(seed_text: String, subdivisions: int = -1) -> void:
	var s := int(seed_text) if seed_text.strip_edges().is_valid_int() else randi() % 1000000
	world = World.new(cat)
	world.create_planet(s, subdivisions)
	world.set_meta("rivals", 2 if world.planet.cell_count <= 2562 else 4)
	world.world_name = tr("Monde %d") % s
	world_id = SaveSystem.new_world_id()
	_start_founders()

func _start_founders() -> void:
	ui.close_modal()
	view.setup(world)
	state = "founders"
	founder_screen = FounderScreen.new()
	ui.layout.add_child(founder_screen)   # dans les marges de sécurité (encoches, barres système)
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
	world.create_rivals(int(world.get_meta("rivals", cat.cfg("rivals", "count", 2))))
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

## Sélecteur de fichier de l'appareil : natif quand le système en fournit un (Android, bureau),
## sinon la boîte de dialogue intégrée de Godot. Le fichier choisi est d'abord copié dans les exports du jeu
## (sur Android, le sélecteur peut renvoyer une adresse « content:// » lisible une seule fois).
func pick_import_file() -> void:
	var filters := PackedStringArray(["*.cworld ; Monde Cit-a"])
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Importer un monde", OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters, func(ok: bool, paths: PackedStringArray, _f: int):
				if ok and paths.size() > 0:
					_import_external(paths[0]))
	else:
		var dlg := FileDialog.new()
		dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dlg.access = FileDialog.ACCESS_FILESYSTEM
		dlg.filters = filters
		dlg.title = "Importer un monde"
		dlg.use_native_dialog = false
		dlg.file_selected.connect(func(p: String):
			_import_external(p)
			dlg.queue_free())
		dlg.canceled.connect(dlg.queue_free)
		ui.add_child(dlg)
		dlg.popup_centered_ratio(0.8)

func _import_external(path: String) -> void:
	var local := SaveSystem.copy_into_exports(path)
	if local == "":
		ui.show_message("Import impossible", [tr("Le fichier « %s » n'a pas pu être lu.") % path.get_file()])
		return
	import_world(local)

## Enregistre une copie de l'export là où le joueur le choisit (pour l'envoyer ou le sauvegarder ailleurs).
func export_to_device(kind: String) -> void:
	var path := SaveSystem.export_world(world, kind)
	if path == "":
		ui.show_message("Export", ["Échec de l'export."])
		return
	var save := func(dest: String):
		var msg := tr("Copie enregistrée : %s") % dest if SaveSystem.copy_file(path, dest) else tr("Impossible d'écrire à cet endroit : %s") % dest
		ui.show_message("Export", [msg])
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Enregistrer le monde", OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), path.get_file(), false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.cworld ; Monde Cit-a"]), func(ok: bool, paths: PackedStringArray, _f: int):
				if ok and paths.size() > 0:
					save.call(paths[0]))
	else:
		var dlg := FileDialog.new()
		dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		dlg.access = FileDialog.ACCESS_FILESYSTEM
		dlg.current_file = path.get_file()
		dlg.use_native_dialog = false
		dlg.file_selected.connect(func(p: String):
			save.call(p)
			dlg.queue_free())
		dlg.canceled.connect(dlg.queue_free)
		ui.add_child(dlg)
		dlg.popup_centered_ratio(0.8)

## Changement de langue : immédiat pour l'interface et le catalogue.
func set_language(locale: String) -> void:
	I18n.apply(locale, cat)
	I18n.save_locale(locale)
	ui.mark_dirty()

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
	rig.user_moved = false
	# Le temps reste en pause pendant l'apprentissage initial.
	set_speed(0 if tutorial_active() else 1)
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
	ui.refresh_hud(speed, tr("Pendant votre absence… encore %d ans à simuler") % _catchup_left)
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
	# Simulation étalée : chaque année est calculée par morceaux de 2 ms par image (pas d'à-coup).
	if world.tick_in_progress():
		if world.tick_step(2000):
			ui.mark_dirty()
	elif speed > 0:
		_acc += delta * speed
		var spt := float(cat.cfg("time", "seconds_per_tick", 1.0))
		if _acc >= spt:
			_acc = minf(_acc - spt, spt * 4.0)
			if world.tick_step(2000):
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
		# Musique : tension quand un peuple fidèle au joueur est en guerre.
		var war := false
		for p in world.peoples:
			if int(p.deity) == world.player_deity and not p.extinct and world.people_at_war(int(p.id)):
				war = true
				break
		if war and audio.mood == "paix" and audio.loops_ready():
			audio.play("war")
		audio.set_mood("tension" if war else "paix")
	_mesh_acc += delta
	update_lod()
	if _mesh_acc >= 1.0 or world.planet.version != view._built_version:
		_mesh_acc = 0.0
		view.refresh()

func update_lod() -> void:
	view.update_view(rig.camera.global_position)
	sun.shadow_enabled = view.lod > 0   # ombres inutiles de loin : économie sur mobile

func set_speed(s: int) -> void:
	speed = s
	ui.update_speed(s)

func set_overlay(o: String) -> void:
	view.set_overlay(o)

# ------------------------------------------------------------------ Sélection et pouvoirs

func _cell_at(screen_pos: Vector2) -> int:
	var cam: Camera3D = rig.camera
	var p: Vector3 = view.ray_hit(cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))
	if p == Vector3.ZERO:
		return -1
	var c: int = world.planet.nearest_cell(p)
	# Toucher près d'une bannière sélectionne le village, même hors de sa cellule centrale.
	if world.settlement_at(c).is_empty() or int(world.settlement_at(c).cell) != c:
		var best := -1
		var bd := 0.03
		for st in world.alive_settlements():
			var d: float = (world.planet.pos[int(st.cell)] - p.normalized()).length()
			if d < bd:
				bd = d
				best = int(st.cell)
		if best >= 0 and _power == "":
			return best
	return c

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

func focus_settlement(sid: int) -> void:
	var st: Dictionary = world.settlements[sid]
	rig.focus_on(world.planet.pos[int(st.cell)], 1.45)
	view.highlight([int(st.cell)], Color(1, 1, 1, 0.3))
	ui.close_modal()
	ui.show_cell(int(st.cell))

func focus_people(pid: int) -> void:
	var ps: Array = world.people_settlements(pid)
	if ps.size() > 0:
		rig.focus_on(world.planet.pos[int(ps[0].cell)], 1.9)
		view.highlight([int(ps[0].cell)], Color(1, 1, 1, 0.35))
		ui.show_cell(int(ps[0].cell))
	ui.close_modal()

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
	var pid := _power
	var cells: Array = Powers.area(world, pid, _preview_cell)
	var before := _effect_snapshot(cells)
	var d: Dictionary = world.deities[world.player_deity]
	var e0 := float(d.energy)
	var r := Powers.apply(world, world.player_deity, pid, _preview_cell, _power_opts)
	cancel_power()   # la cible est oubliée : une seconde validation ne relance rien
	if r.ok:
		_tutorial_done(2)
		view.refresh(true)
		view.pulse(cells, Color(1.0, 0.85, 0.35, 0.5))
		view.play_fx(str(cat.powers[pid].get("visual", "sparkles")), cells)
		audio.play_power(str(cat.powers[pid].family))
		ui.mark_dirty()
		ui.refresh_hud(speed)
		ui.show_toast("%s — énergie %.1f → %.1f (−%.1f)\n%s" % [r.msg, e0, float(d.energy), e0 - float(d.energy), _effect_diff(before, _effect_snapshot(cells), pid)])
		# La fiche ouverte montre le village touché, mis à jour.
		var hit: Array = Powers.settlements_in(world, cells)
		if not hit.is_empty():
			ui.show_cell(int(hit[0].cell))
	else:
		ui.show_toast("Impossible : " + str(r.msg), Color(1.0, 0.6, 0.45))
		audio.play("error")

## Valeurs observables de la zone (pour montrer l'effet réel d'un pouvoir).
func _effect_snapshot(cells: Array) -> Dictionary:
	var snap := {"height": 0.0, "moist": 0.0, "fert": 0.0, "setl": {}}
	for c in cells:
		snap.height += world.planet.height[int(c)]
		snap.moist += world.planet.moisture[int(c)]
		snap.fert += world.planet.fertility[int(c)]
	for st in Powers.settlements_in(world, cells):
		var mine := 0.0
		var rel := str(world.peoples[0].religion)
		mine = float(st.faith.get(rel, 0.0))
		snap.setl[int(st.id)] = {"name": st.name, "pop": float(st.pop), "fervor": float(st.fervor), "share": mine, "status": st.statuses.keys()}
	return snap

func _effect_diff(a: Dictionary, b: Dictionary, pid: String) -> String:
	var parts := []
	var n := 1.0
	if absf(b.height - a.height) > 0.001: parts.append("relief %+.2f" % (b.height - a.height))
	if absf(b.moist - a.moist) > 0.001: parts.append("humidité %+.2f" % (b.moist - a.moist))
	if absf(b.fert - a.fert) > 0.001: parts.append("fertilité %+.2f" % (b.fert - a.fert))
	for id in b.setl:
		var x: Dictionary = b.setl[id]
		var y: Dictionary = a.setl.get(id, x)
		var sp := []
		if roundi(x.fervor * 100.0) != roundi(y.fervor * 100.0): sp.append("ferveur %.0f → %.0f %%" % [y.fervor * 100.0, x.fervor * 100.0])
		if roundi(x.share * 100.0) != roundi(y.share * 100.0): sp.append("fidèles %.0f → %.0f %%" % [y.share * 100.0, x.share * 100.0])
		if absf(x.pop - y.pop) > 0.5: sp.append("population %d → %d" % [int(y.pop), int(x.pop)])
		for stt in x.status:
			if not stt in y.status: sp.append("état « %s »" % world.cat.temporary[stt].name)
		if sp.size() > 0: parts.append("%s : %s" % [x.name, ", ".join(sp)])
	var delayed: Array = world.cat.powers[pid].get("delayed", [])
	if delayed.size() > 0:
		parts.append("conséquence différée dans %d an(s)" % int(delayed[0].after))
	return "Effets : " + ("; ".join(parts) if parts.size() > 0 else "aucun changement mesurable ici")

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

func tutorial_active() -> bool:
	return world != null and not world.tutorial.get("skipped", false) and world.tutorial.done.size() < TUTORIAL.size()

func _tutorial_done(step: int) -> void:
	if world == null:
		return
	var was_active := tutorial_active()
	if not step in world.tutorial.done:
		world.tutorial.done.append(step)
	_update_tutorial()
	if was_active and not tutorial_active() and speed == 0:
		set_speed(1)
		ui.show_toast("Tutoriel terminé : le temps s'écoule. Pause et vitesses en haut à droite.")

## Étape courante = première non faite.
func tutorial_step() -> int:
	for i in TUTORIAL.size():
		if not i in world.tutorial.done:
			return i
	return -1

func tutorial_next() -> void:
	var st := tutorial_step()
	if st >= 0:
		_tutorial_done(st)

func tutorial_skip() -> void:
	world.tutorial["skipped"] = true
	_update_tutorial()
	if speed == 0:
		set_speed(1)

func tutorial_restart() -> void:
	world.tutorial = {"step": 0, "done": [], "skipped": false}
	rig.user_moved = false
	set_speed(0)
	_update_tutorial()

func _update_tutorial() -> void:
	if world == null:
		return
	if rig.user_moved and not 0 in world.tutorial.done and state == "play":
		world.tutorial.done.append(0)
	if not tutorial_active():
		ui.set_tutorial("")
		return
	var st := tutorial_step()
	var pause_note := "\n" + tr("(Le temps est en pause pendant l'apprentissage.)") if speed == 0 else ""
	ui.set_tutorial(tr("Tutoriel %d/%d — %s%s") % [st + 1, TUTORIAL.size(), tr(TUTORIAL[st]), pause_note], st)

# ------------------------------------------------------------------ Sauvegarde

func save_now() -> void:
	if world != null and world_id != "" and state in ["play", "catchup"]:
		world.finish_tick()   # jamais d'année à moitié calculée dans une sauvegarde
		SaveSystem.save_world(world, world_id)

func export_world(kind: String) -> String:
	var path := SaveSystem.export_world(world, kind)
	if path == "":
		return "Échec de l'export."
	return tr("Fichier créé : %s\n(chemin réel : %s)") % [path, ProjectSettings.globalize_path(path)]

## Touche « retour » d'Android : ferme ce qui est ouvert, du plus récent au plus ancien ; en partie, ouvre le menu.
## Ne quitte l'application que depuis l'écran des mondes (après sauvegarde).
func handle_back() -> String:
	if state == "founders":
		if founder_screen != null:
			founder_screen.queue_free()
			founder_screen = null
		back_to_menu()
		return "creation_annulee"
	if state == "menu":
		save_now()
		get_tree().quit()
		return "quitter"
	if _power != "":
		cancel_power()
		return "pouvoir_annule"
	if ui.modal != null:
		ui.close_modal()
		return "fenetre_fermee"
	if ui.log_panel.visible:
		ui._toggle_log()
		return "journal_ferme"
	if ui.info_panel.visible:
		ui.info_panel.visible = false
		return "fiche_fermee"
	if ui.drawer.visible:
		ui._toggle_drawer()
		return "tiroir_ferme"
	ui.show_game_menu()
	return "menu_ouvert"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_now()

func perf_text() -> String:
	return tr("[b]Mesures[/b]\nIPS %d · dernier tick %.2f ms · maillage %d sommets (reconstruit en %.0f ms)\nMémoire statique %.1f Mo · objets %d · appels de dessin %d\nÉtablissements %d · cellules %d") % [
		Engine.get_frames_per_second(), float(world.tick_ms_last), view.vertex_count(), view.last_build_ms,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), world.alive_settlements().size(), world.planet.cell_count]
