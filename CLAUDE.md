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
- UI metinleri baştan `tr()` ile yazılır (TR + EN).

## Temel tasarım kuralları
- Savaştan sonra sunulan kartlar, **o savaşta karşılaşılan krallığın** kartlarıdır.
- Deste yok; seçilen kart anında ordu ızgarasına eklenir.
- 3 can; kaybedilen savaş tekrar oynanmaz.

## Çalışma şekli
- Kullanıcı Godot'u öğreniyor: her adımda hangi Godot kavramının kullanıldığını kısaca açıkla.
- Türkçe yanıt ver; kod, komut ve hata mesajları orijinal kalsın.
