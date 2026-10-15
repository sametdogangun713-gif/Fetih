extends SceneTree
## Piksel yazı tipinde Türkçe (ve arayüzde kullanılan) karakterler var mı.
## Çalıştırma: godot --headless --path Fetih -s res://tools/font_test.gd

const FONTS := ["res://assets/fonts/PixelOperator.ttf", "res://assets/fonts/PixelOperator8.ttf"]
const CHARS := "ĞğİıŞşÇçÖöÜüÂâÎîÛû·•%-"

var failures := 0


func check(name: String, ok: bool) -> void:
	print("%s  %s" % ["TAMAM " if ok else "HATA  ", name])
	if not ok:
		failures += 1


func _initialize() -> void:
	for path in FONTS:
		var font: FontFile = load(path)
		check("%s yüklendi" % path.get_file(), font != null)
		if font == null:
			continue
		var missing := ""
		for i in CHARS.length():
			if not font.has_char(CHARS.unicode_at(i)):
				missing += CHARS[i]
		check("%s eksik: [%s]" % [path.get_file(), missing], missing == "")
	print("Hata: %d" % failures)
	quit(1 if failures > 0 else 0)
