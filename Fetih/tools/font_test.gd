extends SceneTree
## Arayüz yazı tiplerinde (Cinzel başlık, Nunito metin) Türkçe ve arayüz karakterleri var mı;
## UiKit yazı API'si doğru fontu ve ağırlığı veriyor mu.
## Çalıştırma: godot --headless --path Fetih -s res://tools/font_test.gd

const FONTS := ["res://assets/fonts/Cinzel.ttf", "res://assets/fonts/Nunito.ttf"]
const CHARS := "ĞğİıŞşÇçÖöÜüÂâÎîÛû·•%-"

var failures := 0


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


func _initialize() -> void:
	for path in FONTS:
		var font: FontFile = load(path) if ResourceLoader.exists(path) else null
		check("%s yüklendi" % path.get_file(), font != null)
		if font == null:
			continue
		var missing := ""
		for i in CHARS.length():
			if not font.has_char(CHARS.unicode_at(i)):
				missing += CHARS[i]
		check("%s eksik: [%s]" % [path.get_file(), missing], missing == "")
	var kit: GDScript = load("res://scripts/ui/ui_kit.gd")
	var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
	var body: Font = kit.ui_font(700)
	check("ui_font FontVariation", body is FontVariation)
	if body is FontVariation:
		check("ui_font Nunito", (body as FontVariation).base_font.resource_path.ends_with("Nunito.ttf"))
		check("ui_font ağırlık 700", int((body as FontVariation).variation_opentype.get(wght, 0)) == 700)
	var head: Font = kit.heading_font()
	check("heading_font Cinzel", head is FontVariation
			and (head as FontVariation).base_font.resource_path.ends_with("Cinzel.ttf"))
	var l: Label = kit.label("Fetih", 14, Color.WHITE, true)
	check("label başlık fontu", l.get_theme_font("font") == head)
	check("label boyutu aynen", l.get_theme_font_size("font_size") == 14)
	l.free()
	print("Hata: %d" % failures)
	quit(1 if failures > 0 else 0)
