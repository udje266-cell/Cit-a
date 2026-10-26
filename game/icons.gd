extends RefCounted
## Icônes vectorielles (SVG intégré, rendu en texture). Aucune dépendance aux glyphes de la police,
## dont la couverture varie selon les téléphones.

const SIZE := 30
const PATHS := {
	"pause": "<rect x='6' y='4' width='4' height='16' rx='1'/><rect x='14' y='4' width='4' height='16' rx='1'/>",
	"play": "<path d='M7 4l13 8-13 8z'/>",
	"ff2": "<path d='M3 5l9 7-9 7zM12 5l9 7-9 7z'/>",
	"ff3": "<path d='M1 6l7 6-7 6zM8.5 6l7 6-7 6zM16 6l7 6-7 6z'/>",
	"star": "<path d='M12 2l2.6 6.4L21 9l-5 4.4 1.6 6.6L12 16.5 6.4 20 8 13.4 3 9l6.4-.6z'/>",
	"flame": "<path d='M12 2c1 4 6 6.5 6 12a6 6 0 0 1-12 0c0-3 1.6-5 3-7 .2 2.4 1.2 3.6 2.4 4C11 8 10.4 5 12 2z'/>",
	"people": "<circle cx='8' cy='7' r='3.2'/><circle cx='16.5' cy='8' r='2.8'/><path d='M2 20c0-4 2.7-7 6-7s6 3 6 7zM13 20c0-2 .3-3.6 1.2-5 .7-.4 1.5-.6 2.3-.6 3 0 5.5 2.6 5.5 5.6z'/>",
	"person": "<circle cx='12' cy='7' r='4'/><path d='M4 21c0-4.4 3.6-8 8-8s8 3.6 8 8z'/>",
	"sword": "<path d='M20 2l-1 5-9.5 9.5-2-2L17 5zM5 13.5l5.5 5.5-1.5 1.5-1.8-1.8L4.5 21.5 2.5 19.5l2.8-2.7-1.8-1.8z'/>",
	"book": "<path d='M4 3h7c1 0 1 1 1 1v17c0-1-1-2-2-2H4zM20 3h-7c-1 0-1 1-1 1v17c0-1 1-2 2-2h6z'/>",
	"globe": "<circle cx='12' cy='12' r='9' fill='none' stroke='white' stroke-width='2'/><path d='M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18' fill='none' stroke='white' stroke-width='1.8'/>",
	"menu": "<rect x='3' y='5' width='18' height='2.6' rx='1'/><rect x='3' y='10.7' width='18' height='2.6' rx='1'/><rect x='3' y='16.4' width='18' height='2.6' rx='1'/>",
	"bolt": "<path d='M13 2L4 14h6.5L9 22l10-13h-6.5z'/>",
	"hourglass": "<path d='M6 2h12v2c0 4-4 6-4 8s4 4 4 8v2H6v-2c0-4 4-6 4-8S6 8 6 4zM8.5 20h7c0-2.5-3.5-4-3.5-6 0 2-3.5 3.5-3.5 6z'/>",
	"close": "<path d='M5 7l2-2 5 5 5-5 2 2-5 5 5 5-2 2-5-5-5 5-2-2 5-5z'/>",
	"lock": "<rect x='5' y='10' width='14' height='11' rx='2'/><path d='M8 10V7a4 4 0 0 1 8 0v3' fill='none' stroke='white' stroke-width='2.4'/>",
	"mountain": "<path d='M2 20l7-12 4 6 3-4 6 10z'/>",
	"cloud": "<path d='M7 19a5 5 0 0 1-.6-10A6 6 0 0 1 18 8.5a4.5 4.5 0 0 1-.5 10.5z'/>",
	"leaf": "<path d='M20 3C9 3 4 8 4 15c0 2 .6 4 1.6 5.6C7 15 11 11 16 9c-4 3-7.5 6.5-9 12.5C17 21 20 14 20 3z'/>",
	"heart": "<path d='M12 21C5 15.5 2 12 2 8a5 5 0 0 1 10-1 5 5 0 0 1 10 1c0 4-3 7.5-10 13z'/>",
	"dna": "<path d='M7 2c0 6 10 8 10 14v6M17 2c0 6-10 8-10 14v6M8 6h8M8 18h8M9.5 12h5' fill='none' stroke='white' stroke-width='2.2'/>",
	"cross": "<path d='M9 3h6v6h6v6h-6v6H9v-6H3V9h6z'/>",
	"sun": "<circle cx='12' cy='12' r='5'/><path d='M12 1v4M12 19v4M1 12h4M19 12h4M4.2 4.2l2.8 2.8M17 17l2.8 2.8M4.2 19.8L7 17M17 7l2.8-2.8' stroke='white' stroke-width='2.2'/>",
	"bulb": "<path d='M12 2a7 7 0 0 0-4 12.7V18h8v-3.3A7 7 0 0 0 12 2zM9 20h6v2H9z'/>",
	"eye": "<path d='M12 5C6 5 2 12 2 12s4 7 10 7 10-7 10-7-4-7-10-7z'/><circle cx='12' cy='12' r='3.5' fill='#222'/>",
}

static var _cache := {}

static func get_icon(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='white'>%s</svg>" % PATHS.get(name, PATHS.star)
	var img := Image.new()
	img.load_svg_from_string(svg, float(SIZE) / 24.0)
	var tex := ImageTexture.create_from_image(img)
	_cache[name] = tex
	return tex
