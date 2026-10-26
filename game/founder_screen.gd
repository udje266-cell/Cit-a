extends PanelContainer
## Création du peuple du joueur : espèce, nom, divinité, deux fondateurs (traits + don d'affinité facultatif).

signal confirmed(species_id: String, people_name: String, deity_name: String, founders: Array)

const Affinity = preload("res://sim/affinity.gd")
const Genetics = preload("res://sim/genetics.gd")
const POINTS := 10

var cat
var energy_available := 15.0
var species_id := ""
var founders := [{"name": "", "traits": [], "affinity": "none"}, {"name": "", "traits": [], "affinity": "none"}]
var _species_desc: RichTextLabel
var _people_name: LineEdit
var _deity_name: LineEdit
var _tabs: TabContainer
var _points_labels := []
var _checks := [{}, {}]
var _name_edits := []
var _aff_options := []
var _energy_label: Label
var _rng := RandomNumberGenerator.new()

func build(p_cat, initial_energy: float) -> void:
	cat = p_cat
	energy_available = initial_energy
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.1, 0.92)
	add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var title := Label.new()
	title.text = "Créez votre peuple"
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)
	# Colonne espèces
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 330
	cols.add_child(left)
	var sl := Label.new(); sl.text = "Espèce"; left.add_child(sl)
	var group := ButtonGroup.new()
	for id in cat.species_order:
		var b := Button.new()
		b.text = cat.species[id].name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size.y = 52
		b.pressed.connect(_select_species.bind(id))
		left.add_child(b)
		if species_id == "":
			species_id = id
			b.button_pressed = true
	_species_desc = RichTextLabel.new()
	_species_desc.bbcode_enabled = true
	_species_desc.fit_content = true
	_species_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_species_desc)
	# Colonne fondateurs
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var names := HBoxContainer.new()
	mid.add_child(names)
	_people_name = LineEdit.new(); _people_name.placeholder_text = "Nom du peuple"; _people_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deity_name = LineEdit.new(); _deity_name.placeholder_text = "Votre nom divin"; _deity_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(_people_name); names.add_child(_deity_name)
	_energy_label = Label.new()
	mid.add_child(_energy_label)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(_tabs)
	for f in 2:
		_tabs.add_child(_founder_tab(f))
		_tabs.set_tab_title(f, "Fondateur %d" % (f + 1))
	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	var rnd := Button.new(); rnd.text = "Traits au hasard"; rnd.custom_minimum_size = Vector2(220, 56)
	rnd.pressed.connect(_randomize)
	bottom.add_child(rnd)
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var ok := Button.new(); ok.text = "Créer le peuple ▶"; ok.custom_minimum_size = Vector2(260, 56)
	ok.pressed.connect(_confirm)
	bottom.add_child(ok)
	_select_species(species_id)
	_randomize_names()

func _founder_tab(f: int) -> Control:
	var v := VBoxContainer.new()
	v.name = "F%d" % f
	var h := HBoxContainer.new()
	v.add_child(h)
	var ne := LineEdit.new(); ne.placeholder_text = "Nom"; ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_changed.connect(func(t): founders[f].name = t)
	h.add_child(ne)
	_name_edits.append(ne)
	var ao := OptionButton.new()
	for a in Affinity.ALL:
		ao.add_item(Affinity.NAMES[a] + ("" if a == "none" else " (don divin : %.1f énergie)" % float(cat.config.affinity.cost[a])))
	ao.item_selected.connect(_on_affinity.bind(f))
	h.add_child(ao)
	_aff_options.append(ao)
	var pl := Label.new()
	v.add_child(pl)
	_points_labels.append(pl)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for catid in cat.trait_categories:
		var header := Label.new()
		header.text = "— " + cat.trait_categories[catid] + " —"
		header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		list.add_child(header)
		for tid in cat.trait_order:
			var t: Dictionary = cat.traits[tid]
			if t.cat != catid:
				continue
			var cb := CheckBox.new()
			var cost := int(t.cost)
			var kind := "" if t.kind == "heritable" else " [acquis : culture]"
			var price := ("coût %d" % cost) if cost >= 0 else ("rend %d" % -cost)
			cb.text = "%s (%s) — %s%s" % [t.name, price, t.desc, kind]
			cb.tooltip_text = _fx_text(t)
			cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cb.toggled.connect(_on_trait.bind(f, tid))
			list.add_child(cb)
			_checks[f][tid] = cb
	return v

func _on_affinity(idx: int, f: int) -> void:
	founders[f].affinity = Affinity.ALL[idx]
	_update_labels()

func _fx_text(t: Dictionary) -> String:
	var parts := []
	for s in t.fx:
		parts.append("%s %+.2f" % [s, float(t.fx[s])])
	var txt := "Effets : " + ", ".join(parts)
	if not t.incompat.is_empty():
		txt += "\nIncompatible avec : " + ", ".join(t.incompat.map(func(x): return cat.traits[x].name))
	return txt

func _points_used(f: int) -> int:
	var p := 0
	for tid in founders[f].traits:
		p += int(cat.traits[tid].cost)
	return p

func _on_trait(on: bool, f: int, tid: String) -> void:
	var list: Array = founders[f].traits
	if on and not tid in list:
		if _points_used(f) + int(cat.traits[tid].cost) > POINTS:
			_checks[f][tid].set_pressed_no_signal(false)
			_flash(f, "Points insuffisants")
			return
		for o in cat.traits[tid].incompat:
			if o in list:
				list.erase(o)
				_checks[f][o].set_pressed_no_signal(false)
		list.append(tid)
	elif not on:
		list.erase(tid)
	_update_labels()

func _flash(f: int, msg: String) -> void:
	_points_labels[f].text = msg

func _update_labels() -> void:
	for f in 2:
		_points_labels[f].text = "Points utilisés : %d / %d   ·   %d trait(s)" % [_points_used(f), POINTS, founders[f].traits.size()]
	var spent := _affinity_cost()
	_energy_label.text = "Énergie divine initiale : %.1f — dons d'affinité aux fondateurs : %.1f" % [energy_available, spent]
	_energy_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if spent > energy_available else Color(0.8, 0.9, 1))

func _affinity_cost() -> float:
	var c := 0.0
	for f in founders:
		if f.affinity != "none":
			c += float(cat.config.affinity.cost[f.affinity])
	return c

func _select_species(id: String) -> void:
	species_id = id
	var s: Dictionary = cat.species[id]
	var hab: Array = s.habitat.keys()
	hab.sort_custom(func(a, b): return float(s.habitat[a]) > float(s.habitat[b]))
	_species_desc.text = "[b]%s[/b]\n%s\n\nLongévité : %d ans · génération : %d ans\nCroissance : %.1f %%/an · potentiel magique ×%.1f\nMilieux favoris : %s" % [
		s.name, s.desc, int(s.longevity), int(s.generation_years), float(s.growth) * 100.0, float(s.magic_potential),
		", ".join(hab.slice(0, 3).map(func(b): return preload("res://sim/planet.gd").BIOME_NAMES.get(b, b)))]
	_randomize_names()

func _randomize_names() -> void:
	if _name_edits.size() < 2:
		return
	for f in 2:
		founders[f].name = Genetics.make_name(_rng, species_id)
		_name_edits[f].text = founders[f].name
	if _people_name.text == "":
		_people_name.placeholder_text = "Nom du peuple (ex. %s)" % Genetics.make_name(_rng, species_id)

func _randomize() -> void:
	for f in 2:
		for tid in founders[f].traits.duplicate():
			_checks[f][tid].button_pressed = false
		var tries := 0
		while _points_used(f) < POINTS - 1 and tries < 60:
			tries += 1
			var tid: String = cat.trait_order[_rng.randi_range(0, cat.trait_order.size() - 1)]
			if not tid in founders[f].traits:
				_checks[f][tid].button_pressed = true
	_update_labels()

func _confirm() -> void:
	if _affinity_cost() > energy_available:
		_energy_label.text = "Énergie insuffisante pour ces dons d'affinité."
		return
	var pname := _people_name.text.strip_edges()
	if pname == "":
		pname = Genetics.make_name(_rng, species_id)
	var dname := _deity_name.text.strip_edges()
	if dname == "":
		dname = "L'Éveillé"
	for f in 2:
		if founders[f].name.strip_edges() == "":
			founders[f].name = Genetics.make_name(_rng, species_id)
	confirmed.emit(species_id, pname, dname, founders.duplicate(true))
