extends RefCounted
## Sauvegardes : plusieurs mondes, écriture atomique, versions + migrations, export/import, progression hors-ligne.

const World = preload("res://sim/world.gd")

const ROOT := "user://worlds"
const EXPORTS := "user://exports"
const EXT := ".cworld"

# Chaque migration transforme un dictionnaire de version n en version n+1.
static func _migrate_0_to_1(d: Dictionary) -> Dictionary:
	# v0 (prototype) : pas d'affinités Magie/Épée ni de compteur de naissances.
	d["birth_counter"] = int(d.get("birth_counter", 0))
	if not d.has("stats_births"):
		d["stats_births"] = {"divine_slots": 0, "divine_none": 0, "divine": {"magic": 0, "sword": 0, "both": 0},
			"natural_slots": 0, "natural": {"none": 0, "magic": 0, "sword": 0}, "late": {"magic": 0, "sword": 0, "both": 0}}
	d["affinity_history"] = d.get("affinity_history", [])
	for s in d.get("settlements", []):
		if not s.has("aff"):
			s["aff"] = {"none": float(s.get("pop", 0.0)), "magic": 0.0, "sword": 0.0, "both": 0.0}
		if not s.has("aff_src"):
			s["aff_src"] = {"magic": {}, "sword": {}, "both": {}}
		if not s.has("mastery"):
			s["mastery"] = {"magic": 0.0, "sword": 0.0}
		s["training"] = float(s.get("training", 0.0))
		s["military"] = float(s.get("military", 0.0))
		if not s.has("births"):
			s["births"] = d.stats_births.duplicate(true)
			for k in ["divine_slots", "divine_none", "natural_slots"]:
				s.births[k] = 0
	for dd in d.get("deities", []):
		dd["rules"] = dd.get("rules", [])
		dd["manual_orders"] = dd.get("manual_orders", [])
		dd["auto_budget"] = float(dd.get("auto_budget", 4.0))
		dd["auto_spent"] = 0.0
		dd["affinities_granted"] = int(dd.get("affinities_granted", 0))
		dd["next_rule_id"] = int(dd.get("next_rule_id", 1))
	d["version"] = 1
	return d

static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	if v > World.SAVE_VERSION:
		push_error("Sauvegarde plus récente que le jeu (v%d)" % v)
		return {}
	while v < World.SAVE_VERSION:
		match v:
			0: d = _migrate_0_to_1(d)
		v = int(d.version)
	return d

# ------------------------------------------------------------------ Fichiers

static func _write_compressed(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	if f == null:
		push_error("Écriture impossible : " + tmp)
		return false
	f.store_string(JSON.stringify(data, "", false, true))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK

static func _read_compressed(path: String) -> Dictionary:
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	return d if d is Dictionary else {}

static func world_dir(id: String) -> String:
	return ROOT + "/" + id

static func new_world_id() -> String:
	return "w%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 10000]

static func save_world(w, id: String) -> bool:
	DirAccess.make_dir_recursive_absolute(world_dir(id))
	w.last_saved_unix = int(Time.get_unix_time_from_system())
	var ok := _write_compressed(world_dir(id) + "/save" + EXT, w.to_dict())
	var meta := {"id": id, "name": w.world_name, "year": w.year, "saved": w.last_saved_unix,
		"player_people": w.peoples[0].name if w.peoples.size() > 0 else ""}
	var f := FileAccess.open(world_dir(id) + "/meta.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(meta))
		f.close()
	return ok

static func load_world(id: String):
	var d := _read_compressed(world_dir(id) + "/save" + EXT)
	if d.is_empty():
		return null
	return world_from_dict(d)

static func world_from_dict(d: Dictionary):
	d = migrate(d)
	if d.is_empty():
		return null
	var w = World.new()
	w.from_dict(d)
	return w

static func list_worlds() -> Array:
	var out := []
	var dir := DirAccess.open(ROOT)
	if dir == null:
		return out
	for sub in dir.get_directories():
		var txt := FileAccess.get_file_as_string(ROOT + "/" + sub + "/meta.json")
		var m = JSON.parse_string(txt) if txt != "" else null
		if m is Dictionary:
			out.append(m)
	out.sort_custom(func(a, b): return int(a.saved) > int(b.saved))
	return out

static func delete_world(id: String) -> void:
	var d := world_dir(id)
	for f in ["save" + EXT, "meta.json"]:
		if FileAccess.file_exists(d + "/" + f):
			DirAccess.remove_absolute(d + "/" + f)
	DirAccess.remove_absolute(d)

# ------------------------------------------------------------------ Export / import

## kind = "seed" : planète (graine + modifications) à découvrir, sans peuples.
## kind = "evolved" : monde complet déjà évolué.
static func export_world(w, kind: String) -> String:
	DirAccess.make_dir_recursive_absolute(EXPORTS)
	var data := {}
	if kind == "seed":
		data = {"version": World.SAVE_VERSION, "kind": "seed", "name": w.world_name, "planet": w.planet.to_dict()}
	else:
		data = w.to_dict()
		data["kind"] = "evolved"
	var safe: String = w.world_name.validate_filename().replace(" ", "_")
	var path := "%s/%s_%s_an%d%s" % [EXPORTS, safe, kind, w.year, EXT]
	return path if _write_compressed(path, data) else ""

## Copie d'un fichier quelconque (chemin ou adresse fournie par le sélecteur du système). Vrai si réussi.
static func copy_file(src: String, dest: String) -> bool:
	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		return false
	var data := f.get_buffer(f.get_length())
	f.close()
	var o := FileAccess.open(dest, FileAccess.WRITE)
	if o == null:
		return false
	o.store_buffer(data)
	o.close()
	return true

## Copie un fichier choisi sur l'appareil dans le dossier des exports du jeu ; renvoie le chemin local ou "".
static func copy_into_exports(src: String) -> String:
	DirAccess.make_dir_recursive_absolute(EXPORTS)
	var name := src.get_file().validate_filename()
	if not name.ends_with(EXT):
		name += EXT
	var dest := "%s/%s" % [EXPORTS, name]
	return dest if copy_file(src, dest) else ""

## Retourne {kind, world} (monde prêt) ou {error}.
static func import_file(path: String) -> Dictionary:
	var d := _read_compressed(path)
	if d.is_empty():
		return {"error": "Fichier illisible ou corrompu"}
	var kind := str(d.get("kind", "evolved"))
	if kind == "seed":
		if not d.has("planet"):
			return {"error": "Monde initial invalide"}
		var w = World.new()
		w.world_name = str(d.get("name", "Monde importé"))
		w.planet = load("res://sim/planet.gd").new()
		w.planet.from_dict(d.planet)
		w.world_seed = int(d.planet.seed)
		w.rng.seed = w.world_seed
		w.owner.resize(w.planet.cell_count)
		w.owner.fill(-1)
		return {"kind": "seed", "world": w}
	for k in ["planet", "peoples", "settlements", "deities", "religions"]:
		if not d.has(k):
			return {"error": "Champ manquant : " + k}
	var w2 = world_from_dict(d)
	if w2 == null:
		return {"error": "Version incompatible"}
	w2.offline_consumed_until = int(Time.get_unix_time_from_system())  # pas de rattrapage d'absence sur un import
	return {"kind": "evolved", "world": w2}

# ------------------------------------------------------------------ Absence

## Nombre d'années à simuler pour l'absence. Ne modifie rien.
static func offline_years(w, now_unix: int) -> Dictionary:
	var cfg: Dictionary = w.cat.config.offline
	var from := maxi(int(w.last_saved_unix), int(w.offline_consumed_until))
	if from <= 0:
		return {"years": 0, "clock_issue": false, "capped": false, "seconds": 0}
	var elapsed := now_unix - from
	if elapsed < 0:
		return {"years": 0, "clock_issue": true, "capped": false, "seconds": elapsed}
	var cap := int(float(cfg.max_hours) * 3600.0)
	var capped := elapsed > cap
	elapsed = mini(elapsed, cap)
	return {"years": int(elapsed / float(cfg.real_seconds_per_year)), "clock_issue": false, "capped": capped, "seconds": elapsed}

## Marque la période comme consommée AVANT la simulation (aucune double application possible).
static func consume_offline(w, now_unix: int) -> void:
	w.offline_consumed_until = maxi(int(w.offline_consumed_until), now_unix)

static func summary(w, before: Dictionary, after: Dictionary) -> Array:
	var lines := []
	lines.append("%d années se sont écoulées (an %d → an %d)." % [after.year - before.year, before.year, after.year])
	for p in w.peoples:
		var id = p.id
		var p0 := float(before.pops.get(id, 0.0))
		var p1 := float(after.pops.get(id, 0.0))
		if p0 == 0.0 and p1 == 0.0:
			continue
		lines.append("%s : %d → %d habitants, %d → %d établissements, %d découverte(s)." % [p.name, int(p0), int(p1),
			int(before.settlements.get(id, 0)), int(after.settlements.get(id, 0)), int(after.techs.get(id, 0)) - int(before.techs.get(id, 0))])
	var pd = w.player_deity
	lines.append("Vos fidèles : %d → %d. Énergie : %.1f → %.1f." % [int(before.believers.get(pd, 0.0)), int(after.believers.get(pd, 0.0)), float(before.energy), float(after.energy)])
	var b0: Dictionary = before.births
	var b1: Dictionary = after.births
	lines.append("Naissances : %d ouvertes à l'attribution divine, %d naturelles." % [int(b1.divine_slots) - int(b0.divine_slots), int(b1.natural_slots) - int(b0.natural_slots)])
	if after.wars > 0:
		lines.append("%d conflit(s) en cours." % after.wars)
	var start := int(before.log_index)
	var important := []
	for i in range(maxi(0, w.chronicle.size() - (int(after.log_index) - start)), w.chronicle.size()):
		var e: Dictionary = w.chronicle[i]
		if e.kind in ["tech", "war", "diplomacy", "faith", "disaster", "crisis", "settlement", "politics"]:
			important.append("An %d — %s (%s)" % [int(e.y), e.txt, e.why])
	for l in important.slice(maxi(0, important.size() - 12)):
		lines.append(l)
	return lines
