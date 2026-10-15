# Fetih — proje talimatları

## Proje
- Offline, tek oyunculu, fetih temalı auto-battler roguelite. Ana referans: 9 Kings.
- Tasarım: [oyun_tasarim_dokumani.md](oyun_tasarim_dokumani.md)
- Yol haritası ve aşamalar: [2B_oyun_projesi_yol_haritasi.md](2B_oyun_projesi_yol_haritasi.md)
- Godot projesi: `Fetih/` klasörü.

## Gizlilik
- Proje gizli. Tek uzak depo: **özel (private)** GitHub reposu `origin` → https://github.com/sametdogangun713-gif/Fetih. Push sadece buraya.
- Repo **asla public yapılmaz**, başka remote eklenmez, başkasıyla paylaşılmaz (collaborator eklemek kullanıcıya sorulur).

## Teknik
- Motor: **Godot 4.7.2** (standart, .NET değil). Dil: **GDScript**. API için context7'de `/godotengine/godot-docs` (4.7 dalı) kullan, tahmin etme.
- Godot yolu: `C:\Users\Samet PC\Desktop\Godot_v4.7.2-stable_win64.exe`
- Renderer: Compatibility. Arayüz düzeni 640x360 (viewport), stretch `canvas_items`, scale `integer`: her şey pencere çözünürlüğünde çizilir (varsayılan 3x = 1920x1080). Varsayılan texture filter Nearest: birlikler, zemin (`GroundArt`) ve ağaçlar hep Nearest, alt-piksel kayma yok.
- Görsel dil: 9 Kings (spec `docs/superpowers/specs/2026-10-15-grafik-devrimi-design.md`). Ayna izometrik (64x32 karo, oyuncu sağ altta): `Battlefield.field_to_world` / `world_to_field` (TileMap yok), `y_sort_enabled`. Zemini `GroundArt` çizer: biyom başına düz renk (`BIOMES.ramp[1]`) + seyrek motif (`motif_points`), kenarda öbek ağaçlar (`assets/terrain/px/plants`, `build_ground.gd` palete indirir). Her ordunun arkasında krallık kampı: `KingdomCamp` + `unit_art/building_art.gd` (koddan, krallık `color`/`accent_color`).
- Fizik motoru kullanılmaz; bölük tabanlı simülasyon, basit matematik.
- Özel mekanikler `UnitData` alanlarıyla (burn_ratio, slow_amount, regen_ratio, revive_ratio, splits) ve `BattleSimulation` içinde; yeni mekanik eklerken ferman `stat` alanı da aynı alan adını kullanabilir.
- Savaş deterministik olmalı (seed'li `RandomNumberGenerator`).
- Veri odaklı: birlik/krallık/kart verileri `Fetih/data/` altında `.tres` dosyaları.
- UI metinleri baştan `tr()` ile yazılır (TR + EN); statik fonksiyonlarda `UiKit.t()`.
- Koşu durumu `RunState` autoload'unda (`scripts/run/run_state.gd`); ekran geçişleri `Screens` ile.
- Kalıcı profil `Profile` autoload'unda (`scripts/meta/profile.gd`, `user://save.json`). `RunState` Profile'a bağımlı değildir (bonuslar `start_run` parametresi). Testler `save_path`'i değiştirir; **oyuncunun gerçek kaydına asla yazma.** Koruma: araç scriptiyle (`-s`) çalışırken `Profile` ve `Settings` varsayılan dosyalara yazmayı reddeder (`Profile.is_tool_run`). Kayıt testi: `res://tools/save_test.gd`.
- Arayüz kodla kurulur (`UiKit` yardımcıları); ekran sahneleri sadece kök Control/Node + script.
- Yazı tipi: Pixel Operator (CC0, `Fetih/assets/fonts/`, Türkçe harfler `kaynak_assetler/fontlar/pixel_operator/turkce_harf_ekle.py` ile eklenir: `uvx --from fonttools python -I ...`). Boyutlar `UiKit.font_spec` ile piksel net katlara oturur (<=9 → 8 px font @8, 10-14 → @16, 15-22 → 8 px font @16, 23+ → @32); yazı boyutu için `UiKit.label(..., size)` ya da `UiKit.set_font_size`, çizimde `UiKit.pixel_font(true)`. Test: `res://tools/font_test.gd`, önizleme `res://tools/font_preview.gd -- out.png`.
- Ekran akışı: ana menü/krallık seçimi (`kingdom_select`) → **Meydan** (`scenes/run/meydan.tscn`, tek sahne; aşamalar PREP → BATTLE → CARDS → PREP) → koşu sonu (`run_end`). Aşama `Screens.next_phase` ile seçilir (yeni koşu "prep"; `resume_saved_run` kayıttaki aşamayı verir), Meydan açılışta okuyup sıfırlar; aşama değişince koşu kaydedilir. Eski hazırlık/kart ekranları (`prep`, `card_select`) kaldırıldı.
- Meydan parçaları: `Meydan` (aşama makinesi, `scripts/run/meydan.gd`), `BattleRunner` (savaş yürütme: simülasyon adımı, görüntüler, kamera), `BattleHud` (savaş arayüzü; `battle.tscn` ile ortak), `PrepLayer` (alanda sürükle-bırak, rakip önizlemesi), `CardLayer` (alt kart paneli, alanda değiştirme), `RunField` (zemin/dekor/aura), `SquadInfo` (bölük bilgisi). `battle.tscn` sadece test/gösterim modu için kalır.
- Bölük konumu: `ArmySquad.pos` (Vector2, yerleşim bölgesi koordinatı: x cephe boyunca, y derinlik, 0 = ön) ve `Formation` (serbest yerleşim, `nearest_free`/`clamp_deploy`, ızgara `cell_to_deploy`). Derinlik bantları ön/orta/arka (`ArmySquad.band()`, `PassiveData.applies_to`): ön cephe/arka saf fermanları derinliğe bakar. Rakip ordu aynı koordinatı ayna gibi kullanır.
- Meydan testleri: `res://tools/meydan_test.gd` (aşama makinesi, kayıt, kart uygulama), `res://tools/field_test.gd` (Formation/bantlar), `res://tools/card_fit_test.gd` (kart sığması). Ekran: `battle_showcase.gd -- meydan prep|battle|cards`.
- Ekransız test: `godot --headless --path Fetih -s <script>`; ekran görüntüsü: `--write-movie out.png --quit-after N`.
- Denge testi: `powershell -ExecutionPolicy Bypass -File Fetih\tools\run_balance_test.ps1` — birlik değeri değişince çalıştır.
- Koşu zorluğu: `godot --headless --path Fetih -s res://tools/run_test.gd` (botlarla fetih oranı). Yükseltme eşitliği: `res://tools/upgrade_test.gd`. Boss gücü: `res://tools/boss_test.gd`.
- Görsel: sprite sayfası 4 satır (durma, yürüme, saldırı, ölüm), kare biçimli kareler, figür sağa bakar. Askerler `unit_art/mini_unit_art.gd` (`MiniUnitArt`, 16x16, ~10-12 px figür, takım rengi gövdede: oyuncu altın `f9c22b`, rakip `e83b3b`); `UnitSprites.sheet_for(unit, team)`. Sadece boss'lar `assets/sprites/units/<id>.png` ya da eski büyük üretimi kullanır. Formasyon `SquadView.layout`. Efektler `BattleFx` (sadece görüntü; simülasyona dokunmaz). Önizleme: `res://tools/sprite_preview.gd -- out.png`. Palet: Resurrect 64 (`assets/palette/resurrect-64.hex`, `SpritePalette`); `import_sprites.gd` ve `build_ground.gd` paletin dışına çıkmaz. Kuşatma birlikleri `unit_art/siege_art.gd` (top, mancınık).
- Hazır sprite'lar: CC0 paketler `kaynak_assetler/` (Godot dışı, lisanslar `LISANSLAR.md`). `res://tools/import_sprites.gd` `assets/sprites/units/` sayfalarını üretir; bunlar artık sadece boss'larda kullanılır. Görsel testler: `res://tools/field_test.gd` (dönüşüm, zemin, formasyon, yapılar), `res://tools/mini_art_test.gd`, `res://tools/card_fit_test.gd`.
- Savaş kamerası otomatik takip eder (`BattleCamera.follow`, `ZOOM_LEVELS`; ilk kare kampları da gösterir, otomatik takip en fazla 1.5); elle kontrol takibi kapatır, F açar. `BattleController.PLAYBACK` x1 hızını yavaşlatır (sadece gösterim).
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

## Ajan kullanımı (kullanım limiti)
- Ajan modelleri: `gameplay-programci`, `gorsel-efekt-ajani`, `denge-ajani`, `oyun-tasarimci` → sonnet; `playtester`, `ceviri-ajani` → haiku. Opus sadece ana oturumda.
- Aynı anda en fazla 2 ajan. Aynı dosyaya dokunacak ajanlar paralel çalışmaz: sıralı çalıştır veya `isolation: worktree` kullan.
- Ajan prompt'u kendi kendine yetsin: dosya yolları, kabul kriteri, çalıştırılacak test komutu. Ajan keşifle token harcamasın.
- Küçük iş (1-2 dosya, bariz değişiklik) ajana verilmez; ana oturum yapar.
- Ajan bitirince doğrulama için yeni ajan açma; ana oturum tek test komutu çalıştırır.
- Biten ajan worktree'leri (`.claude/worktrees/`) birleştirildikten sonra temizlenir.
