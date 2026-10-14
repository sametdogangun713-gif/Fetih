# Fetih — proje talimatları

## Proje
- Offline, tek oyunculu, fetih temalı auto-battler roguelite. Ana referans: 9 Kings.
- Tasarım: [oyun_tasarim_dokumani.md](oyun_tasarim_dokumani.md)
- Yol haritası ve aşamalar: [2B_oyun_projesi_yol_haritasi.md](2B_oyun_projesi_yol_haritasi.md)
- Godot projesi: `Fetih/` klasörü.

## Gizlilik
- Proje tamamen gizli. **GitHub'a veya herhangi bir uzak depoya asla push yapılmaz**, remote eklenmez, repo oluşturulmaz. Git sadece yerel.

## Teknik
- Motor: **Godot 4.7.2** (standart, .NET değil). Dil: **GDScript**. API için context7'de `/godotengine/godot-docs` (4.7 dalı) kullan, tahmin etme.
- Godot yolu: `C:\Users\Samet PC\Desktop\Godot_v4.7.2-stable_win64.exe`
- Renderer: Compatibility. Arayüz düzeni 640x360 (viewport), stretch `canvas_items`, scale `integer`: her şey pencere çözünürlüğünde çizilir (varsayılan 3x = 1920x1080). Varsayılan texture filter Nearest (piksel sanat birlikler); HD zemin (`GroundArt`) doğrusal süzme kullanır.
- İzometrik görünüm (64x32 karo), `y_sort_enabled`. `Ground` TileMapLayer görünmez, sadece koordinat için; zemini `GroundArt` çizer (CC0 rubberduck çimen + ağaçlar, rakip krallığa göre `BIOMES`).
- Fizik motoru kullanılmaz; bölük tabanlı simülasyon, basit matematik.
- Özel mekanikler `UnitData` alanlarıyla (burn_ratio, slow_amount, regen_ratio, revive_ratio, splits) ve `BattleSimulation` içinde; yeni mekanik eklerken ferman `stat` alanı da aynı alan adını kullanabilir.
- Savaş deterministik olmalı (seed'li `RandomNumberGenerator`).
- Veri odaklı: birlik/krallık/kart verileri `Fetih/data/` altında `.tres` dosyaları.
- UI metinleri baştan `tr()` ile yazılır (TR + EN); statik fonksiyonlarda `UiKit.t()`.
- Koşu durumu `RunState` autoload'unda (`scripts/run/run_state.gd`); ekran geçişleri `Screens` ile.
- Kalıcı profil `Profile` autoload'unda (`scripts/meta/profile.gd`, `user://save.json`). `RunState` Profile'a bağımlı değildir (bonuslar `start_run` parametresi). Testler `save_path`'i değiştirir; **oyuncunun gerçek kaydına asla yazma.** Kayıt testi: `res://tools/save_test.gd`.
- Arayüz kodla kurulur (`UiKit` yardımcıları); ekran sahneleri sadece kök Control + script.
- Ekransız test: `godot --headless --path Fetih -s <script>`; ekran görüntüsü: `--write-movie out.png --quit-after N`.
- Denge testi: `powershell -ExecutionPolicy Bypass -File Fetih\tools\run_balance_test.ps1` — birlik değeri değişince çalıştır.
- Koşu zorluğu: `godot --headless --path Fetih -s res://tools/run_test.gd` (botlarla fetih oranı). Yükseltme eşitliği: `res://tools/upgrade_test.gd`. Boss gücü: `res://tools/boss_test.gd`.
- Görsel: sprite sayfası 4 satır (durma, yürüme, saldırı, ölüm), kare biçimli kareler, figür sağa bakar. `assets/sprites/units/<id>.png` varsa o, yoksa `UnitSprites` role göre koddan üretir. Efektler `BattleFx` (sadece görüntü; simülasyona dokunmaz). Önizleme: `res://tools/sprite_preview.gd -- out.png`.
- Hazır sprite'lar: CC0 paketler `kaynak_assetler/` (Godot dışı, lisanslar `LISANSLAR.md`). `res://tools/import_sprites.gd` `SPECS` tablosuna göre `assets/sprites/units/` sayfalarını üretir, sonra `godot --headless --path Fetih --import`. Atlılar, toplar, golemler, kentaurlar koddan üretiliyor.
- Savaş kamerası otomatik takip eder (`BattleCamera.follow`, sadece 0.5/1/2 yakınlık); elle kontrol takibi kapatır, F açar. `BattleController.PLAYBACK` x1 hızını yavaşlatır (sadece gösterim).
- Ayarlar: `Settings` autoload (`scripts/meta/settings.gd`, `user://settings.cfg`, ConfigFile). İlerlemeden ayrı. Testler `settings_path`'i değiştirir; oyuncunun gerçek ayar dosyasına yazma.
- Çeviri: kaynak dil Türkçe (msgid), İngilizce `Fetih/i18n/en.po`. Yeni metin ekleyince: `res://tools/update_translations.gd` çalıştır, listelenen çevrilmemiş msgstr'leri doldur. Veri adları (`display_name`, `description`) gösterilirken `tr()` ile sarılır. Yedek dil `tr` (yoksa Türkçe oyuncu İngilizce görür).
- Pencereler: `Overlay` (karartma + panel), `SettingsPanel.open()`, `PauseMenu` (ekran kendine ekler), `Tips.show_once()` (görülenler Profile'da).
- Ses: `Audio` autoload (`Audio.play("hit")`, `Audio.play_music("battle")`); dosyalar `assets/audio/sfx|music/<ad>.wav`. Geçici sesler `res://tools/build_audio.gd` ile üretilir (sonra `--import`). Araç scriptleri (`-s`) autoload adlarını derleme anında tanımaz: araçların derlediği zincirdeki scriptler (UiKit, battlefield → battle_fx, settings) autoload'a `get_node` / preload ile erişir; araçlar UI sınıflarını `load()` ile alır.
- Savaş gösterimi / kayıt: `res://tools/battle_showcase.gd -- <seed>|list|boss <krallık>|scene <yol>` (kayıt ayrı dosyaya yazılır). `--quit-after` ile kapanışta çıkan "resources still in use" mesajı ani kapanıştan; normal çıkışta yok.
- Yayın: `Fetih/export_presets.cfg` ("Windows Desktop", çıktı `Fetih/build/windows/`, git dışı). Export şablonu gerekir; şablonsuz deneme: `--export-pack "Windows Desktop" build/test/Fetih.pck`. Mağaza metni ve ekran görüntüleri `yayin/`. Sürüm `project.godot` → `config/version`.
- Boss'lar `Fetih/data/bosses/` altında (kart havuzuna girmez); krallık `.tres` dosyası boss'u ve başlangıç fermanını gösterir.

## Temel tasarım kuralları
- Savaştan sonra sunulan birlik kartları ve fermanlar, **o savaşta karşılaşılan krallıktan** gelir. Yükseltme kartları oyuncunun kendi bölükleri için.
- Deste yok; seçilen kart anında uygulanır.
- 3 can; kaybedilen savaş tekrar oynanmaz.
- En fazla 5 bölük, bölük seviyesi 1–5. Denge sayıları `Fetih/scripts/data/balance.gd` içinde; değiştirince denge aracını ve otomatik koşu testini çalıştır.

## Çalışma şekli
- Kullanıcı Godot'u öğreniyor: her adımda hangi Godot kavramının kullanıldığını kısaca açıkla.
- Türkçe yanıt ver; kod, komut ve hata mesajları orijinal kalsın.
