extends Control
## Graphique en lignes minimal : plusieurs séries alignées sur un axe des années commun.
## series : [{name, color, start (indice dans years), v: Array}]

var years: Array = []
var series: Array = []
var y_max := 0.0
var percent := false

func setup(p_years: Array, p_series: Array, p_percent: bool = false) -> void:
	years = p_years
	series = p_series
	percent = p_percent
	y_max = 0.02 if percent else 0.0
	for s in series:
		for v in s.v:
			y_max = maxf(y_max, float(v))
	custom_minimum_size = Vector2(0, 170)
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var fs := 12
	var r := Rect2(Vector2(42, 8), size - Vector2(50, 40))
	draw_rect(r, Color(1, 1, 1, 0.05))
	draw_rect(r, Color(1, 1, 1, 0.25), false)
	if years.size() < 2:
		draw_string(font, r.position + Vector2(8, 20), "Pas encore assez d'années enregistrées.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		return
	var ym := maxf(y_max, 0.001)
	draw_string(font, Vector2(0, r.position.y + 10), ("%.0f %%" % (ym * 100.0)) if percent else str(int(ym)), HORIZONTAL_ALIGNMENT_LEFT, 40, fs)
	draw_string(font, Vector2(0, r.end.y), "0", HORIZONTAL_ALIGNMENT_LEFT, 40, fs)
	draw_string(font, Vector2(r.position.x, r.end.y + 14), "an %d" % int(years[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2(r.end.x - 60, r.end.y + 14), "an %d" % int(years[years.size() - 1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var n := years.size() - 1
	var lx := r.position.x
	for s in series:
		var pts := PackedVector2Array()
		for i in s.v.size():
			var idx: int = int(s.start) + i
			pts.append(Vector2(r.position.x + r.size.x * float(idx) / n, r.end.y - r.size.y * float(s.v[i]) / ym))
		if pts.size() >= 2:
			draw_polyline(pts, s.color, 2.0, true)
		# Légende sous l'axe.
		draw_rect(Rect2(Vector2(lx, r.end.y + 20), Vector2(10, 10)), s.color)
		draw_string(font, Vector2(lx + 13, r.end.y + 30), str(s.name), HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		lx += 18 + font.get_string_size(str(s.name), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10
