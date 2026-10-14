class_name SpritePainter
extends RefCounted
## Koddan sprite çizmek için küçük bir piksel ressamı (UnitSprites'ın yardımcısı).
##
## Çalışma şekli: her beden parçası (kafa, gövde, bacak...) önce bir MASKEYE şekil olarak çizilir
## (elips, dikdörtgen, çokgen, kalın çizgi), sonra fill() ile bir renk rampasıyla boyanır.
## fill() ışığı sol üstten alır: maskenin kenarındaki pikselin "normali" komşu boşluklardan
## tahmin edilir; ışığa bakan kenar açık, öbür yan koyu, iç kısım ana renk olur. Böylece hazır
## CC0 sprite'lardaki gibi hacimli (düz değil) parçalar çıkar.
## Öne çizilen parça, altında kalan parçanın kendisine değen piksellerini koyulaştırır (iç kontur):
## kol gövdeden, kafa omuzdan ayrı okunur. Dış kontur en sonda outline() ile eklenir.
##
## Godot kavramları: Image (CPU tarafındaki piksel dizisi; set_pixel / get_pixel / blend_rect),
## PackedByteArray (maske: piksel başına 1 bayt, Array'den çok daha hafif).

const OUTLINE := Color("1c1612")
## Işık yönü (ekranda y aşağı): sol üstten, çoğunlukla yukarıdan.
const LIGHT := Vector2(-0.45, -0.89)

var size: int
var image: Image  ## Boyanan kare (dış kontur yok).
## Bütün şekil koordinatlarına eklenen kayma (gövdenin inip kalkması, öne eğilme).
var origin := Vector2.ZERO
var _mask := PackedByteArray()
## Maskenin dolu kısmını saran kutu (boyama sadece bu kutuda dolaşır: GDScript'te hız için).
var _lo := Vector2i.ZERO
var _hi := Vector2i.ZERO


func _init(p_size := 32) -> void:
	size = p_size
	image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	_mask.resize(size * size)
	begin()


## Yeni parça: maskeyi temizler.
func begin() -> SpritePainter:
	_mask.fill(0)
	_lo = Vector2i(size, size)
	_hi = Vector2i(-1, -1)
	return self


## Şeklin dolaşacağı aralığı kutuya ekler.
func _grow(x0: int, y0: int, x1: int, y1: int) -> void:
	_lo = Vector2i(mini(_lo.x, maxi(x0, 0)), mini(_lo.y, maxi(y0, 0)))
	_hi = Vector2i(maxi(_hi.x, mini(x1, size - 1)), maxi(_hi.y, mini(y1, size - 1)))


# --- Maske şekilleri (parçayı oluşturur) ---

func rect(x: float, y: float, w: float, h: float) -> SpritePainter:
	var x0 := roundi(x + origin.x)
	var y0 := roundi(y + origin.y)
	var x1 := x0 + roundi(w) - 1
	var y1 := y0 + roundi(h) - 1
	_grow(x0, y0, x1, y1)
	for yy in range(maxi(y0, 0), mini(y1 + 1, size)):
		for xx in range(maxi(x0, 0), mini(x1 + 1, size)):
			_mask[yy * size + xx] = 1
	return self


## Merkezi (cx, cy), yarıçapları rx, ry olan elips. Piksel merkezi içerdeyse dolu.
func ellipse(cx: float, cy: float, rx: float, ry: float) -> SpritePainter:
	cx += origin.x
	cy += origin.y
	var x0 := floori(cx - rx)
	var y0 := floori(cy - ry)
	var x1 := ceili(cx + rx)
	var y1 := ceili(cy + ry)
	_grow(x0, y0, x1, y1)
	for yy in range(maxi(y0, 0), mini(y1 + 1, size)):
		var dy := (yy + 0.5 - cy) / ry
		for xx in range(maxi(x0, 0), mini(x1 + 1, size)):
			var dx := (xx + 0.5 - cx) / rx
			if dx * dx + dy * dy <= 1.0:
				_mask[yy * size + xx] = 1
	return self


## Kalın çizgi (iki ucu yuvarlak). width 1 ise tek piksellik Bresenham çizgisi.
func line(a: Vector2, b: Vector2, width := 1.0) -> SpritePainter:
	a += origin
	b += origin
	if width <= 1.0:
		var ia := Vector2i(floori(a.x), floori(a.y))
		var ib := Vector2i(floori(b.x), floori(b.y))
		_grow(mini(ia.x, ib.x), mini(ia.y, ib.y), maxi(ia.x, ib.x), maxi(ia.y, ib.y))
		_bresenham(ia, ib)
		return self
	var r := width / 2.0
	var x0 := floori(minf(a.x, b.x) - r)
	var y0 := floori(minf(a.y, b.y) - r)
	var x1 := ceili(maxf(a.x, b.x) + r)
	var y1 := ceili(maxf(a.y, b.y) + r)
	_grow(x0, y0, x1, y1)
	var ab := b - a
	var len2 := ab.length_squared()
	for yy in range(maxi(y0, 0), mini(y1 + 1, size)):
		for xx in range(maxi(x0, 0), mini(x1 + 1, size)):
			var p := Vector2(xx + 0.5, yy + 0.5)
			var t := 0.0 if len2 == 0.0 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			if (a + ab * t).distance_squared_to(p) <= r * r:
				_mask[yy * size + xx] = 1
	return self


## İçbükey de olabilen çokgen (köşe noktaları sırayla).
func poly(points: PackedVector2Array) -> SpritePainter:
	var moved := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		var q := p + origin
		moved.append(q)
		lo = lo.min(q)
		hi = hi.max(q)
	var x0 := floori(lo.x)
	var y0 := floori(lo.y)
	var x1 := ceili(hi.x)
	var y1 := ceili(hi.y)
	_grow(x0, y0, x1, y1)
	for yy in range(maxi(y0, 0), mini(y1 + 1, size)):
		for xx in range(maxi(x0, 0), mini(x1 + 1, size)):
			if Geometry2D.is_point_in_polygon(Vector2(xx + 0.5, yy + 0.5), moved):
				_mask[yy * size + xx] = 1
	return self


## Maskeden dikdörtgen siler (şekle oyuk açmak için).
func cut(x: float, y: float, w: float, h: float) -> SpritePainter:
	var x0 := roundi(x + origin.x)
	var y0 := roundi(y + origin.y)
	for yy in range(maxi(y0, 0), mini(y0 + roundi(h), size)):
		for xx in range(maxi(x0, 0), mini(x0 + roundi(w), size)):
			_mask[yy * size + xx] = 0
	return self


func _bresenham(a: Vector2i, b: Vector2i) -> void:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while true:
		if p.x >= 0 and p.y >= 0 and p.x < size and p.y < size:
			_mask[p.y * size + p.x] = 1
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy


func _has(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size and _mask[y * size + x] == 1


# --- Boyama ---

## Maskeyi rampa ile boyar. ramp: [en koyu, gölge, ana, ışık] (bkz. ramp()).
## shade: false ise düz ana renk. sep: altta kalan parçalara iç kontur çizer.
func fill(ramp: Array, shade := true, sep := true) -> SpritePainter:
	if _hi.x < 0:
		return self
	if sep:
		_separate()
	for y in range(_lo.y, _hi.y + 1):
		for x in range(_lo.x, _hi.x + 1):
			if _mask[y * size + x] == 0:
				continue
			var c: Color = ramp[2]
			if shade:
				c = ramp[_tone(x, y)]
			image.set_pixel(x, y, c)
	return self


## Tek renkle düz boyar (parıltı, göz gibi gölgesiz parçalar).
func fill_color(color: Color, sep := false) -> SpritePainter:
	return fill([color, color, color, color], false, sep)


## Kenar pikselinin ışığa göre tonu: 3 ışık, 2 ana, 1 gölge.
func _tone(x: int, y: int) -> int:
	var n := Vector2.ZERO
	var edge := false
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if not _has(x + dx, y + dy):
				var w := 2.0 if absi(dx) <= 1 and absi(dy) <= 1 else 1.0
				n += Vector2(dx, dy) * w
				if absi(dx) + absi(dy) == 1:
					edge = true
	if n == Vector2.ZERO:
		return 2
	var lit := n.normalized().dot(LIGHT)
	if lit > 0.35 and edge:
		return 3
	if lit < -0.3:
		return 1
	return 2


## Bu parçanın değdiği, önceden boyanmış pikselleri koyulaştırır.
func _separate() -> void:
	for y in range(maxi(_lo.y - 1, 0), mini(_hi.y + 2, size)):
		for x in range(maxi(_lo.x - 1, 0), mini(_hi.x + 2, size)):
			if _mask[y * size + x] == 1:
				continue
			var c := image.get_pixel(x, y)
			if c.a == 0.0:
				continue
			if _has(x - 1, y) or _has(x + 1, y) or _has(x, y - 1) or _has(x, y + 1):
				image.set_pixel(x, y, c.darkened(0.35))



## Tek piksel (origin eklenir).
func px(x: float, y: float, color: Color) -> SpritePainter:
	var xx := roundi(x + origin.x)
	var yy := roundi(y + origin.y)
	if xx >= 0 and yy >= 0 and xx < size and yy < size:
		image.set_pixel(xx, yy, color)
	return self


## Boyalı bir pikselin rengini değiştirir (boşsa dokunmaz). Detay çizgileri için.
func tint(x: float, y: float, color: Color) -> SpritePainter:
	var xx := roundi(x + origin.x)
	var yy := roundi(y + origin.y)
	if xx >= 0 and yy >= 0 and xx < size and yy < size and image.get_pixel(xx, yy).a > 0.0:
		image.set_pixel(xx, yy, color)
	return self


# --- Rampa, kontur, döndürme (statik yardımcılar) ---

## Bir renkten 4 tonluk rampa: [en koyu, gölge, ana, ışık]. Piksel sanatındaki gibi gölgeler
## maviye/mora, ışıklar sarıya doğru kayar (sadece koyulaştırmaktan daha canlı durur).
static func ramp(base: Color) -> Array[Color]:
	var shadow := _shift(base, 0.68, 0.035, 0.12, 0.70)
	var darkest := _shift(base, 0.70, 0.06, 0.18, 0.46)
	var light := _shift(base, 0.14, 0.03, -0.12, 1.22)
	return [darkest, shadow, base, light]


static func _shift(c: Color, target_hue: float, amount: float, sat_add: float, val_mul: float) -> Color:
	var h := c.h
	var diff := wrapf(target_hue - h, -0.5, 0.5)
	h = fposmod(h + clampf(diff, -amount, amount), 1.0)
	var s := clampf(c.s + sat_add * c.s, 0.0, 1.0)
	var v := c.v * val_mul
	if v > 1.0:  # parlaklık tavana vurunca açıklık doygunluğu azaltarak gelir
		s = clampf(s - (v - 1.0), 0.0, 1.0)
		v = 1.0
	return Color.from_hsv(h, s, v, c.a)


## Saydam olup dolu bir komşusu (4 yön) olan her piksel kenar çizgisi olur.
static func outline(img: Image, color := OUTLINE) -> void:
	var source := img.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if source.get_pixel(x, y).a > 0.0:
				continue
			if (x > 0 and source.get_pixel(x - 1, y).a > 0.0) \
					or (x < w - 1 and source.get_pixel(x + 1, y).a > 0.0) \
					or (y > 0 and source.get_pixel(x, y - 1).a > 0.0) \
					or (y < h - 1 and source.get_pixel(x, y + 1).a > 0.0):
				img.set_pixel(x, y, color)


## Resmi pivot etrafında döndürür ve shift kadar kaydırır (en yakın komşu: pikseller bozulmaz).
## Pozitif açı ekranda saat yönünün tersine (baş sola/geriye) devirir.
static func rotated(src: Image, degrees: float, pivot: Vector2, shift := Vector2.ZERO) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var theta := deg_to_rad(degrees)
	var cos_t := cos(theta)
	var sin_t := sin(theta)
	for y in h:
		for x in w:
			# Hedef pikselden kaynağa geri dönülür (ters döndürme): sonuçta delik kalmaz.
			var d := Vector2(x + 0.5, y + 0.5) - pivot - shift
			var s := Vector2(d.x * cos_t - d.y * sin_t, d.x * sin_t + d.y * cos_t) + pivot
			var sx := floori(s.x)
			var sy := floori(s.y)
			if sx >= 0 and sy >= 0 and sx < w and sy < h:
				var c := src.get_pixel(sx, sy)
				if c.a > 0.0:
					out.set_pixel(x, y, c)
	return out


## Bir resmi ötekinin üstüne bindirir (saydam pikseller atlanır).
static func stamp(dst: Image, src: Image, at := Vector2i.ZERO) -> void:
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
