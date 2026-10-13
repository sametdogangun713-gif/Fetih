# 2B Oyun Projesi: Yol Haritası (v2)

Bu dosya, Godot 4 ile yapılacak izometrik, offline, fetih temalı auto-battler roguelite oyununun planıdır.
Oyunun tasarımı için: [oyun_tasarim_dokumani.md](oyun_tasarim_dokumani.md)

> v1'deki aksiyon (WASD ile hareket eden karakter) planı bu sürümde kaldırıldı. Oyun artık otomatik savaşan ordular üzerine kurulu.

---

## 1. İndirilecekler

### Zorunlu
- [ ] **Godot 4** — en güncel kararlı sürüm, **standart** (.NET değil). godotengine.org/download
- [ ] **Git** — git-scm.com
- [ ] **Yedekleme** — proje gizli, GitHub kullanılmaz. Haftada bir harici diske / USB belleğe kopya al
- [ ] **Piksel çizim aracı**, biri yeterli:
  - **Aseprite** (ücretli, ~20$, en iyisi; Steam'den alınabilir)
  - **LibreSprite** (ücretsiz, Aseprite'ın eski açık kaynak kopyası)
  - **Piskel** (ücretsiz, tarayıcıda)

### Faydalı
- [ ] **GitHub Desktop** — Git'i komut satırı olmadan kullanmak için
- [ ] **VS Code** + **godot-tools** eklentisi — Godot'un kendi editörü de yeterli, isteğe bağlı
- [ ] **Audacity** — ses düzenleme
- [ ] **jsfxr** (tarayıcıda) — retro ses efektleri
- [ ] **OBS Studio** — fragman ve oyun videosu kaydı (sonra)

Piksel sanat seçildiği için **Aseprite** önerim: animasyon zaman çizelgesi, palet ve sprite sheet dışa aktarma Godot ile en rahat çalışan araç.

### Hazır görseller (prototip için)
- [ ] **Lospec.com** — hazır piksel sanat renk paletleri (tüm oyun için tek palet seç)
- [ ] **Kenney.nl** — ücretsiz (CC0) izometrik karo ve UI paketleri
- [ ] **itch.io → Game Assets** — ücretsiz ve ucuz piksel birim paketleri
- [ ] **OpenGameArt.org** — ücretsiz müzik ve ses

**Lisans uyarısı:** Her paketin lisansına bak. CC0 serbest. CC-BY isim yazmayı ister. "Ticari kullanım yasak" olanları Steam'de satılan oyunda kullanamazsın.

**Font uyarısı:** Seçtiğin fontta **ğ, ş, ı, İ, ö, ü, ç** harfleri olmalı. Çoğu piksel font Türkçe karakter içermez. Google Fonts'ta "Latin Extended" desteği olanlara bak.

---

## 2. Proje klasör düzeni

```
Fetih/
├── project.godot
├── scenes/
│   ├── battle/        # savaş sahnesi, bölük sahnesi
│   ├── map/           # koşu haritası (20 savaşlık yol)
│   └── ui/            # menüler, kart seçimi, HUD
├── scripts/
│   ├── data/          # UnitData, KingdomData, CardData sınıfları
│   ├── battle/        # savaş simülasyonu
│   ├── run/           # koşu durumu, rakip üretimi
│   └── meta/          # kayıt, kilit açma
├── data/
│   ├── units/         # elf_archer.tres, orc_warrior.tres ...
│   ├── kingdoms/      # elves.tres, humans.tres ...
│   └── cards/
├── assets/
│   ├── sprites/
│   ├── tiles/         # izometrik karolar
│   ├── audio/sfx/
│   ├── audio/music/
│   └── fonts/
├── tools/             # denge testi scriptleri
└── .gitignore
```

---

## 3. Gerekli beceriler

| Beceri | Neden lazım | Aşama |
|---|---|---|
| GDScript temelleri (değişken, döngü, fonksiyon, dizi, sözlük) | Her şeyin temeli | 0-1 |
| Sahne ve düğüm mantığı | Godot'un çalışma biçimi | 1 |
| `TileMapLayer` (izometrik), `Camera2D`, Y-sort | Harita ve görünüm | 1 |
| Resource (`.tres`) ve `class_name` | Birlik/krallık/kart verileri | 2 |
| Sinyaller | Bölük öldü, savaş bitti, kart seçildi | 2-4 |
| Basit yapay zekâ (en yakın hedef, yürü, vur) | Bölük davranışı | 2 |
| `RandomNumberGenerator` ve seed | Deterministik savaş, rastgele kart | 3-4 |
| Autoload (singleton) | Koşu durumu sahneler arası taşınır | 4 |
| Control düğümleri, tema | Kart ekranı, menüler | 4-5 |
| `FileAccess` + JSON | Kayıt | 7 |
| Tween, parçacık, AnimatedSprite2D | Oyun hissi | 9 |
| `TranslationServer`, `tr()` | Türkçe/İngilizce | 4'ten itibaren |

---

## 4. Aşamalar

Her aşama sonunda **çalışan** bir sürüm olmalı. Grafik son aşamalara kadar basit şekiller (renkli kare, daire) olabilir.

### Aşama 0: Kurulum (1-2 gün)
- [x] Godot projesini oluştur, klasör düzenini kur
- [x] Yerel Git başlat (proje gizli, GitHub'a yüklenmez)
- [x] `.gitignore` ekle (`.godot/` klasörü repoya girmez)
- [x] Piksel sanat ayarları (640x360, `viewport`, `integer`, Nearest)
- **Çıktı:** Boş ama düzenli proje

### Aşama 1: İzometrik harita ve kamera (1 hafta)
- [x] `TileMapLayer` ile izometrik savaş alanı (64x32 karo, 10x16, oyuncu/düşman yerleşim bölgeleri)
- [x] Kamera: WASD/ok tuşları, sağ/orta tuşla sürükleme, tekerlekle yakınlaştırma (0.5x / 1x / 2x)
- [x] Haritada bir kareye tıklayınca karo koordinatını yazdır (koordinat dönüşümünü öğrenmek için)
- [x] `y_sort_enabled` ile derinlik sıralaması (test askerleri)
- [x] Piksel sanat ayarları: Stretch Mode = `viewport`, Default Texture Filter = `Nearest`
- **Çıktı:** Sol üst ön köşeden bakılan, gezilebilen boş savaş alanı

### Aşama 2: Bölük ve ilk savaş (2 hafta)
- [x] `UnitData` kaynağı (bkz. GDD bölüm 7)
- [x] Bölük görüntüsü: N asker, formasyon halinde dizilir, hedefe döner
- [x] Bölük yapay zekâsı: en yakın düşman bölüğünü bul → menzile kadar yürü → saldır
- [x] Hasar alınca asker sayısı düşer, askerler ön sıradan tek tek kaybolur
- [x] İki tarafın bölükleri: biri kalmayınca savaş biter, `battle_finished(winner)` sinyali
- [x] Hız düğmesi (x1 / x2 / x4) — `Engine.time_scale` yerine simülasyon adım sayısı (deterministik kalsın diye)
- [x] Simülasyon görüntüden ayrı (`BattleSimulation`), sabit 30 adım/sn, seed ile deterministik
- **Çıktı:** 2 savaşçı bölüğü vs 2 okçu bölüğü kapışıyor, kazanan belli oluyor

### Aşama 3: Roller, karşılıklar, denge aracı (2 hafta)
- [x] 6 rol: Savaşçı, Mızrakçı, Tank, Okçu, Büyücü, Süvari (`scripts/data/role_rules.gd`)
- [x] Karşılık tablosu (%25 bonus) + rol mekanikleri: büyü zırh deler ve alan hasarı, süvari hücumu ve okçu avı, mızrakçı hücumu karşılar, okçu yakın dövüşte %50
- [x] Savaşa seed ver, aynı seed aynı sonucu versin
- [x] `tools/balance_test.gd`: görüntüsüz 1320 savaş (~10 sn), kazanma oranı + karşılık kontrolü raporu
- [x] İlk 3 krallığın birlikleri: İnsanlar, Elfler, Orklar (her biri 4 birim)
- [x] Birlik maliyeti (asker başına güç puanı) — bölük bütçesi askere çevrilir
- [x] Denge: 12 birliğin hepsi %36–%62 genel kazanma; krallıklar %49–%51; karşılıklar 19-20 / 21
- **Çıktı:** 12 birim, ölçülebilir denge

### Aşama 4: Koşu döngüsü (2 hafta)
- [ ] Koşu durumu autoload'u (`RunState`): ordu, can, savaş sırası
- [ ] Krallık seçim ekranı (3 açık krallık)
- [ ] Rakip ordu üretici: tur numarasına göre bütçe
- [ ] Savaş → sonuç → kart seçimi → sonraki savaş
- [ ] 3 can, kaybedilen savaş tekrar oynanmaz
- [ ] Kart seçim ekranı: savaşılan krallığın 3 kartı, 1 seç
- [ ] **Ordu ızgarası (3x3):** seçilen bölüğü boş kareye sürükle-bırak, bölüklerin yerini değiştir
- [ ] Izgaradaki yer → savaş alanındaki başlangıç noktası (üst satır = ön cephe)
- [ ] Sıradaki rakibin krallığını hazırlık ekranında göster
- [ ] Tüm UI metinleri baştan `tr()` ile
- **Çıktı:** Baştan sona oynanabilen kısa (ör. 5 savaşlık) bir koşu

### Aşama 5: Kart çeşitliliği ve kombolar (2 hafta)
- [ ] Güçlendirme ve ferman kartları
- [ ] Bölük birleşme ve seviye (aynı birlik gelince seviye atlar, en fazla 3)
- [ ] Izgaranın büyümesi (3x3 → 5x5, boss'ları yendikçe)
- [ ] Komşuluk bonusları (karar verilirse)
- [ ] Krallık kombo bonusları (ör. 3 Elf bölüğü → okçular +menzil)
- [ ] Savaştan sonra sunulan kartlar = o savaşta karşılaşılan krallığın kartları (temel kural)
- **Çıktı:** Her koşu farklı bir ordu ile bitiyor

### Aşama 6: Boss'lar ve tam koşu — DİKEY KESİT (2-3 hafta)
- [ ] 3 başlangıç krallığının boss'ları
- [ ] 20 savaşlık koşu, 5/10/15/20. savaşlarda boss
- [ ] Koşu haritası ekranı (hangi savaştasın, sıradaki rakip kim)
- [ ] **KONTROL NOKTASI:** 5 kişiye oynat. "Bir koşu daha" dedirtiyor mu?
  - Evet → devam
  - Hayır → içerik eklemeden önce kart ve savaş sistemini düzelt
- **Çıktı:** 3 krallıkla tam oynanabilen oyun

### Aşama 7: Kalıcı ilerleme ve kayıt (1-2 hafta)
- [ ] `user://save.json`, içinde `"save_version": 1`
- [ ] Krallık mühürü ve kilit açma
- [ ] Kalıcı yükseltmeler (kart seçim sayısı, ekstra can)
- [ ] Ana menü: açık/kilitli krallıklar
- **Çıktı:** Oyunu kapatıp açınca ilerleme duruyor

### Aşama 8: Kalan 7 krallık (her biri ~1-2 hafta, toplam 2-3 ay)
Sıra önerisi (kolaydan zora):
- [ ] Golemler (tank — basit)
- [ ] Kentaurlar (süvari — basit)
- [ ] İblisler (alan hasarı + yanma)
- [ ] Cüceler (kuşatma, uzak menzil)
- [ ] Çamurlar (yavaşlatma, onarma)
- [ ] Ölüler (diriliş)
- [ ] Slime'lar (bölünme — en karmaşık)

Her krallık için: 4-5 birim, 1 boss, kombo bonusu, denge testi.

### Aşama 9: Oyun hissi, grafik, ses (1-2 ay)
- [ ] Vuruş efektleri: kısa yanıp sönme, parçacık, ekran sarsıntısı (boss'ta)
- [ ] Ölüm animasyonları, ok ve büyü mermileri
- [ ] Gerçek sprite'lar (kendi çizimin veya satın alınmış paket)
- [ ] Ses efektleri ve müzik (menü, savaş, boss)
- **Çıktı:** Görsel ve sesle tamamlanmış oyun

### Aşama 10: Cila ve ayarlar (2-3 hafta)
- [ ] Ayarlar: ses, tam ekran, çözünürlük, savaş hızı varsayılanı
- [ ] Duraklat menüsü
- [ ] Türkçe + İngilizce tam çeviri
- [ ] Başlangıç rehberi (ilk koşuda kısa ipuçları)
- **Çıktı:** Yayınlanabilir sürüm

### Aşama 11: Yayın (bkz. bölüm 5)

**Gerçekçi toplam süre:** Godot'u yeni öğrenen biri için **8-12 ay** (haftada 15-20 saat).

---

## 5. Yayın

Oyun offline olduğu için Steam zorunlu değil. Steam en çok satışı getirir; itch.io ücretsiz ve kolay bir ara adımdır.

### 5.1 itch.io (Aşama 6'dan sonra, ücretsiz)
- [ ] Dikey kesiti ücretsiz demo olarak yükle
- [ ] Geri bildirim topla

### 5.2 Steam
- [ ] Steamworks hesabı (partner.steamgames.com), vergi ve banka bilgisi
- [ ] Steam Direct ücreti (~100$, oyun belli bir satış gelirine ulaşınca geri ödenir)
- [ ] **Mağaza sayfasını Aşama 6 biter bitmez aç.** Satışı wishlist sayısı belirler. Ne kadar erken, o kadar iyi.
- [ ] Steam kuralları: ücret ödendikten sonra en az 30 gün geçmeli, sayfa en az 2 hafta "Coming Soon" görünmeli
- [ ] Demo hazırla, **Steam Next Fest**'e katıl (indie oyunlar için en büyük wishlist kaynağı)
- [ ] Mağaza: İngilizce açıklama, kapsül görseller, 5+ ekran görüntüsü, 30-60 sn fragman
- [ ] Etiketler: Auto Battler, Roguelite, Strategy, Fantasy, Isometric, Singleplayer
- [ ] Fiyat: bu tür için genelde 5-15$
- [ ] Godot'ta Windows export → SteamPipe ile yükle → test branch'te dene → yayınla
- [ ] **GodotSteam isteğe bağlı.** Sadece başarım (achievement) ve bulut kayıt istersen gerekir. Oyun Steam'de onsuz da satılabilir.

---

## 6. Öneriler

1. **Kapsamı küçük başlat.** 10 krallık × 5 birim = 50 birim + 10 boss demek. Aşama 6'ya kadar sadece 3 krallıkla çalış. Eğlenceli olmayan bir oyuna 7 krallık eklemek onu kurtarmaz.
2. **Grafiği sona bırak.** Aşama 8'e kadar renkli karelerle çalış. Elf = yeşil, Ork = kırmızı. Önce oyun eğlenceli olsun.
3. **Sprite'ları sadece sağ/sol yöne çiz.** İzometrik 8 yön, çizim işini dört katına çıkarır.
4. **Fizik motoru kullanma.** Yüzlerce asker için `CharacterBody2D` ve çarpışma kasar. Bölük tabanlı basit matematik yeter.
5. **Denge aracını erken yaz** (Aşama 3). 10 krallığı elle oynayarak dengelemek imkânsız.
6. **Her gün Git commit'i at.** Bir şey bozulduğunda geri dönebilmek hayat kurtarır.
7. **Benzer oyunları oyna ve not al.** Ana referans **9 Kings**: kart seçimi, ızgara, tur akışı, menülerin sadeliği. Steam yorumlarındaki şikâyetleri de oku (geç oyunda ani zorluk artışı, seviye 3 sınırı); aynı hataları yapmamak için. Diğerleri: Super Auto Pets, The Bazaar, Mechabellum, Hearthstone Battlegrounds. Neyin seni "bir tur daha" oynattığını yaz.
8. **Geliştirme sürecini paylaş.** Kısa savaş videoları (TikTok, YouTube Shorts, Reddit r/godot, r/IndieDev) Steam sayfası için wishlist toplar. Yüzlerce askerin çarpışması videoda iyi görünür.

---

## 7. Kontrol listesi

- [ ] Kurulum ve Git tamam
- [ ] İzometrik harita ve kamera çalışıyor
- [ ] İki bölük savaşıyor
- [ ] Roller ve denge aracı hazır
- [ ] Kart seçimiyle koşu döngüsü çalışıyor
- [ ] Kombolar ve bölük birleşme çalışıyor
- [ ] 3 krallıkla 20 savaşlık koşu oynanıyor (dikey kesit)
- [ ] 5 kişiye oynatıldı, "eğlenceli" onayı alındı
- [ ] Kayıt ve krallık kilidi açma çalışıyor
- [ ] 10 krallık tamam
- [ ] Grafik ve ses tamam
- [ ] Menüler ve TR/EN çeviri tamam
- [ ] Steam sayfası yayında, wishlist toplanıyor
- [ ] Demo / Next Fest
- [ ] Yayın

---

## 8. Bir sonraki adım

Aşama 0: Godot'u indir, `Fetih` projesini oluştur, klasörleri aç, Git'i bağla. Bitince ekranda ne gördüğünü yaz. Ardından Aşama 1'de izometrik haritayı birlikte kuracağız.
