extends Node
## Kalıcı oyuncu profili: açık krallıklar, Şan, kalıcı geliştirmeler, istatistikler, yarım kalan koşu.
## Autoload: oyun açılınca user://save.json'dan yüklenir; her değişiklikte kaydedilir.
## Kayıt güvenliği: önce .tmp dosyasına yazılır, sonra asıl dosyanın yerine taşınır
## (yazma sırasında oyun kapanırsa eski kayıt bozulmaz). Okunamayan kayıt silinmez, yedeklenir.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## Kayıt dosyası. Testler bunu değiştirir; oyuncunun gerçek kaydına dokunmasınlar diye.
var save_path := SAVE_PATH
var glory := 0  ## Şan: kalıcı geliştirmelerin parası.
var unlocked: Array[StringName] = []
var upgrades := {}  ## geliştirme id -> seviye
var stats := {}
var saved_run := {}  ## Yarım kalan koşu (RunState.to_dict). Boşsa yok.
var tips_seen: Array[String] = []  ## Gösterilmiş başlangıç ipuçları (Tips).


func _ready() -> void:
	load_profile()


# --- Kayıt ---

func load_profile() -> void:
	_reset()
	if not FileAccess.file_exists(save_path):
		_ensure_default_unlocks()
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(data) != TYPE_DICTIONARY:
		var backup := save_path + ".bozuk"
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup))
		push_warning("Kayıt okunamadı, yedeklendi: " + backup)
		_ensure_default_unlocks()
		return
	data = _migrate(data)
	glory = int(data.get("glory", 0))
	for id in data.get("unlocked", []):
		unlocked.append(StringName(id))
	for id in data.get("upgrades", {}):
		upgrades[id] = int(data["upgrades"][id])
	var saved_stats: Dictionary = data.get("stats", {})
	for key in saved_stats:
		stats[key] = saved_stats[key]
	saved_run = data.get("saved_run", {})
	for id in data.get("tips_seen", []):  # Aşama 10'dan eski kayıtlarda yok: boş liste
		tips_seen.append(String(id))
	_ensure_default_unlocks()


func save_profile() -> void:
	if save_path == SAVE_PATH and is_tool_run():
		push_warning("Araç scripti oyuncunun gerçek kaydına yazmak istedi; atlandı (save_path'i değiştir).")
		return
	var unlocked_ids: Array[String] = []
	for id in unlocked:
		unlocked_ids.append(String(id))
	var data := {
		"save_version": SAVE_VERSION,
		"glory": glory,
		"unlocked": unlocked_ids,
		"upgrades": upgrades,
		"stats": stats,
		"saved_run": saved_run,
		"tips_seen": tips_seen,
	}
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Kayıt yazılamadı: %s (%d)" % [tmp_path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path),
			ProjectSettings.globalize_path(save_path))
	if err != OK:
		push_error("Kayıt taşınamadı (%d)" % err)


## Araç scriptiyle mi çalışıyoruz (godot -s ...)? Oyun (editörden F5 ya da yayın) hiç -s almaz.
## Godot: OS.get_cmdline_args() motorun komut satırı argümanlarını verir.
static func is_tool_run() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("-s") or args.has("--script")


## Eski sürüm kayıtlarını yeni biçime çevirir. Sürüm 2 gelince buraya adım eklenir.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_version", 1))
	if version > SAVE_VERSION:
		push_warning("Kayıt daha yeni bir oyun sürümünden (%d)." % version)
	return data


func _reset() -> void:
	glory = 0
	unlocked.clear()
	upgrades.clear()
	stats = {"runs": 0, "victories": 0, "battles_won": 0, "best_battle": 0, "kingdom_victories": {}}
	saved_run = {}
	tips_seen.clear()


func _ensure_default_unlocks() -> void:
	for kingdom in KingdomCatalog.all():
		if kingdom.starts_unlocked and not unlocked.has(kingdom.id):
			unlocked.append(kingdom.id)


# --- Krallıklar ---

func is_unlocked(kingdom_id: StringName) -> bool:
	return unlocked.has(kingdom_id)


func locked_kingdoms() -> Array[StringName]:
	var result: Array[StringName] = []
	for kingdom in KingdomCatalog.all():
		if not is_unlocked(kingdom.id):
			result.append(kingdom.id)
	return result


# --- Kalıcı geliştirmeler ---

func level_of(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func can_buy(upgrade_id: String) -> bool:
	var cost := MetaUpgrades.next_cost(upgrade_id, level_of(upgrade_id))
	return cost >= 0 and glory >= cost


func buy(upgrade_id: String) -> void:
	if not can_buy(upgrade_id):
		return
	glory -= MetaUpgrades.next_cost(upgrade_id, level_of(upgrade_id))
	upgrades[upgrade_id] = level_of(upgrade_id) + 1
	save_profile()


## Koşuya verilecek kalıcı bonuslar (RunState.start_run'a parametre olarak gider).
func run_perks() -> Dictionary:
	return {
		"extra_cards": level_of(MetaUpgrades.EXTRA_CARD),
		"extra_lives": level_of(MetaUpgrades.EXTRA_LIFE),
		"veterans": level_of(MetaUpgrades.VETERANS),
		"rerolls": level_of(MetaUpgrades.SCOUTING),
	}


# --- Yarım kalan koşu ---

func has_saved_run() -> bool:
	return not saved_run.is_empty()


func store_run(run_dict: Dictionary) -> void:
	saved_run = run_dict
	save_profile()


func clear_run() -> void:
	saved_run = {}
	save_profile()


# --- Başlangıç ipuçları ---

func mark_tip_seen(id: String) -> void:
	if not tips_seen.has(id):
		tips_seen.append(id)
		save_profile()


## Ayarlardaki "İpuçlarını yeniden göster".
func reset_tips() -> void:
	tips_seen.clear()
	save_profile()


# --- Koşu sonu ---

## Koşu bitince bir kez çağrılır: Şan ve istatistikler eklenir, mühürler krallık açar.
## Döndürür: yeni açılan krallıklar.
func record_run_end(glory_earned: int, victory: bool, kingdom_id: StringName, battles_won: int,
		battles_played: int, seals: Array[StringName]) -> Array[StringName]:
	glory += glory_earned
	stats["runs"] = int(stats.get("runs", 0)) + 1
	stats["battles_won"] = int(stats.get("battles_won", 0)) + battles_won
	stats["best_battle"] = maxi(int(stats.get("best_battle", 0)), battles_played)
	var newly_unlocked: Array[StringName] = []
	if victory:
		stats["victories"] = int(stats.get("victories", 0)) + 1
		var per_kingdom: Dictionary = stats.get("kingdom_victories", {})
		per_kingdom[String(kingdom_id)] = int(per_kingdom.get(String(kingdom_id), 0)) + 1
		stats["kingdom_victories"] = per_kingdom
		for id in seals:
			if not unlocked.has(id):
				unlocked.append(id)
				newly_unlocked.append(id)
	saved_run = {}
	save_profile()
	return newly_unlocked
