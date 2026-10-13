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
- Renderer: Compatibility. Piksel sanat: viewport 640x360, stretch `viewport`, scale `integer`, texture filter Nearest.
- İzometrik görünüm (`TileMapLayer`, 64x32 karo), `y_sort_enabled`.
- Fizik motoru kullanılmaz; bölük tabanlı simülasyon, basit matematik.
- Savaş deterministik olmalı (seed'li `RandomNumberGenerator`).
- Veri odaklı: birlik/krallık/kart verileri `Fetih/data/` altında `.tres` dosyaları.
- UI metinleri baştan `tr()` ile yazılır (TR + EN); statik fonksiyonlarda `UiKit.t()`.
- Koşu durumu `RunState` autoload'unda (`scripts/run/run_state.gd`); ekran geçişleri `Screens` ile.
- Arayüz kodla kurulur (`UiKit` yardımcıları); ekran sahneleri sadece kök Control + script.
- Ekransız test: `godot --headless --path Fetih -s <script>`; ekran görüntüsü: `--write-movie out.png --quit-after N`.
- Denge testi: `powershell -ExecutionPolicy Bypass -File Fetih\tools\run_balance_test.ps1` — birlik değeri değişince çalıştır.
- Koşu zorluğu: `godot --headless --path Fetih -s res://tools/run_test.gd` (botlarla fetih oranı). Yükseltme eşitliği: `res://tools/upgrade_test.gd`. Boss gücü: `res://tools/boss_test.gd`.
- Boss'lar `Fetih/data/bosses/` altında (kart havuzuna girmez); krallık `.tres` dosyası boss'u ve başlangıç fermanını gösterir.

## Temel tasarım kuralları
- Savaştan sonra sunulan birlik kartları ve fermanlar, **o savaşta karşılaşılan krallıktan** gelir. Yükseltme kartları oyuncunun kendi bölükleri için.
- Deste yok; seçilen kart anında uygulanır.
- 3 can; kaybedilen savaş tekrar oynanmaz.
- En fazla 5 bölük, bölük seviyesi 1–5. Denge sayıları `Fetih/scripts/data/balance.gd` içinde; değiştirince denge aracını ve otomatik koşu testini çalıştır.

## Çalışma şekli
- Kullanıcı Godot'u öğreniyor: her adımda hangi Godot kavramının kullanıldığını kısaca açıkla.
- Türkçe yanıt ver; kod, komut ve hata mesajları orijinal kalsın.
