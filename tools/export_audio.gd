extends SceneTree
## Écoute hors du jeu : godot --headless --path . -s tools/export_audio.gd -- <dossier> (musique_paix.wav, musique_tension.wav, effets.wav)
func _init():
	var Audio = load("res://game/audio.gd")
	var a = Audio.new()
	var out: String = OS.get_cmdline_user_args()[0]
	for m in ["paix", "tension"]:
		a._wav(Audio.make_loop(m, 24.0), false).save_to_wav(out + "/musique_%s.wav" % m)
	var all := PackedFloat32Array()
	for k in ["tap", "open", "error", "rumble", "whoosh", "bloom", "chime", "magic", "war"]:
		all.append_array(Audio._synth(k))
		var gap := PackedFloat32Array(); gap.resize(Audio.RATE / 3)
		all.append_array(gap)
	a._wav(all).save_to_wav(out + "/effets.wav")
	a.free()
	quit()
