class_name SpritePalette
## Koddan üretilen sprite'ların ortak paleti: Resurrect 64 (Kerrie Lake, Lospec).
## Sanat yönü "tutarlı piksel" (gorsel_yon_dokumani.md Seçenek A): bütün figürler tek paletten.
## Rampalar bu paletten seçilir (SpritePainter.ramp) ve sayfa en sonda bu palete indirgenir
## (quantize). Kontur rengi (#1c1612) paletin dışında bırakılır: belgede ayrıca belirlendi.

const HEX: PackedStringArray = [
	"2e222f", "3e3546", "625565", "966c6c", "ab947a", "694f62", "7f708a", "9babb2",
	"c7dcd0", "ffffff", "6e2727", "b33831", "ea4f36", "f57d4a", "ae2334", "e83b3b",
	"fb6b1d", "f79617", "f9c22b", "7a3045", "9e4539", "cd683d", "e6904e", "fbb954",
	"4c3e24", "676633", "a2a947", "d5e04b", "fbff86", "165a4c", "239063", "1ebc73",
	"91db69", "cddf6c", "313638", "374e4a", "547e64", "92a984", "b2ba90", "0b5e65",
	"0b8a8f", "0eaf9b", "30e1b9", "8ff8e2", "323353", "484a77", "4d65b4", "4d9be6",
	"8fd3ff", "45293f", "6b3e75", "905ea9", "a884f3", "eaaded", "753c54", "a24b6f",
	"cf657f", "ed8099", "831c5d", "c32454", "f04f78", "f68181", "fca790", "fdcbb0",
]

static var _colors: Array[Color] = []
static var _cache := {}  ## Color -> en yakın palet rengi


static func colors() -> Array[Color]:
	if _colors.is_empty():
		for h in HEX:
			_colors.append(Color(h))
	return _colors


## Algıya yakın renk farkı (yeşile duyarlı ağırlıklı RGB).
static func distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	var rm := (a.r + b.r) * 0.5
	return (2.0 + rm) * dr * dr + 4.0 * dg * dg + (3.0 - rm) * db * db


static func luma(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


## Paletteki en yakın renk (saydamlık korunur).
static func nearest(c: Color) -> Color:
	var key := Color(c.r, c.g, c.b)
	if _cache.has(key):
		var hit: Color = _cache[key]
		return Color(hit.r, hit.g, hit.b, c.a)
	var best := key
	var best_d := INF
	for p in colors():
		var d := distance(key, p)
		if d < best_d:
			best_d = d
			best = p
	_cache[key] = best
	return Color(best.r, best.g, best.b, c.a)


## Hedefe en yakın, `ref`'ten belirgin biçimde açık (lighter = true) ya da koyu palet rengi.
## Rampanın tonları palete oturunca birbirine karışmasın diye.
static func nearest_step(target: Color, ref: Color, lighter: bool) -> Color:
	var best := Color()
	var best_d := INF
	var ref_l := luma(ref)
	for p in colors():
		var l := luma(p)
		if lighter and (l <= ref_l + 0.04 or l > ref_l + 0.32):
			continue  # çok uzak (ör. ten rengine sarı ışık) adım seçilmesin
		if not lighter and (l >= ref_l - 0.04 or l < ref_l - 0.4):
			continue
		var d := distance(target, p)
		if d < best_d:
			best_d = d
			best = p
	if best_d == INF:  # daha açık / koyu renk kalmadı
		return ref
	return best


## Resmi palete indirger. keep: dokunulmayacak renk (kontur).
static func quantize(img: Image, keep := SpritePainter.OUTLINE) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0 or c.is_equal_approx(keep):
				continue
			img.set_pixel(x, y, nearest(c))
