extends Control
## Interface tactile. Ne modifie la simulation qu'à travers les méthodes de main.gd (pouvoirs, règles, ordres).
## Mise en page : barre d'état en haut, rail de navigation à droite, tiroir de pouvoirs en bas, panneaux latéraux.
## Tout est placé dans une marge qui respecte la zone de sécurité de l'écran (encoches, coins arrondis).

const Affinity = preload("res://sim/affinity.gd")
const Genetics = preload("res://sim/genetics.gd")
const Civ = preload("res://sim/civ_system.gd")
const Faith = preload("res://sim/faith_system.gd")
const Powers = preload("res://sim/powers.gd")
const Planet = preload("res://sim/planet.gd")
const PlanetView = preload("res://game/planet_view.gd")
const Icons = preload("res://game/icons.gd")

const ACCENT := Color(0.96, 0.76, 0.3)
const BG := Color(0.07, 0.08, 0.14, 0.9)
const RAIL_W := 104

var main
var world
var safe: MarginContainer
var layout: Control
var top_bar: PanelContainer
var chips := {}
var energy_bar: ProgressBar
var speed_buttons := {}
var speed_label: Label
var rail: VBoxContainer
var rail_buttons := {}
var info_panel: PanelContainer
var info_text: RichTextLabel
var info_buttons: Container
var drawer: PanelContainer
var family_bar: HBoxContainer
var power_bar: HBoxContainer
var confirm_bar: PanelContainer
var confirm_label: RichTextLabel
var confirm_ok: Button
var brush_toggle: CheckButton
var tutorial_panel: PanelContainer
var tutorial_label: Label
var log_panel: PanelContainer
var log_text: RichTextLabel
var modal: Control
var current_family := "sign"
var selected_cell := -1
var _dirty := true

func build(p_main) -> void:
	main = p_main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()
	safe = MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	layout = Control.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(layout)
	_build_top_bar()
	_build_rail()
	_build_info_panel()
	_build_power_bar()
	_build_confirm_bar()
	_build_log_panel()
	_build_tutorial()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	set_play_visible(false)

## Marges = zone de sécurité de l'appareil convertie en coordonnées d'interface, + 8 px.
func _apply_safe_area() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	var vis := get_viewport().get_visible_rect().size
	var m := {"left": 8.0, "top": 8.0, "right": 8.0, "bottom": 8.0}
	if win.x > 0 and win.y > 0:
		var sa := DisplayServer.get_display_safe_area()
		var k := vis / win
		m.left += maxf(sa.position.x, 0) * k.x
		m.top += maxf(sa.position.y, 0) * k.y
		m.right += maxf(win.x - sa.end.x, 0) * k.x
		m.bottom += maxf(win.y - sa.end.y, 0) * k.y
	for side in m:
		safe.add_theme_constant_override("margin_" + side, int(m[side]))

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	var normal := _box(Color(0.14, 0.16, 0.26, 0.95), 10)
	var hover := _box(Color(0.2, 0.23, 0.36, 0.95), 10)
	var pressed := _box(ACCENT, 10)
	var disabled := _box(Color(0.12, 0.13, 0.18, 0.7), 10)
	for cls in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		th.set_stylebox("normal", cls, normal)
		th.set_stylebox("hover", cls, hover)
		th.set_stylebox("pressed", cls, pressed)
		th.set_stylebox("hover_pressed", cls, pressed)
		th.set_stylebox("disabled", cls, disabled)
		th.set_stylebox("focus", cls, _box(Color(0, 0, 0, 0), 10, ACCENT))
		th.set_color("font_color", cls, Color(0.93, 0.94, 1.0))
		th.set_color("font_pressed_color", cls, Color(0.1, 0.08, 0.04))
		th.set_color("font_hover_pressed_color", cls, Color(0.1, 0.08, 0.04))
		th.set_color("font_disabled_color", cls, Color(0.55, 0.57, 0.65))
		th.set_color("icon_pressed_color", cls, Color(0.1, 0.08, 0.04))
		th.set_color("icon_hover_pressed_color", cls, Color(0.1, 0.08, 0.04))
	th.set_stylebox("panel", "PanelContainer", _box(BG, 14))
	th.set_stylebox("background", "ProgressBar", _box(Color(0.2, 0.22, 0.32), 4))
	th.set_stylebox("fill", "ProgressBar", _box(Color(0.45, 0.8, 1.0), 4))
	th.set_font_size("font_size", "ProgressBar", 1)
	return th

func _box(col: Color, radius: int, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10; sb.content_margin_right = 10; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb

func _panel_style(alpha: float = 0.9) -> StyleBoxFlat:
	return _box(Color(BG.r, BG.g, BG.b, alpha), 14)

func _button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.pressed.connect(cb)
	return b

func _icon_button(icon: String, tip: String, cb: Callable, size: float = 52.0) -> Button:
	var b := Button.new()
	b.icon = Icons.get_icon(icon)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(size, size)
	b.tooltip_text = tip
	b.pressed.connect(cb)
	return b

## Le point écran est-il sur un élément d'interface visible ? (évite de tourner la planète en touchant un panneau)
func blocks(pos: Vector2) -> bool:
	if modal != null:
		return true
	for c in [top_bar, rail, drawer, info_panel, confirm_bar, log_panel]:
		if c != null and c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	for c in get_children():
		if c != safe and c is Control and c.visible and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(pos):
			return true
	return false

func set_world(w) -> void:
	world = w
	selected_cell = -1
	_rebuild_families()
	_dirty = true

func set_play_visible(v: bool) -> void:
	for c in [top_bar, rail, drawer, tutorial_panel]:
		c.visible = v
	info_panel.visible = false
	confirm_bar.visible = false
	log_panel.visible = false

# ------------------------------------------------------------------ Barre d'état et vitesse

func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 64
	layout.add_child(top_bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	top_bar.add_child(h)
	# Pastilles d'état (touchables : explication).
	for c in [["year", "hourglass", "Année du monde"], ["energy", "bolt", "Énergie divine disponible / maximum"],
			["faith", "flame", "Production de foi par an"], ["believers", "person", "Nombre de fidèles"]]:
		var b := Button.new()
		b.icon = Icons.get_icon(c[1])
		b.expand_icon = false
		b.flat = true
		b.tooltip_text = c[2] + " — touchez pour une explication"
		b.custom_minimum_size.y = 50
		b.pressed.connect(show_explain.bind(c[0]))
		h.add_child(b)
		chips[c[0]] = b
		if c[0] == "energy":
			energy_bar = ProgressBar.new()
			energy_bar.custom_minimum_size = Vector2(70, 10)
			energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			energy_bar.show_percentage = false
			energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(energy_bar)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	speed_label = Label.new()
	speed_label.custom_minimum_size.x = 110
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(speed_label)
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	h.add_child(group)
	for sp in [[0, "pause", "Pause"], [1, "play", "Vitesse normale (1 an/s)"], [2, "ff2", "Vitesse ×2"], [4, "ff3", "Vitesse ×4"]]:
		var b := _icon_button(sp[1], sp[2], main.set_speed.bind(sp[0]), 50)
		b.toggle_mode = true
		speed_buttons[sp[0]] = b
		group.add_child(b)

func update_speed(speed: int) -> void:
	for k in speed_buttons:
		speed_buttons[k].set_pressed_no_signal(k == speed)
	speed_label.text = "En pause" if speed == 0 else "Vitesse ×%d" % speed
	speed_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45) if speed == 0 else Color(0.85, 0.9, 1.0))

# ------------------------------------------------------------------ Rail de navigation

func _build_rail() -> void:
	rail = VBoxContainer.new()
	rail.anchor_left = 1.0; rail.anchor_right = 1.0; rail.anchor_top = 0.0; rail.anchor_bottom = 1.0
	rail.offset_left = -RAIL_W; rail.offset_right = 0; rail.offset_top = 72; rail.offset_bottom = -8
	rail.add_theme_constant_override("separation", 6)
	layout.add_child(rail)
	for item in [["powers", "star", "Pouvoirs", _toggle_drawer], ["faith", "flame", "Foi", func(): show_deity(world.player_deity)],
			["peoples", "people", "Peuples", show_peoples], ["affinity", "sword", "Affinités", show_affinity_rules],
			["journal", "book", "Journal", _toggle_log], ["maps", "globe", "Cartes", show_overlays]]:
		var b := Button.new()
		b.icon = Icons.get_icon(item[1])
		b.text = item[2]
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = false
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(RAIL_W, 66)
		b.pressed.connect(item[3])
		rail.add_child(b)
		rail_buttons[item[0]] = b
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(spacer)
	var menu := _icon_button("menu", "Menu : sauvegarde, export, mondes", show_game_menu, 52)
	menu.custom_minimum_size = Vector2(RAIL_W, 48)
	rail.add_child(menu)

func _build_tutorial() -> void:
	tutorial_panel = PanelContainer.new()
	tutorial_panel.add_theme_stylebox_override("panel", _box(Color(0.12, 0.1, 0.04, 0.85), 12, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6)))
	tutorial_panel.anchor_left = 0.5; tutorial_panel.anchor_right = 0.5
	tutorial_panel.offset_left = -330; tutorial_panel.offset_right = 330; tutorial_panel.offset_top = 72
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(tutorial_panel)
	tutorial_label = Label.new()
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.add_theme_color_override("font_color", Color(1, 0.93, 0.7))
	tutorial_label.add_theme_font_size_override("font_size", 18)
	tutorial_panel.add_child(tutorial_label)

func set_tutorial(text: String) -> void:
	tutorial_label.text = text
	# Masqué quand un panneau occupe déjà l'écran, pour ne jamais recouvrir d'information.
	tutorial_panel.visible = text != "" and top_bar.visible and not info_panel.visible and not log_panel.visible and not confirm_bar.visible

# ------------------------------------------------------------------ Panneau d'information (sélection)

func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.anchor_left = 1.0; info_panel.anchor_right = 1.0; info_panel.anchor_top = 0.0; info_panel.anchor_bottom = 1.0
	info_panel.offset_left = -RAIL_W - 430; info_panel.offset_right = -RAIL_W - 8; info_panel.offset_top = 72; info_panel.offset_bottom = -158
	layout.add_child(info_panel)
	var v := VBoxContainer.new()
	info_panel.add_child(v)
	v.add_child(_button("Fermer", _close_info))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	info_text = RichTextLabel.new()
	info_text.bbcode_enabled = true
	info_text.fit_content = true
	info_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(info_text)
	info_buttons = HFlowContainer.new()
	v.add_child(info_buttons)

func show_cell(cell: int) -> void:
	selected_cell = cell
	info_panel.visible = cell >= 0
	refresh_info()

func refresh_info() -> void:
	if selected_cell < 0 or world == null:
		return
	var pl = world.planet
	var c := selected_cell
	var t := "[b]%s[/b]\nTempérature %.0f %% · Humidité %.0f %% · Fertilité %.0f %%\nRessources : %s\n" % [
		Planet.BIOME_NAMES[pl.biome_name(c)], pl.temperature[c] * 100.0, pl.moisture[c] * 100.0, pl.fertility[c] * 100.0,
		", ".join(pl.res_list(c).map(func(r): return Planet.RES_NAMES[r])) if pl.res_list(c).size() > 0 else "aucune"]
	for ch in info_buttons.get_children():
		ch.queue_free()
	var s: Dictionary = world.settlement_at(c)
	if not s.is_empty():
		var p: Dictionary = world.peoples[int(s.people)]
		var tot := maxf(float(s.aff.none) + float(s.aff.magic) + float(s.aff.sword) + float(s.aff.both), 1.0)
		t += "\n[b][color=#ffd966]%s[/color][/b] — %s (%s)\n" % [s.name, p.name, p.polity]
		t += "Population %d / capacité %d · Stabilité %.0f %%\n" % [int(s.pop), int(s.capacity), float(s.stability) * 100.0]
		t += "Réserves de nourriture : %d · Force militaire %.0f\n" % [int(s.food), float(s.military)]
		t += "\n[b]Affinités[/b] (sur %d habitants)\n" % int(tot)
		for a in ["none", "magic", "sword", "both"]:
			t += "  %s : %d (%.1f %%)\n" % [Affinity.NAMES[a], int(s.aff[a]), float(s.aff[a]) / tot * 100.0]
		t += "  Maîtrise magique %.0f %% · maîtrise de l'épée %.0f %% (apprentissage des porteurs)\n" % [float(s.mastery.magic) * 100.0, float(s.mastery.sword) * 100.0]
		t += "  Entraînement aux armes (compétence ordinaire, tous) %.0f %%\n" % (float(s.training) * 100.0)
		var bs: Dictionary = s.births
		t += "  Naissances : %d ouvertes au divin (%d sans attribution), %d naturelles\n" % [int(bs.divine_slots), int(bs.divine_none), int(bs.natural_slots)]
		t += "\n[b]Foi[/b] — ferveur %.0f %%\n" % (float(s.fervor) * 100.0)
		for rid in s.faith:
			t += "  %s : %.0f %%\n" % [world.religions[int(rid)].name, float(s.faith[rid]) * 100.0]
		var unbelief := 1.0
		for rid in s.faith:
			unbelief -= float(s.faith[rid])
		t += "  Sans religion : %.0f %%\n" % (maxf(unbelief, 0.0) * 100.0)
		if not s.statuses.is_empty():
			var st := []
			for k in s.statuses:
				st.append("%s (%d ans)" % [world.cat.temporary[k].name, int(s.statuses[k])])
			t += "\n[b]États temporaires[/b] : %s\n" % ", ".join(st)
		t += "\n[b]Traits héréditaires dominants[/b]\n"
		var keys: Array = s.freqs.keys()
		keys.sort_custom(func(a, b): return float(s.freqs[a]) > float(s.freqs[b]))
		for k in keys.slice(0, 8):
			t += "  %s %.0f %%\n" % [world.cat.traits[k].name, float(s.freqs[k]) * 100.0]
		info_buttons.add_child(_button("Peuple", show_people.bind(int(s.people))))
		info_buttons.add_child(_button("Habitants", show_individuals.bind(int(s.id))))
		info_buttons.add_child(_button("Dieu", show_deity.bind(int(p.deity))))
		info_buttons.add_child(_button("Intervenir (affinités)", show_manual_affinity.bind(int(s.id))))
	info_text.text = t

# ------------------------------------------------------------------ Pouvoirs (tiroir du bas)

func _build_power_bar() -> void:
	drawer = PanelContainer.new()
	drawer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	drawer.offset_top = -150
	drawer.offset_right = -RAIL_W - 8
	layout.add_child(drawer)
	var v := VBoxContainer.new()
	drawer.add_child(v)
	var fs := ScrollContainer.new()
	fs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fs.custom_minimum_size.y = 58
	v.add_child(fs)
	family_bar = HBoxContainer.new()
	fs.add_child(family_bar)
	var ps := ScrollContainer.new()
	ps.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ps.custom_minimum_size.y = 62
	v.add_child(ps)
	power_bar = HBoxContainer.new()
	ps.add_child(power_bar)

func _toggle_drawer() -> void:
	drawer.visible = not drawer.visible
	rail_buttons.powers.set_pressed_no_signal(drawer.visible)

const FAMILY_ICONS := {"terrain": "mountain", "climate": "cloud", "vegetation": "leaf", "life": "heart", "evolution": "dna",
	"affinity": "sword", "healing": "cross", "blessing": "sun", "inspiration": "bulb", "sign": "eye", "catastrophe": "bolt"}
const FAMILY_SHORT := {"terrain": "Terrain", "climate": "Climat", "vegetation": "Végétation", "life": "Vie", "evolution": "Évolution",
	"affinity": "Affinités", "healing": "Soins", "blessing": "Bénédictions", "inspiration": "Révélations", "sign": "Signes", "catastrophe": "Catastrophes"}

func _rebuild_families() -> void:
	for c in family_bar.get_children():
		c.queue_free()
	for fam in world.cat.power_families:
		var b := Button.new()
		b.icon = Icons.get_icon(FAMILY_ICONS.get(fam, "star"))
		b.text = FAMILY_SHORT.get(fam, fam)
		b.tooltip_text = world.cat.power_families[fam]
		b.toggle_mode = true
		b.custom_minimum_size.y = 52
		b.button_pressed = fam == current_family
		b.set_meta("family", fam)
		b.pressed.connect(_select_family.bind(fam))
		family_bar.add_child(b)
	_rebuild_powers()

func _select_family(fam: String) -> void:
	current_family = fam
	for b in family_bar.get_children():
		b.set_pressed_no_signal(b.get_meta("family", "") == fam)
	_rebuild_powers()

func _rebuild_powers() -> void:
	for c in power_bar.get_children():
		c.queue_free()
	var d: Dictionary = world.deities[world.player_deity]
	for pid in world.cat.power_order:
		var p: Dictionary = world.cat.powers[pid]
		if p.family != current_family:
			continue
		var unlocked := Powers.is_unlocked(world, d, pid)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 56)
		if unlocked:
			b.text = "%s  ·  %s" % [p.name, ("%.0f énergie" % float(p.cost)) if pid != "don_affinite" else "coût variable"]
			b.icon = Icons.get_icon("bolt")
			b.disabled = float(d.energy) < float(p.cost) and pid != "don_affinite"
		else:
			b.text = "%s  (niveau %d)" % [p.name, int(p.unlock.get("level", 0))]
			b.icon = Icons.get_icon("lock")
			b.disabled = true
		b.tooltip_text = "%s\n%s" % [p.desc, p.interactions]
		b.pressed.connect(main.select_power.bind(pid))
		power_bar.add_child(b)
	brush_toggle = CheckButton.new()
	brush_toggle.text = "Pinceau"
	brush_toggle.tooltip_text = "Glisser le doigt applique le pouvoir de terrain en continu"
	brush_toggle.visible = current_family == "terrain"
	brush_toggle.toggled.connect(main.set_brush)
	power_bar.add_child(brush_toggle)

func _build_confirm_bar() -> void:
	confirm_bar = PanelContainer.new()
	confirm_bar.add_theme_stylebox_override("panel", _box(Color(0.06, 0.07, 0.12, 0.96), 14, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7)))
	confirm_bar.anchor_left = 0.5; confirm_bar.anchor_right = 0.5; confirm_bar.anchor_top = 1.0; confirm_bar.anchor_bottom = 1.0
	confirm_bar.offset_left = -400; confirm_bar.offset_right = 340; confirm_bar.offset_top = -318; confirm_bar.offset_bottom = -158
	layout.add_child(confirm_bar)
	var h := HBoxContainer.new()
	confirm_bar.add_child(h)
	confirm_label = RichTextLabel.new()
	confirm_label.bbcode_enabled = true
	confirm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(confirm_label)
	var v := VBoxContainer.new()
	h.add_child(v)
	confirm_ok = _button("Valider", main.confirm_power, 150)
	v.add_child(confirm_ok)
	v.add_child(_button("Annuler", main.cancel_power, 150))

func show_targeting(pid: String) -> void:
	var p: Dictionary = world.cat.powers[pid]
	confirm_bar.visible = true
	confirm_ok.disabled = true
	confirm_label.text = "[b]%s[/b]\n%s\n[i]Touchez une région de la planète pour prévisualiser la zone et le coût.[/i]" % [p.name, p.desc]

func show_preview(pv: Dictionary, delayed: Array) -> void:
	confirm_bar.visible = true
	confirm_ok.disabled = not pv.ok
	var t := "[b]%s[/b] — coût [color=#7fd4ff]%.1f[/color] énergie\nZone : %d cellule(s), %d établissement(s)\n" % [pv.name, float(pv.cost), pv.cells.size(), pv.settlements.size()]
	if not delayed.is_empty():
		t += "Conséquences différées : %s\n" % ", ".join(delayed.map(func(e): return "%s dans %d ans" % [e.t, int(e.after)]))
	for wmsg in pv.warnings:
		t += "[color=#ff9966]Attention : %s[/color]\n" % wmsg
	if not pv.ok:
		t += "[color=#ff6666]%s[/color]" % pv.reason
	confirm_label.text = t

func hide_targeting() -> void:
	confirm_bar.visible = false

# ------------------------------------------------------------------ Journal

func _build_log_panel() -> void:
	log_panel = PanelContainer.new()
	log_panel.anchor_left = 0.0; log_panel.anchor_right = 0.0; log_panel.anchor_top = 0.0; log_panel.anchor_bottom = 1.0
	log_panel.offset_left = 0; log_panel.offset_right = 540; log_panel.offset_top = 72; log_panel.offset_bottom = -158
	layout.add_child(log_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(scroll)
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.fit_content = true
	log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_text)

func _toggle_log() -> void:
	log_panel.visible = not log_panel.visible
	rail_buttons.journal.set_pressed_no_signal(log_panel.visible)
	main.on_log_opened()
	refresh_log()

const KIND_COLORS := {"tech": "#9fe0ff", "war": "#ff7a6b", "faith": "#ffd966", "crisis": "#ffab66", "disaster": "#ff8c8c",
	"genetics": "#b7f7a6", "settlement": "#e6e6e6", "diplomacy": "#d7b3ff", "power": "#fff2a8", "deity": "#ffe680", "politics": "#c6d2ff", "people": "#ffffff"}

func refresh_log() -> void:
	if not log_panel.visible or world == null:
		return
	var t := "[b]Journal du monde[/b] (le plus récent en haut)\n"
	var n: int = world.chronicle.size()
	for i in range(n - 1, maxi(-1, n - 80), -1):
		var e: Dictionary = world.chronicle[i]
		t += "[color=%s]An %d — %s[/color]\n   [i][color=#9aa]Cause : %s[/color][/i]\n" % [KIND_COLORS.get(e.kind, "#ffffff"), int(e.y), e.txt, e.why]
	log_text.text = t

# ------------------------------------------------------------------ Mise à jour régulière

func mark_dirty() -> void:
	_dirty = true

func refresh_hud(speed: int, catching_up: String = "") -> void:
	if world == null:
		return
	var d: Dictionary = world.deities[world.player_deity]
	chips.year.text = "An %d" % world.year
	chips.energy.text = "%.0f / %.0f" % [float(d.energy), float(d.max_energy)]
	chips.faith.text = "+%.2f/an" % float(d.faith_rate)
	chips.believers.text = "%d" % int(d.believers)
	energy_bar.max_value = float(d.max_energy)
	energy_bar.value = float(d.energy)
	if catching_up != "":
		speed_label.text = catching_up
	else:
		update_speed(speed)
	if _dirty:
		_dirty = false
		refresh_info()
		refresh_log()
		_rebuild_powers_if_changed(int(d.level), int(float(d.energy)))

var _last_power_state := ""
func _rebuild_powers_if_changed(lvl: int, energy: int) -> void:
	var st := "%d_%d" % [lvl, energy]
	if st != _last_power_state:
		_last_power_state = st
		_rebuild_powers()

## Explications accessibles des grandeurs affichées.
func show_explain(topic: String) -> void:
	var d: Dictionary = world.deities[world.player_deity]
	match topic:
		"year":
			show_message("Le temps", ["Un tour de simulation = 1 an. Utilisez la pause et les vitesses en haut à droite.", "Pendant votre absence, le monde avance (8 h maximum)."])
		"energy":
			show_message("Énergie divine", ["Réserve dépensée par les pouvoirs et les dons d'affinité : %.1f sur %.0f." % [float(d.energy), float(d.max_energy)],
				"Elle se remplit chaque année grâce à la foi produite par vos fidèles. Le maximum augmente avec votre niveau.",
				"Sans fidèles, une étincelle se régénère lentement : vous pouvez toujours murmurer."])
		"faith":
			show_message("Production de foi", ["+%.2f énergie par an." % float(d.faith_rate), "Elle dépend du nombre de fidèles × leur ferveur × leurs temples.",
				"Les miracles vus augmentent la ferveur ; les crises sans aide divine la font baisser."])
		"believers":
			show_message("Fidèles", ["%d personnes croient en vous, dans tous les peuples." % int(d.believers), "Une religion peut dépasser les frontières de votre peuple : elle se diffuse entre voisins."])

func show_peoples() -> void:
	var body := open_modal("Peuples du monde")
	for p in world.peoples:
		if p.extinct:
			continue
		var row := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = Color(p.color[0], p.color[1], p.color[2])
		sw.custom_minimum_size = Vector2(18, 40)
		row.add_child(sw)
		var l := Label.new()
		l.text = "%s — %s, %d hab., %d villages · %s" % [p.name, p.polity, int(world.people_pop(int(p.id))), world.people_settlements(int(p.id)).size(), world.deities[int(p.deity)].name]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		row.add_child(_button("Voir", main.focus_people.bind(int(p.id))))
		row.add_child(_button("Fiche", show_people.bind(int(p.id))))
		body.add_child(row)

func show_overlays() -> void:
	var body := open_modal("Cartes thématiques")
	body.add_child(_rich("Choisissez ce que la planète affiche. La grille des cellules de simulation n'apparaît qu'en mode « Grille »."))
	for k in PlanetView.OVERLAYS:
		var b := _button(PlanetView.OVERLAYS[k], func():
			main.set_overlay(k)
			close_modal())
		b.toggle_mode = true
		b.button_pressed = main.view.overlay == k
		body.add_child(b)

# ------------------------------------------------------------------ Fenêtres modales

func open_modal(title: String, wide: bool = false) -> VBoxContainer:
	close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.97))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := 40 if wide else 140
	panel.offset_left = m; panel.offset_right = -m; panel.offset_top = 30; panel.offset_bottom = -30
	modal.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_font_size_override("font_size", 28)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tl)
	h.add_child(_icon_button("close", "Fermer", close_modal, 52))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return body

func close_modal() -> void:
	if modal != null:
		modal.queue_free()
		modal = null

func _rich(text: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.text = text
	return r

func show_message(title: String, lines: Array) -> void:
	var body := open_modal(title)
	body.add_child(_rich("\n".join(lines)))

func show_people(pid: int) -> void:
	var p: Dictionary = world.peoples[pid]
	var body := open_modal(p.name)
	var agg := Civ.people_aggregate(world, p)
	var t := "[b]%s[/b] · %s · %s\n" % [world.cat.species[p.species].name, p.polity, world.cat.eras[int(p.era)]]
	t += "Population %d dans %d établissement(s) · stabilité moyenne %.0f %%\n" % [int(agg.pop), world.people_settlements(pid).size(), agg.stability * 100.0]
	var lean := float(p.lean)
	t += "Voie : %s (%.2f)\n" % ["science" if lean > 0.2 else ("magie" if lean < -0.2 else "hybride"), lean]
	t += "Porteurs d'affinité : magie %.1f %% · épée %.1f %%\n" % [agg.share_magic * 100.0, agg.share_sword * 100.0]
	t += "\n[b]Origines[/b] — fondé en l'an %d par :\n" % int(p.founded)
	for f in p.founders:
		t += "  %s (%s) — %s\n" % [f.name, Affinity.NAMES[f.get("affinity", "none")], ", ".join(f.traits.map(func(x): return world.cat.traits[x].name if world.cat.traits.has(x) else x))]
	t += "\n[b]Découvertes[/b] (%d)\n  %s\n" % [p.techs.size(), ", ".join(p.techs.keys().map(func(x): return world.cat.techs[x].name))]
	var cur: String = p.research.current
	if cur != "":
		t += "Recherche en cours : %s (%.0f / %.0f)\n" % [world.cat.techs[cur].name, float(p.research.progress), float(world.cat.techs[cur].cost)]
	else:
		t += "[color=#ffab66]Aucune recherche possible (stagnation)[/color]\n"
	t += "\n[b]Prochaines découvertes et obstacles[/b]\n"
	var shown := 0
	for tid in world.cat.tech_order:
		if p.techs.has(tid) or shown >= 6:
			continue
		var why := Civ.tech_block_reason(world, p, tid, agg)
		t += "  %s [%s] : %s\n" % [world.cat.techs[tid].name, world.cat.techs[tid].path, "disponible" if why == "" else why]
		shown += 1
	if not p.culture.is_empty():
		t += "\n[b]Culture (traits acquis)[/b] : %s\n" % ", ".join(p.culture.keys().map(func(x): return world.cat.traits[x].name))
	t += "\n[b]Relations[/b]\n"
	for o in world.peoples:
		if int(o.id) == pid or o.extinct:
			continue
		var k: String = world.rel_key(pid, int(o.id))
		if world.relations.has(k):
			var r: Dictionary = world.relations[k]
			t += "  %s : %.2f%s%s\n" % [o.name, float(r.value), " — GUERRE" if r.war else "", " — alliance" if r.alliance else ""]
	t += "\n[b]Histoire[/b]\n"
	for hst in p.history.slice(maxi(0, p.history.size() - 15)):
		t += "  An %d — %s\n" % [int(hst.year), hst.text]
	body.add_child(_rich(t))

func show_individuals(sid: int) -> void:
	var s: Dictionary = world.settlements[sid]
	var p: Dictionary = world.peoples[int(s.people)]
	var body := open_modal("Habitants représentatifs de " + s.name)
	body.add_child(_rich("[i]Individus tirés de la distribution réelle de l'établissement (affichage seulement : la simulation est agrégée).[/i]\n"))
	for ind in Genetics.representatives(world.cat, s, p.species, 6, sid * 31 + world.year):
		var t := "[b]%s[/b], %d ans — [color=#ffd966]%s[/color]\n" % [ind.name, int(ind.age), Affinity.NAMES[ind.affinity]]
		t += "  Traits : %s\n" % (", ".join(ind.traits.map(func(x): return world.cat.traits[x].name)) if ind.traits.size() > 0 else "aucun trait marquant")
		t += "  Maîtrise magique %.0f %% · maîtrise de l'épée %.0f %% · entraînement aux armes %.0f %%\n" % [float(ind.mastery_magic) * 100.0, float(ind.mastery_sword) * 100.0, float(ind.weapon_training) * 100.0]
		body.add_child(_rich(t))

func show_deity(did: int) -> void:
	var d: Dictionary = world.deities[did]
	var body := open_modal(d.name)
	var pers: Dictionary = d.personality
	var t := "%s\n" % ("[b]Vous[/b]" if d.is_player else "Divinité rivale")
	t += "Bienveillance %.0f %% · agressivité %.0f %% · penchant %s\n" % [float(pers.benevolence) * 100.0, float(pers.aggression) * 100.0, "magique" if float(pers.magic_bias) > 0.2 else ("guerrier" if float(pers.magic_bias) < -0.2 else "équilibré")]
	t += "\n[b]Foi[/b]\n  Fidèles : %d\n  Production de foi : %.2f / an\n  Énergie divine : %.1f / %.0f\n  Niveau %d (XP %d)\n" % [int(d.believers), float(d.faith_rate), float(d.energy), float(d.max_energy), int(d.level), int(d.xp)]
	t += "  Affinités conférées : %d · pouvoirs utilisés : %d\n" % [int(d.affinities_granted), int(d.powers_used)]
	t += "\n[b]Objectifs (débloquent la progression)[/b]\n"
	for a in world.cat.achievements:
		var done: bool = a.id in d.achievements
		var cur := Faith.metric(world, d, a.cond.type)
		t += "  %s %s — %s (%s / %s, +%d XP)\n" % ["✔" if done else "○", a.name, a.desc, str(snappedf(cur, 1.0)), str(a.cond.value), int(a.xp)]
	t += "\n[b]Relations divines[/b]\n"
	for o in world.deities:
		if int(o.id) != did:
			t += "  %s : %.2f\n" % [o.name, float(d.relations.get(str(o.id), 0.0))]
	body.add_child(_rich(t))

# ------------------------------------------------------------------ Affinités : règles automatiques

func show_affinity_rules() -> void:
	var d: Dictionary = world.deities[world.player_deity]
	var body := open_modal("Affinités : règles divines automatiques", true)
	var cfg: Dictionary = world.cat.config.affinity
	var p: Dictionary = cfg.natural_probabilities
	body.add_child(_rich("Sur 3 naissances, [b]2 sont ouvertes à votre attribution[/b] (sinon : sans affinité, aucun tirage de remplacement) et [b]1 est naturelle[/b] (hasard : sans %.0f %% · Magie %.0f %% · Épée %.0f %%). [b]Seul un dieu peut conférer Magie et Épée.[/b]\nCoût par naissance : Magie %.1f · Épée %.1f · les deux %.1f énergie. Les règles s'appliquent par priorité croissante ; la première qui correspond décide." % [
		float(p.none) * 100.0, float(p.magic) * 100.0, float(p.sword) * 100.0, float(cfg.cost.magic), float(cfg.cost.sword), float(cfg.cost.both)]))
	var bh := HBoxContainer.new()
	body.add_child(bh)
	var bl := Label.new(); bl.text = "Budget automatique par an (énergie) :"
	bh.add_child(bl)
	var bs := SpinBox.new(); bs.min_value = 0; bs.max_value = 200; bs.step = 0.5; bs.value = float(d.auto_budget)
	bs.value_changed.connect(func(v): d.auto_budget = v)
	bh.add_child(bs)
	var rules: Array = d.rules
	rules.sort_custom(func(a, b): return int(a.priority) < int(b.priority))
	for i in rules.size():
		body.add_child(_rule_row(d, rules[i]))
	body.add_child(_button("+ Nouvelle règle", func():
		var id := int(d.next_rule_id)
		d.next_rule_id = id + 1
		d.rules.append(Affinity.new_rule(id, "Règle %d" % id, Affinity.MAGIC, [{"field": "own_people"}], rules.size() + 1, 3))
		main.on_rules_changed()
		show_affinity_rules()))
	var st: Dictionary = world.stats_births
	var t := "\n[b]Statistiques mondiales des naissances[/b]\n  Ouvertes au divin : %d (sans attribution : %d ; Magie %d · Épée %d · les deux %d)\n  Naturelles : %d (sans %d · Magie %d · Épée %d)\n  Interventions tardives : Magie %d · Épée %d · les deux %d\n" % [
		int(st.divine_slots), int(st.divine_none), int(st.divine.magic), int(st.divine.sword), int(st.divine.both),
		int(st.natural_slots), int(st.natural.none), int(st.natural.magic), int(st.natural.sword), int(st.late.magic), int(st.late.sword), int(st.late.both)]
	t += "\n[b]Historique récent[/b]\n"
	var hist: Array = world.affinity_history
	for i in range(hist.size() - 1, maxi(-1, hist.size() - 25), -1):
		var e: Dictionary = hist[i]
		var who: String = "hasard" if int(e.deity) < 0 else world.deities[int(e.deity)].name
		t += "  An %d — %s ×%d à %s — %s (%s)\n" % [int(e.year), Affinity.NAMES[e.result], int(e.count), world.settlements[int(e.settlement)].name, e.reason, who]
	body.add_child(_rich(t))

func _rule_row(d: Dictionary, r: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _panel_style(0.6))
	var v := VBoxContainer.new()
	box.add_child(v)
	var h := HFlowContainer.new()
	v.add_child(h)
	var en := CheckBox.new(); en.text = "Active"; en.button_pressed = r.enabled
	en.toggled.connect(func(on):
		r.enabled = on
		main.on_rules_changed())
	h.add_child(en)
	var name_edit := LineEdit.new(); name_edit.text = r.name; name_edit.custom_minimum_size.x = 260
	name_edit.text_changed.connect(func(tx): r.name = tx)
	h.add_child(name_edit)
	var pr := SpinBox.new(); pr.prefix = "Priorité"; pr.min_value = 0; pr.max_value = 99; pr.value = int(r.priority); pr.custom_minimum_size.x = 190
	pr.value_changed.connect(func(vv): r.priority = int(vv))
	h.add_child(pr)
	var res := OptionButton.new()
	for a in [Affinity.MAGIC, Affinity.SWORD, Affinity.BOTH]:
		res.add_item("→ " + Affinity.NAMES[a])
		if a == r.result:
			res.select(res.item_count - 1)
	res.item_selected.connect(func(idx): r.result = [Affinity.MAGIC, Affinity.SWORD, Affinity.BOTH][idx])
	h.add_child(res)
	var mx := SpinBox.new(); mx.prefix = "Max/an"; mx.min_value = 0; mx.max_value = 500; mx.value = int(r.max_per_year); mx.custom_minimum_size.x = 190
	mx.value_changed.connect(func(vv): r.max_per_year = int(vv))
	h.add_child(mx)
	h.add_child(_button("Supprimer", func():
		d.rules.erase(r)
		main.on_rules_changed()
		show_affinity_rules()))
	for ci in r.conditions.size():
		v.add_child(_condition_row(r, r.conditions[ci]))
	var add := _button("+ Condition", func():
		r.conditions.append({"field": "always"})
		show_affinity_rules())
	v.add_child(add)
	var stats := Label.new()
	stats.text = "Appliquée %d fois au total, %d cette année · refusée %d fois faute de budget/énergie" % [int(r.total), int(r.used_this_year), int(r.get("blocked_budget", 0))]
	v.add_child(stats)
	return box

func _condition_row(r: Dictionary, cond: Dictionary) -> Control:
	var h := HFlowContainer.new()
	var lbl := Label.new(); lbl.text = "  si"
	h.add_child(lbl)
	var field := OptionButton.new()
	var fields: Array = Affinity.CONDITION_FIELDS.keys()
	for f in fields:
		field.add_item(Affinity.CONDITION_FIELDS[f])
		if f == cond.field:
			field.select(field.item_count - 1)
	field.item_selected.connect(func(idx):
		cond.clear()
		cond.field = fields[idx]
		_default_condition(cond)
		show_affinity_rules())
	h.add_child(field)
	match str(cond.field):
		"species":
			h.add_child(_choice(world.cat.species_order, world.cat.species_order.map(func(x): return world.cat.species[x].name), cond, "value"))
		"biome":
			var bl: Array = Planet.BIOMES.slice(2)
			h.add_child(_choice(bl, bl.map(func(x): return Planet.BIOME_NAMES[x]), cond, "value"))
		"lineage_share":
			h.add_child(_choice(["magic", "sword", "both", "none"], ["Magie", "Épée", "Magie et Épée", "Sans affinité"], cond, "key"))
			h.add_child(_choice(["<", ">="], ["<", "≥"], cond, "op"))
			h.add_child(_number(cond, 100.0, "%"))
		"trait_freq":
			h.add_child(_choice(world.cat.trait_order, world.cat.trait_order.map(func(x): return world.cat.traits[x].name), cond, "key"))
			h.add_child(_choice(["<", ">="], ["<", "≥"], cond, "op"))
			h.add_child(_number(cond, 100.0, "%"))
		"need":
			h.add_child(_choice(Affinity.NEEDS.keys(), Affinity.NEEDS.values(), cond, "value"))
		"population":
			h.add_child(_choice(["<", ">="], ["<", "≥"], cond, "op"))
			h.add_child(_number(cond, 1.0, " hab."))
	h.add_child(_icon_button("close", "Retirer la condition", _remove_condition.bind(r, cond), 48))
	return h

func _remove_condition(r: Dictionary, cond: Dictionary) -> void:
	r.conditions.erase(cond)
	show_affinity_rules()

func _close_info() -> void:
	info_panel.visible = false
	main.clear_selection()

func _default_condition(cond: Dictionary) -> void:
	match str(cond.field):
		"species":
			cond.value = world.cat.species_order[0]
		"biome":
			cond.value = "grassland"
		"lineage_share":
			cond.key = "magic"
			cond.op = "<"
			cond.value = 0.1
		"trait_freq":
			cond.key = world.cat.trait_order[0]
			cond.op = ">="
			cond.value = 0.3
		"need":
			cond.value = "defense"
		"population":
			cond.op = ">="
			cond.value = 100

func _choice(keys: Array, labels: Array, cond: Dictionary, prop: String) -> OptionButton:
	var o := OptionButton.new()
	for i in keys.size():
		o.add_item(str(labels[i]))
		if str(keys[i]) == str(cond.get(prop, "")):
			o.select(i)
	o.item_selected.connect(func(idx): cond[prop] = keys[idx])
	return o

func _number(cond: Dictionary, scale: float, suffix: String) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = 0
	s.max_value = 100000 if scale == 1.0 else 100
	s.suffix = suffix
	s.value = float(cond.get("value", 0.0)) * scale
	s.value_changed.connect(func(v): cond.value = v / scale)
	return s

# ------------------------------------------------------------------ Affinités : intervention manuelle

func show_manual_affinity(sid: int) -> void:
	var s: Dictionary = world.settlements[sid]
	var d: Dictionary = world.deities[world.player_deity]
	var body := open_modal("Intervenir à " + s.name)
	body.add_child(_rich("[b]1. Réserver les prochaines naissances ouvertes au divin[/b]\nCes naissances recevront l'affinité choisie (si les parents vous vénèrent et si l'énergie suffit au moment de la naissance). Les ordres manuels passent avant les règles automatiques."))
	var h := HBoxContainer.new()
	body.add_child(h)
	var aff := OptionButton.new()
	for a in [Affinity.MAGIC, Affinity.SWORD, Affinity.BOTH]:
		aff.add_item(Affinity.NAMES[a])
	h.add_child(aff)
	var cnt := SpinBox.new(); cnt.min_value = 1; cnt.max_value = 50; cnt.value = 3; cnt.prefix = "Nombre"
	h.add_child(cnt)
	h.add_child(_button("Réserver", func():
		d.manual_orders.append({"settlement": sid, "affinity": [Affinity.MAGIC, Affinity.SWORD, Affinity.BOTH][aff.selected], "remaining": int(cnt.value)})
		main.on_rules_changed()
		show_manual_affinity(sid)))
	var orders := "Ordres en attente ici : "
	var any := false
	for o in d.manual_orders:
		if int(o.settlement) == sid:
			orders += "%s ×%d  " % [Affinity.NAMES[o.affinity], int(o.remaining)]
			any = true
	body.add_child(_rich(orders if any else orders + "aucun"))
	var cfg: Dictionary = world.cat.config.affinity
	body.add_child(_rich("\n[b]2. Don immédiat à des habitants déjà nés[/b]\nSeule voie pour qu'une personne née sans affinité en obtienne une. Coût tardif ×%.1f : Magie %.1f · Épée %.1f · les deux %.1f par personne. L'affinité ne donne aucune maîtrise immédiate." % [
		float(cfg.late_grant_cost_multiplier), Affinity.cost_of(world, "magic", true), Affinity.cost_of(world, "sword", true), Affinity.cost_of(world, "both", true)]))
	var h2 := HBoxContainer.new()
	body.add_child(h2)
	var aff2 := OptionButton.new()
	for a in [Affinity.MAGIC, Affinity.SWORD, Affinity.BOTH]:
		aff2.add_item(Affinity.NAMES[a])
	h2.add_child(aff2)
	var cnt2 := SpinBox.new(); cnt2.min_value = 1; cnt2.max_value = 50; cnt2.value = 2; cnt2.prefix = "Nombre"
	h2.add_child(cnt2)
	h2.add_child(_button("Prévisualiser", func():
		close_modal()
		main.select_power("don_affinite", {"affinity": [Affinity.MAGIC, Affinity.SWORD, Affinity.BOTH][aff2.selected], "count": int(cnt2.value)})
		main.preview_at(int(s.cell))))

# ------------------------------------------------------------------ Menus

func show_game_menu() -> void:
	var body := open_modal("Menu")
	body.add_child(_button("Sauvegarder", func():
		main.save_now()
		show_message("Sauvegarde", ["Monde sauvegardé."])))
	body.add_child(_button("Exporter le monde initial (planète à découvrir)", func(): show_message("Export", [main.export_world("seed")])))
	body.add_child(_button("Exporter le monde évolué (partie complète)", func(): show_message("Export", [main.export_world("evolved")])))
	var share := Button.new()
	share.text = "Partage en ligne — non connecté"
	share.disabled = true
	share.custom_minimum_size.y = 52
	body.add_child(share)
	body.add_child(_rich("[i]Le partage en ligne nécessite un service d'hébergement qui n'est pas encore configuré (voir docs/ARCHITECTURE.md). L'export local produit un fichier .cworld partageable manuellement.[/i]"))
	body.add_child(_button("Retour à l'écran des mondes", main.back_to_menu))
	body.add_child(_rich(main.perf_text()))

func show_main_menu(worlds: Array, exports: Array) -> void:
	var body := open_modal("Cit-a — simulateur divin", true)
	var h := HBoxContainer.new()
	body.add_child(h)
	var seed_edit := LineEdit.new()
	seed_edit.placeholder_text = "Graine (vide = aléatoire)"
	seed_edit.custom_minimum_size.x = 320
	h.add_child(seed_edit)
	h.add_child(_button("Nouveau monde", func(): main.new_world(seed_edit.text)))
	body.add_child(_rich("\n[b]Mondes sauvegardés[/b]"))
	if worlds.is_empty():
		body.add_child(_rich("Aucun."))
	for m in worlds:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s — an %d" % [m.name, int(m.year)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(_button("Continuer", main.continue_world.bind(m.id)))
		row.add_child(_button("Supprimer", main.delete_world.bind(m.id)))
		body.add_child(row)
	body.add_child(_rich("\n[b]Importer un fichier .cworld[/b] (dossier des exports du jeu)"))
	if exports.is_empty():
		body.add_child(_rich("Aucun fichier exporté."))
	for path in exports:
		body.add_child(_button(str(path).get_file(), main.import_world.bind(path)))
	body.add_child(_rich("\n[i]Partage en ligne : non connecté dans cette version.[/i]"))
	# Le menu principal ne se ferme pas : il faut choisir un monde.
	var close_btn: Button = modal.get_child(1).get_child(0).get_child(0).get_child(1)
	close_btn.visible = false
