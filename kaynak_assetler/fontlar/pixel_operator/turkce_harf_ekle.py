"""Pixel Operator (CC0) fontlarına eksik Türkçe harfleri ekler: Ğ ğ İ Ş ş.

Fontta parçalar var ama birleşik harfler yok. Yeni harfler mevcut konturların kopyasıyla,
piksel hizalı olarak kurulur:
  Ğ = G + Ŭ'nun breve'si (aynı yükseklikte)      ğ = g + ŭ'nun breve'si
  İ = I + i'nin noktası (büyük harf boyuna kaydırılır)
  Ş = S + Ç'nin cedilla'sı                        ş = s + ç'nin cedilla'sı
Çıktı: Fetih/assets/fonts/<aynı ad>.ttf

Çalıştırma (repo kökünden): uvx --from fonttools python -I kaynak_assetler/fontlar/pixel_operator/turkce_harf_ekle.py
"""
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import Glyph, GlyphCoordinates

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[2] / "Fetih" / "assets" / "fonts"
## Bold yüzlerde harf ve aksan tek kontur (ayrılamıyor); oyunda kullanılmıyor.
FONTS = ["PixelOperator.ttf", "PixelOperator8.ttf"]


def contours(font, name):
    """Glifin konturları: her biri [(x, y, on_curve), ...]."""
    glyf = font["glyf"]
    g = glyf[name]
    coords, ends, flags = g.getCoordinates(glyf)
    out, start = [], 0
    for end in ends:
        out.append([(coords[i][0], coords[i][1], flags[i] & 1) for i in range(start, end + 1)])
        start = end + 1
    return out


def bbox(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def accent_part(font, accented, base, above=True):
    """Aksanlı glifte taban harfte olmayan konturlar (aksan). above: taban harfin üstünde mi altında mı."""
    _, _, _, base_top = bbox([p for c in contours(font, base) for p in c])
    result = []
    for c in contours(font, accented):
        _, ymin, _, ymax = bbox(c)
        if above and ymin >= base_top:
            result.append(c)
        elif not above and ymax <= 0:
            result.append(c)
    return result


def shift(cs, dx, dy):
    return [[(x + dx, y + dy, on) for x, y, on in c] for c in cs]


def make_glyph(cs):
    g = Glyph()
    pts, flags, ends = [], [], []
    for c in cs:
        for x, y, on in c:
            pts.append((x, y))
            flags.append(1 if on else 0)
        ends.append(len(pts) - 1)
    g.coordinates = GlyphCoordinates(pts)
    g.flags = bytearray(flags)
    g.endPtsOfContours = ends
    g.numberOfContours = len(ends)
    g.program = None
    from fontTools.ttLib.tables import ttProgram
    g.program = ttProgram.Program()
    g.program.fromBytecode(b"")
    return g


def add(font, name, codepoint, cs, advance_from):
    glyf = font["glyf"]
    g = make_glyph(cs)
    glyf.glyphs[name] = g
    order = font.getGlyphOrder()
    if name not in order:
        order.append(name)
        font.setGlyphOrder(order)
    g.recalcBounds(glyf)
    font["hmtx"][name] = (font["hmtx"][advance_from][0], g.xMin)
    for table in font["cmap"].tables:
        if table.isUnicode():
            table.cmap[codepoint] = name


def build(path_in, path_out):
    font = TTFont(path_in)
    upem = font["head"].unitsPerEm
    cmap = font.getBestCmap()
    name_of = lambda cp: cmap[cp]
    G, g, I, i, S, s = (name_of(ord(ch)) for ch in "GgIiSs")
    # Breve: Ŭ / ŭ içindeki yerinde (taban harflerin boyları aynı: U ile G, u ile g'nin üstü).
    breve_up = accent_part(font, name_of(0x16C), name_of(ord("U")))
    breve_lo = accent_part(font, name_of(0x16D), name_of(ord("u")))
    cedilla_up = accent_part(font, name_of(0xC7), name_of(ord("C")), above=False)
    cedilla_lo = accent_part(font, name_of(0xE7), name_of(ord("c")), above=False)
    # i'nin noktası: x-yüksekliğinin üstündeki kontur; İ için büyük harf boyu kadar yukarı.
    _, _, _, x_height = bbox([p for c in contours(font, name_of(0x131)) for p in c])  # ı
    _, _, _, cap = bbox([p for c in contours(font, I) for p in c])
    dot = accent_part(font, i, name_of(0x131))
    dot_up = shift(dot, 0, cap - x_height)
    px = upem // 16 if upem >= 1600 else upem // 8
    if not breve_up:
        # PixelOperator8: Ŭ'da U küçültülmüş, büyük harf breve'si yok. ŭ'nun breve'si G'nin 1 piksel üstüne.
        _, _, _, g_top = bbox([p for c in contours(font, G) for p in c])
        _, lo_bottom, _, _ = bbox([p for c in breve_lo for p in c])
        breve_up = shift(breve_lo, 0, g_top + px - lo_bottom)
    # Aksan ile harf yatayda aynı hücrede (Ŭ ile G, Ç ile S genişlikleri aynı); farkı ortala.
    def centered(acc, src_base, dst_base):
        sx0, _, sx1, _ = bbox([p for c in contours(font, src_base) for p in c])
        dx0, _, dx1, _ = bbox([p for c in contours(font, dst_base) for p in c])
        dx = round(((dx0 + dx1) - (sx0 + sx1)) / 2 / px) * px  # piksel hizalı
        return shift(acc, dx, 0)

    add(font, "Gbreve", 0x11E, contours(font, G) + centered(breve_up, name_of(ord("U")), G), G)
    add(font, "gbreve", 0x11F, contours(font, g) + centered(breve_lo, name_of(ord("u")), g), g)
    add(font, "Idotaccent", 0x130, contours(font, I) + dot_up, I)
    add(font, "Scedilla", 0x15E, contours(font, S) + centered(cedilla_up, name_of(ord("C")), S), S)
    add(font, "scedilla", 0x15F, contours(font, s) + centered(cedilla_lo, name_of(ord("c")), s), s)
    if upem < 1600:
        # PixelOperator8'in kendi Ç/ç'si harfi ezip cedilla'ya yapıştırıyor; 8 px'te "ş" gibi okunuyor.
        # Normal C/c + altında ayrı cedilla olarak yeniden kur.
        C, c = name_of(ord("C")), name_of(ord("c"))
        add(font, name_of(0xC7), 0xC7, contours(font, C) + cedilla_up, C)
        add(font, name_of(0xE7), 0xE7, contours(font, c) + cedilla_lo, c)
    font["maxp"].numGlyphs = len(font.getGlyphOrder())
    font.save(path_out)
    print("yazıldı:", path_out)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name in FONTS:
        build(HERE / name, OUT / name)
