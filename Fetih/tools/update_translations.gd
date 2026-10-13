extends SceneTree
## Oyundaki bütün çevrilecek metinleri toplar ve i18n/en.po dosyasını günceller.
## Kaynak dil Türkçe: msgid Türkçe metnin kendisi, msgstr İngilizcesi.
## Var olan çeviriler korunur; yeni metinler boş msgstr ile eklenir, artık kullanılmayanlar silinir.
## Sonunda çevrilmemiş metinleri listeler (boş msgstr = oyunda Türkçe görünür).
##
##   godot --headless --path Fetih -s res://tools/update_translations.gd
##
## Toplanan yerler:
## - .gd: tr("...") ve UiKit.t("...") içindeki sabit metinler
## - role_rules.gd ROLE_NAMES, meta_upgrades.gd "name"/"desc" (kodda tr(değişken) ile çevrilir)
## - data/**/*.tres: display_name, description, specialty_label
## - scenes/**/*.tscn: text, tooltip_text

const PO_PATH := "res://i18n/en.po"

var _entries: Array[String] = []  ## msgid'ler, ilk görüldükleri sırayla
var _refs := {}  ## msgid -> ilk görüldüğü dosya


func _initialize() -> void:
	var string_re := "\"((?:[^\"\\\\]|\\\\.)*)\""
	var call_re := RegEx.create_from_string("\\b(?:tr|t)\\(" + string_re)
	var table_re := RegEx.create_from_string("(?m)^\\t[A-Z_]+: " + string_re + ",")
	var meta_re := RegEx.create_from_string("\"(?:name|desc)\": " + string_re)
	var data_re := RegEx.create_from_string("(?m)^(?:display_name|description|specialty_label) = " + string_re)
	var scene_re := RegEx.create_from_string("(?m)^(?:text|tooltip_text) = " + string_re)

	for path in _files("res://scripts", ".gd"):
		var text := FileAccess.get_file_as_string(path)
		_collect(call_re, text, path)
		if path.ends_with("role_rules.gd"):
			_collect(table_re, text, path)
		if path.ends_with("meta_upgrades.gd"):
			_collect(meta_re, text, path)
	for path in _files("res://data", ".tres"):
		_collect(data_re, FileAccess.get_file_as_string(path), path)
	for path in _files("res://scenes", ".tscn"):
		_collect(scene_re, FileAccess.get_file_as_string(path), path)

	var old := _read_po(PO_PATH)
	var missing: Array[String] = []
	var lines: PackedStringArray = [
		"# Fetih - İngilizce çeviri. Kaynak dil Türkçe (msgid).",
		"# tools/update_translations.gd ile güncellenir; msgstr satırları elle doldurulur.",
		"msgid \"\"",
		"msgstr \"\"",
		"\"Language: en\\n\"",
		"\"MIME-Version: 1.0\\n\"",
		"\"Content-Type: text/plain; charset=UTF-8\\n\"",
		"\"Content-Transfer-Encoding: 8-bit\\n\"",
		"",
	]
	for id in _entries:
		var translated: String = old.get(id, "")
		if translated == "":
			missing.append(id)
		lines.append("#: " + String(_refs[id]).trim_prefix("res://"))
		lines.append("msgid " + _quote(id))
		lines.append("msgstr " + _quote(translated))
		lines.append("")
	var removed := 0
	for id in old:
		if not _refs.has(id):
			removed += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PO_PATH.get_base_dir()))
	var file := FileAccess.open(PO_PATH, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("%d metin, %d çevrilmemiş, %d kullanılmayan silindi -> %s" % [
			_entries.size(), missing.size(), removed, PO_PATH])
	for id in missing:
		print("  ÇEVRİLMEDİ: ", id.c_escape())
	quit()


func _collect(re: RegEx, text: String, path: String) -> void:
	for m in re.search_all(text):
		var id := m.get_string(1).c_unescape()
		if id.strip_edges() == "" or _refs.has(id) or _is_symbolic(id):
			continue
		_refs[id] = path
		_entries.append(id)


## Çeviri gerektirmeyen metinler: sadece sayı/biçim kodu ("x2", "%d%%", "II").
func _is_symbolic(text: String) -> bool:
	var letters := 0
	for c in text.replace("%d", "").replace("%s", ""):
		if c.to_lower() != c.to_upper():  # harf: büyük ve küçük hali farklı olan karakter
			letters += 1
	return letters < 2 or RegEx.create_from_string("^x\\d$").search(text) != null


func _files(dir: String, extension: String) -> Array[String]:
	var result: Array[String] = []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(extension):
			result.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		result.append_array(_files(dir.path_join(sub), extension))
	return result


## Basit .po okuyucu: msgid -> msgstr (çok satırlı "..." birleşimlerini destekler).
func _read_po(path: String) -> Dictionary:
	var result := {}
	if not FileAccess.file_exists(path):
		return result
	var key := ""
	var current := ""
	var target := ""
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("msgid "):
			if target == "msgstr" and key != "":
				result[key] = current
			target = "msgid"
			current = _unquote(line.trim_prefix("msgid "))
		elif line.begins_with("msgstr "):
			key = current
			target = "msgstr"
			current = _unquote(line.trim_prefix("msgstr "))
		elif line.begins_with("\""):
			current += _unquote(line)
	if target == "msgstr" and key != "":
		result[key] = current
	return result


## .po kaçışları: ters bölü, tırnak, satır sonu, sekme (c_escape ' karakterini de kaçırırdı).
func _quote(text: String) -> String:
	var escaped := text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t")
	return "\"" + escaped + "\""


func _unquote(text: String) -> String:
	return text.substr(1, text.length() - 2).c_unescape()
