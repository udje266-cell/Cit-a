extends Node
## Son et musique entièrement procéduraux (aucun fichier audio) :
## - effets synthétisés une fois au démarrage (sinusoïdes, bruit filtré, enveloppes) ;
## - deux boucles musicales générées en arrière-plan (paix : pentatonique majeure ; tension : mineure, plus grave),
##   enchaînées en fondu selon l'état du peuple du joueur (en guerre ou non) ;
## - bus « Musique » et « Effets », volumes réglables et mémorisés (user://settings.cfg).

const RATE := 22050
const SETTINGS := "user://settings.cfg"
const LOOP_SECONDS := 24.0
## Famille de pouvoir -> son.
const FAMILY_SOUND := {"terrain": "rumble", "catastrophe": "rumble", "climate": "whoosh", "vegetation": "bloom",
	"life": "bloom", "evolution": "magic", "affinity": "magic", "healing": "chime", "blessing": "chime",
	"inspiration": "chime", "sign": "chime"}

var music_db := -10.0
var sfx_db := -4.0
var muted := false
var mood := "paix"
var _sfx := {}
var _players: Array = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _loops := {}
var _task := -1
var _pending := {}
var _mutex := Mutex.new()

func _ready() -> void:
	_ensure_bus("Musique")
	_ensure_bus("Effets")
	_load_settings()
	for k in ["tap", "open", "error", "rumble", "whoosh", "bloom", "chime", "magic", "war"]:
		_sfx[k] = _wav(_synth(k))
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "Effets"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Musique"
		m.volume_db = -60.0
		add_child(m)
	# Les boucles musicales sont longues à calculer : fil secondaire.
	_task = WorkerThreadPool.add_task(_generate_loops)

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")

func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Musique"), music_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Effets"), sfx_db)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		music_db = float(c.get_value("audio", "music_db", music_db))
		sfx_db = float(c.get_value("audio", "sfx_db", sfx_db))
		muted = bool(c.get_value("audio", "muted", muted))
	_apply_volumes()

func save_settings() -> void:
	_apply_volumes()
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("audio", "music_db", music_db)
	c.set_value("audio", "sfx_db", sfx_db)
	c.set_value("audio", "muted", muted)
	c.save(SETTINGS)

# ------------------------------------------------------------------ Lecture

func play(kind: String, pitch: float = 1.0) -> void:
	if not _sfx.has(kind):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sfx[kind]
			p.pitch_scale = pitch
			p.play()
			return

func play_power(family: String) -> void:
	play(FAMILY_SOUND.get(family, "chime"))

func set_mood(m: String) -> void:
	if m == mood and (_music_a.playing or _music_b.playing):
		return
	mood = m
	if not _loops.has(m):
		return
	# Fondu enchaîné : le lecteur silencieux prend la nouvelle boucle.
	var from := _music_a if _music_a.volume_db > _music_b.volume_db else _music_b
	var to := _music_b if from == _music_a else _music_a
	to.stream = _loops[m]
	to.volume_db = -40.0
	to.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(to, "volume_db", 0.0, 3.0)
	tw.tween_property(from, "volume_db", -60.0, 3.0)

func loops_ready() -> bool:
	return _loops.size() == 2

func _process(_delta: float) -> void:
	if _pending.is_empty():
		return
	_mutex.lock()
	for k in _pending:
		_loops[k] = _wav(_pending[k], true)
	_pending.clear()
	_mutex.unlock()
	if loops_ready():
		if _task >= 0:
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
		var m := mood
		mood = ""
		set_mood(m)

# ------------------------------------------------------------------ Synthèse

func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

static func _env(t: float, attack: float, decay: float) -> float:
	return minf(t / maxf(attack, 0.0001), 1.0) * exp(-t / decay)

static func _synth(kind: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var dur: float = {"tap": 0.08, "open": 0.18, "error": 0.25, "rumble": 1.4, "whoosh": 1.2, "bloom": 1.0, "chime": 1.6, "magic": 1.3, "war": 0.9}[kind]
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		match kind:
			"tap":
				v = sin(TAU * 880.0 * t) * _env(t, 0.002, 0.02) * 0.35
			"open":
				var f := 520.0 if t < 0.07 else 780.0
				v = sin(TAU * f * t) * _env(fmod(t, 0.07), 0.003, 0.04) * 0.3
			"error":
				v = (sin(TAU * 150.0 * t) + 0.5 * sin(TAU * 225.0 * t)) * _env(t, 0.005, 0.12) * 0.3
			"rumble":
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
				v = (lp * 3.0 + sin(TAU * 48.0 * t) * 0.5) * _env(t, 0.08, 0.5) * 0.6
			"whoosh":
				var cut := 0.02 + 0.2 * sin(PI * t / dur)
				lp += (rng.randf_range(-1.0, 1.0) - lp) * cut
				v = lp * sin(PI * t / dur) * 0.9
			"bloom":
				# Arpège pentatonique ascendant.
				var notes := [523.25, 587.33, 659.25, 783.99, 880.0]
				var k := mini(int(t / 0.12), notes.size() - 1)
				var tt := t - k * 0.12
				v = (sin(TAU * notes[k] * t) + 0.3 * sin(TAU * notes[k] * 2.0 * t)) * _env(tt, 0.005, 0.25) * 0.28
			"chime":
				for p in [[1.0, 1.0], [2.76, 0.5], [5.4, 0.25], [8.93, 0.12]]:
					v += sin(TAU * 660.0 * p[0] * t) * p[1] * exp(-t * (1.2 + p[0] * 0.6))
				v *= minf(t / 0.003, 1.0) * 0.25
			"magic":
				var mod := sin(TAU * 7.0 * t) * 40.0 + sin(TAU * 0.8 * t) * 200.0
				v = sin(TAU * (740.0 + mod) * t) * _env(t, 0.1, 0.5) * 0.22 + sin(TAU * 1480.0 * t) * _env(t, 0.2, 0.4) * 0.06
			"war":
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.1
				for hit in [0.0, 0.3, 0.45]:
					if t >= hit:
						v += (sin(TAU * 70.0 * (t - hit)) + lp) * exp(-(t - hit) * 12.0) * 0.45
		out[i] = v
	return out

## Boucle d'ambiance : nappe d'accords lents et notes pincées, tirées d'une gamme pentatonique (graine fixe).
static func make_loop(mood_name: String, seconds: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 if mood_name == "paix" else 4321
	var minor := mood_name != "paix"
	var root := 196.0 if not minor else 164.81            # sol / mi
	var scale: Array = [0, 2, 4, 7, 9] if not minor else [0, 3, 5, 7, 10]
	var chords: Array = [[0, 4, 7], [-3, 0, 4], [5, 9, 12], [7, 11, 14]] if not minor else [[0, 3, 7], [-4, 0, 3], [5, 8, 12], [-2, 2, 5]]
	var n := int(RATE * seconds)
	var out := PackedFloat32Array()
	out.resize(n)
	var bar := seconds / chords.size()
	# Mélodie : une note toutes les 1,5 s (paix) ou 2 s (tension), parfois un silence.
	var step := 1.5 if not minor else 2.0
	var mel := []
	var tt := 0.5
	while tt < seconds - 1.0:
		if rng.randf() < 0.75:
			var deg: int = scale[rng.randi_range(0, scale.size() - 1)] + 12 * rng.randi_range(1, 2)
			mel.append([tt, root * pow(2.0, deg / 12.0)])
		tt += step
	for i in n:
		var t := float(i) / RATE
		var ci := mini(int(t / bar), chords.size() - 1)
		var tb := t - ci * bar
		# Fondu d'accord à accord, raccord parfait en fin de boucle.
		var fade := clampf(tb / 1.2, 0.0, 1.0) * clampf((bar - tb) / 1.2, 0.0, 1.0)
		var v := 0.0
		for semi in chords[ci]:
			var f: float = root * pow(2.0, float(semi) / 12.0)
			v += sin(TAU * f * t) * 0.09 + sin(TAU * f * 2.003 * t) * 0.025
		v *= 0.35 + 0.65 * fade
		for m in mel:
			var dt: float = t - float(m[0])
			if dt >= 0.0 and dt < 2.5:
				v += sin(TAU * float(m[1]) * t) * exp(-dt * 1.8) * minf(dt / 0.01, 1.0) * 0.16
		out[i] = v * 0.8
	return out

func _generate_loops() -> void:
	for m in ["paix", "tension"]:
		var data := make_loop(m, LOOP_SECONDS)
		_mutex.lock()
		_pending[m] = data
		_mutex.unlock()
