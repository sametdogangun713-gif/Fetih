# Oyun Tasarım Dokümanı (GDD) — Taslak v0.2

> Çalışma adı: **Fetih** (sonra değişebilir)
> Tür: Offline, tek oyunculu, fetih temalı auto-battler roguelite
> Motor: Godot 4 (2B, izometrik görünüm, piksel sanat)
> Platform: Windows PC (Steam / itch.io)
> Ana referans (oynanış ve grafik): **9 Kings**

## 0. 9 Kings'ten farkımız

9 Kings'te de kral seçilir, her tur kart seçilir, kartlar ızgaraya yerleştirilir, savaş otomatiktir ve yenilen kralın destesinden kart alınır. Yani "yenilen krallığın birlikleri havuza girer" fikri 9 Kings'te zaten var. Bizim farklarımız:

1. **Kitle ordusu:** Kart "1 birim" değil, "20 Elf Okçusu". Ekranda yüzlerce asker çarpışır. Fragman ve videoda en çok dikkat çekecek şey bu.
2. **Rol uzmanlığı:** Her krallık bir rolde oyunun en iyisi (Elf okçu, Golem tank…). Ordu kurmak "hangi krallıktan hangi rolü alayım" bulmacasına dönüşür.
3. **Ordu ızgarası = savaş dizilişi:** Izgarada nereye koyduğun, savaş alanında nerede duracağını belirler (ön sıra = ön cephe).
4. **Sabit fetih hedefi:** 20 savaş ve kesin bir sonuç. Sonsuz mod değil.

**(Öneri)** ile işaretli maddeler senin söylediklerinden değil, benim önerimdir. İstemediğini çıkarırız.

---

## 1. Tek cümlede oyun

Krallığını seç, 20 savaş boyunca her zaferden sonra ordunu kartlarla büyüt, rakip krallıkları ve onların boss'larını yenerek fethi tamamla. 10 krallığın 7'sini açmak oyunun uzun vadeli hedefi.

---

## 2. Kamera ve görünüm

- Haritaya bir küpün **sol üst ön köşesinden** çapraz bakılıyor. Bu, klasik **izometrik görünüm**dür.
- Zemin karoları baklava (elmas) şeklinde: **64x32 piksel** izometrik karo (Godot `TileMapLayer`, Tile Shape = Isometric).
- Oyuncu ordusu haritanın **sol alt** yarısında, rakip ordu **sağ üst** yarısında başlar. İki ordu çapraz hat boyunca birbirine yürür.
- **(Öneri) Çizim yükünü azaltma hilesi:** Birimler sadece **sağa ve sola** bakar (sprite `flip_h` ile çevrilir). 8 yönlü izometrik animasyon çizmek 10 krallık için yıllar sürer. Kingdom Rush gibi oyunlar da bu yöntemi kullanır.
- Derinlik sıralaması için `y_sort_enabled` açık olur (aşağıdaki birim önde çizilir).
- **Grafik tarzı: piksel sanat.** Asker sprite'ları küçük olmalı (16x16 veya 24x24 piksel), çünkü ekranda yüzlerce asker olacak. Boss'lar daha büyük (48x48 veya 64x64).
- Oyun düşük çözünürlükte çizilip büyütülür: Project Settings → Display → Window → Stretch Mode = `viewport`, Texture Filter = `Nearest` (piksellerin bulanıklaşmaması için).
- Renk paleti: tüm oyun için tek bir sınırlı palet seç (ör. Lospec.com'dan 32-64 renk). Farklı kaynaklardan gelen çizimler böyle uyumlu görünür.

---

## 3. Krallıklar (10 adet)

Her krallığın bir **"en iyisi"** var. Diğer rolleri de olabilir ama o rolde kimse onu geçemez.

| # | Krallık | En iyi olduğu rol | Özel mekanik | Başlangıçta |
|---|---|---|---|---|
| 1 | İnsanlar | Mızrakçı | Dengeli, süvariye karşı en sağlam | Açık |
| 2 | Elfler | Okçu | Uzun menzil, kritik vuruş | Açık |
| 3 | Orklar | Savaşçı (yakın dövüş) | Can azaldıkça hasar artar (öfke) | Açık |
| 4 | Golemler | Tank | Çok yüksek zırh, çok yavaş | Kilitli |
| 5 | İblisler | Büyücü (alan hasarı) | Ateş hasarı, yanma etkisi | Kilitli |
| 6 | Slime'lar | Sürü | Ölünce iki küçük slime'a bölünür | Kilitli |
| 7 | Çamurlar | Kontrol | Düşmanı yavaşlatır, zamanla kendini onarır | Kilitli |
| 8 | Ölüler | Diriliş | Ölen birimler bir kez iskelet olarak kalkar | Kilitli |
| 9 | Cüceler | Kuşatma / topçu | Mancınık, top: çok yavaş ama büyük alan hasarı | Kilitli |
| 10 | Kentaurlar | Süvari | En hızlı birimler, ilk çarpışmada ağır hasar | Kilitli |

### Roller ve karşılıklar
6 temel rol: **Savaşçı, Mızrakçı, Tank, Okçu, Büyücü, Süvari**.

- Mızrakçı > Süvari (hızlı gelen süvari mızrağa çarpar)
- Süvari > Okçu (arka sıraya dalar)
- Okçu > Büyücü (büyücünün canı az, menzili kısa)
- Büyücü > Tank (büyü zırhı deler)
- Tank > Savaşçı (savaşçı zırhta tıkanır)
- Savaşçı > Mızrakçı (yakın dövüşte mızrak hantal)

Avantaj **%25 civarı hasar bonusu** olmalı, kesin yenme değil. Sayı ve kalite her zaman bir şeyi değiştirebilmeli.

Her krallıkta 6 rolün hepsi olmak zorunda değil. Her krallık **4-5 birim + 1 boss** yeterli.

### Rol mekanikleri (Aşama 3'te uygulandı)
- **Zırh:** hasarı `zırh / (zırh + 5)` oranında azaltır. 1 zırh %17, 3 zırh %38, 5 zırh %50.
- **Büyücü:** zırhı yok sayar; hedefin 1.2 karo yakınındaki diğer düşman bölüklerine yarım hasar verir.
- **Süvari:** önce okçu ve büyücüleri hedefler; en az 2 karo koşup yaptığı ilk vuruş 2 kat (hücum).
- **Mızrakçı:** hücumu karşılar; süvari mızrakçıya hücum bonusu alamaz.
- **Okçu / büyücü:** yakın dövüşe yakalanırsa hasarı yarıya düşer.
- **Maliyet:** her birliğin asker başına güç puanı var. 100 puanlık bölük, maliyeti 5 olan birlikten 20, maliyeti 12 olan Şövalye'den 8 asker eder.

### İlk 12 birlik
Değerler `Fetih/data/units/*.tres` dosyalarında; denge raporu için `tools/run_balance_test.ps1`.

| Krallık | Savaşçı | Mızrakçı | Tank | Okçu | Büyücü | Süvari |
|---|---|---|---|---|---|---|
| İnsanlar | Kılıçlı Piyade | **İnsan Mızrakçı** | | Arbaletçi | | Şövalye |
| Elfler | Kılıç Dansçısı | | | **Elf Okçusu** | Orman Büyücüsü | Geyik Binicisi |
| Orklar | **Ork Savaşçısı** | | Kalkanlı Ork | | Ork Şamanı | Kurt Binicisi |

Kalın olan, krallığın uzmanlık birliği.

---

## 4. Ordu ve kart sistemi

### Kart seçimi
- Her savaştan sonra **3 kart sunulur, 1 tanesi seçilir.**
- **(Öneri)** Kalıcı yükseltmeyle sunulan kart sayısı 4'e, sonra 5'e çıkar. Böylece "3 veya 5 kart" fikrin ilerleme ödülüne dönüşür.
- Deste yok. Seçilen kart **anında ordunun parçası olur.**

### Kart türleri (Aşama 5'te uygulandı)
1. **Birlik kartı:** "20 Elf Okçusu" gibi; orduya 100 güçlük yeni bölük ekler. Orduda aynı birlik varsa o bölüğe **Takviye** olur.
2. **Yükseltme kartı:** Ordundaki belirli bir bölüğe bir seviye: **Saldırı**, **Savunma** veya **Takviye** (asker sayısı).
3. **Ferman kartı:** Savaşılan krallığın kalıcı ordu bonusu. Her krallığın 3 fermanı var (aşağıda).

Kazanınca 3 kart: 1. birlik, 2. yükseltme, 3. rastgele (%35 birlik, %30 yükseltme, %35 ferman). Kaybedince ilk ikisi.

### Hangi krallığın kartları gelir? (TEMEL KURAL)
- **Birlik kartları ve fermanlar, o savaşta karşılaşılan krallıktan gelir.** Elflerle savaştıysan Elf birlikleri ve Elf fermanları gelir. Yükseltme kartları kendi ordundaki bölükler içindir.
- Kendi krallığın, koşu başındaki başlangıç ordunu verir.
- Sonuç: rakiplerin sırası, ordunun nasıl şekilleneceğini belirler. Bu yüzden sıradaki rakipler hazırlık ekranında önceden gösterilir.

### Komuta sınırı ve seviyeler
- Orduda en fazla **5 bölük** olur. Ordu doluyken yeni birlik kartı, seçilen bir bölüğün yerine geçer (o bölük ve seviyeleri kaybolur).
- Her bölüğün **5 seviyesi** var: Sv 1 taban, her yükseltme kartı +1 seviye.
- Bütün sayılar `Fetih/scripts/data/balance.gd` dosyasında.

### Sayıların matematiği
Savaşta askerler toplu vuruştuğu için **Lanchester kare yasası** geçerli: bölüğün savaş gücü ~ asker² × can × hasar/sn. Buradan "güç" (eşdeğer bütçe) ~ asker × kök(can × hasar/sn) çıkar. Her yükseltme seviyesi gücü taban bütçenin **%40**'ı kadar artırır (k = o türdeki seviye):

| Yükseltme | Etkisi | Güç |
|---|---|---|
| Takviye | asker × (1 + 0.4k) | × (1 + 0.4k) |
| Saldırı | hasar × (1 + 0.4k)² | × (1 + 0.4k) |
| Savunma | alınan hasar ÷ (1 + 0.4k)² | × (1 + 0.4k) |

- Sv 5'te tek türe yığılan bölük ×2.6, karışık (2+1+1) ×3.5 güçlü. Farklı türler çarpılarak birleşir; karışık yükseltmek ödüllendirilir.
- Simülasyonla doğrulandı: üç tür eşit değerde (±%10 ölçüm gürültüsü içinde).
- Simülasyonun düzelttiği iki şey: saldırı **hızı** artışı formülden az değerli çıktı (toplu vuruşta yavaş vuranın gizli avantajı), bu yüzden Saldırı sadece hasarı artırır. Savunma da can yerine dayanıklılık artırır (yüksek canlı yaralı askerler fazla uzun vuruşuyordu).

### Rakip gücü (zorluk)
- Rakip gücü = beklenen oyuncu gücü × zorluk (Aşama 6'da 20 savaş için %85 sabit; aşağıda "Zorluk").
- Beklenen oyuncu gücü: ilk kartlar yeni bölük (+100), 5 bölük dolunca yükseltme (+44).
- Rakip de önce bölük kazanır (2, 3, 4, 5), sonra kalan gücü rastgele yükseltmelere harcar.
- Aşama 5 ölçümü (10 savaş) eskidi; güncel sonuçlar bölüm 5'te.

### Fermanlar
| Krallık | Ferman | Etki |
|---|---|---|
| İnsanlar | Kraliyet Sancağı | Ön cephedeki bölüklerin hasarı +%30 (konumlandırma) |
| İnsanlar | Mızrak Duvarı | Mızrakçı ve tanklar %30 az hasar alır |
| İnsanlar | Kraliyet Demirhanesi | Bütün bölüklerin zırhı +1 |
| Elfler | Keskin Oklar | Okçu ve büyücü hasarı +%40 |
| Elfler | Rüzgâr Okları | Arka saftaki okçu ve büyücülerin menzili +1 (konumlandırma) |
| Elfler | Orman Adımı | Bütün bölükler %30 hızlı yürür |
| Orklar | Savaş Davulları | Bütün bölüklerin saldırı hızı +%15 |
| Orklar | Kurt Sürüsü | Süvari hücumu x3 |
| Orklar | Kan Öfkesi | Savaşçı hasarı +%40 |

### Ordu ızgarası (yerleştirme)
9 Kings'teki krallık ızgarasının ordu versiyonu.

- Her **kare bir bölük** taşır. Yeni bölük role uygun boş kareye girer; sürükle-bırak ile taşınır.
- Izgara **3x3**, ordu en fazla **5 bölük**: 4 boş kare her zaman var, diziliş bir karar. (Eski fikir "ızgara 5x5'e büyüsün" yerine kullanıcı kararıyla 5 bölük sınırı.)
- Bazı fermanlar satıra bağlı (ön cephe / arka saf): konumlandırma güç kazandırır.
- Izgaranın **üst satırı ön cephe**, alt satırı arka saftır. Tankı öne, okçuyu arkaya koymak oyuncunun kararı.
- Savaş başlarken ızgara izometrik savaş alanına aynen aktarılır: her bölük, ızgaradaki yerine karşılık gelen noktadan savaşa girer.
- Savaşlar arasında bölükler sürükle-bırak ile yer değiştirebilir.
- **Komşuluk bonusu (Öneri):** Bazı birimler yanındakileri güçlendirir. Örnek: İnsan Sancaktarı yan karelerdeki bölüklere +%10 hasar; Golem Kalkanı arkasındaki bölüğe hasar azaltma. Yerleştirmeyi gerçek bir bulmacaya çevirir.

### Bölük birleşme
- Aynı birlik kartını tekrar seçersen yeni bölük açılmaz, mevcut bölüğe **Takviye** seviyesi gelir (20 → 28 asker).
- Seviye sınırı 5 (9 Kings'teki 3 sınırı şikâyet konusuydu; 5 seviye ve karışık yükseltme geç oyunda seçenek bırakır).

---

## 5. Koşu yapısı (bir oyun)

- Koşu = **20 savaş** (Aşama 6'da uygulandı).
- **5., 10., 15. savaş:** rakip krallığın **boss'u** ordusunun başında; boss ordusu o krallığın 3 fermanını da kullanır.
- **20. savaş: Büyük Fetih.** O savaşın rakip krallığının boss'u, rakip gücü +%10. **Kazanmak şart:** kaybedersen canın kalsa bile fetih yarım kalır.
- Boss yenilince **+1 can** (en fazla 3) ve 3. kart mutlaka o krallığın fermanı.
- Diğer savaşlar: rastgele rakip krallıkların normal orduları. Hazırlık ekranındaki koşu haritası 20 savaşın tamamını gösterir.

### Boss'lar
Boss tek askerli dev kahramandır; maliyeti 150 (1.5 bölük). Tek asker öldükçe vuruşu azalmadığı için Lanchester formülü değişir: boss'un can × hasarı, rakibin asker² × can × hasarının yarısı kadar olmalı. Değerler simülasyonla (`tools/boss_test.gd`) %50 kazanma noktasına ayarlandı.

| Krallık | Boss | Rol | Can | Hasar | Özel |
|---|---|---|---|---|---|
| İnsanlar | Kral Aldric | Tank | 435 | 18.5 | Zırh 4, alan hasarı |
| Elfler | Kraliçe Sylwen | Büyücü | 265 | 30 | Menzil 4.5, zırh deler, geniş alan hasarı |
| Orklar | Savaş Ağası Grukk | Savaşçı | 325 | 24 | Hücum x2, alan hasarı, hızlı |

Her boss'un karşılığı var (örn. Sylwen süvariye zayıf); boss'a göre ordu kurmak stratejinin parçası.

### Krallık özelliği ve başlangıç ordusu
Her krallık koşuya kendi fermanlarından biriyle başlar (9 Kings'teki kral yetenekleri gibi):

| Krallık | Başlangıç ordusu | Özellik |
|---|---|---|
| İnsanlar | 20 İnsan Mızrakçı, 20 Arbaletçi | Kraliyet Sancağı: ön cephe +%30 hasar |
| Elfler | 20 Elf Okçusu, 13 Orman Büyücüsü | Orman Adımı: ordu %30 hızlı |
| Orklar | 20 Ork Savaşçısı, 14 Kalkanlı Ork | Savaş Davulları: saldırı hızı +%15 |

### Zorluk (Aşama 6 ölçümü)
- Rakip gücü = beklenen oyuncu gücü × %85 (sabit); Büyük Fetih ×1.1.
- 40'ar koşuluk bot testi (`tools/run_test.gd`): kartın güç katkısını hesaplayan bot İnsanlar %58, Elfler %63, Orklar %58 fetih (savaşların %87–92'si kazanılıyor). Rastgele kart seçen bot %3–13.

### Kayıplar
- Ordular her savaşa **tam güçle** girer (9 Kings'teki gibi). Savaşta ölen askerler bir sonraki savaşta geri gelir; kalıcı kayıp yoktur. Ordunun gücü sadece kartlarla değişir.

### Can sistemi
- Oyuncunun **3 canı** var.
- Kaybedilen savaşta 1 can gider. **Savaş tekrar oynanmaz**, sıradaki rakibe geçilir.
- Kaybedersen kart seçimi yine gelir mi? **(Öneri)** Evet ama 2 kart sunulur. Böylece kayıp ordunu çökertmez.
- 3 can biterse koşu biter.

### Savaş akışı
1. **Hazırlık:** Kart seçilir, ordu ızgarasına yerleştirilir, gerekirse bölüklerin yeri değiştirilir. Sıradaki rakibin krallığı önceden gösterilir; oyuncu dizilişini ona göre ayarlar.
2. **Savaş:** Tamamen otomatik. 30-60 saniye sürer. Hız düğmesi: x1 / x2 / x4.
3. **Sonuç:** Kazandın/kaybettin ekranı, sonra kart seçimi.

---

## 6. Kalıcı ilerleme (meta)

- Başta 3 krallık açık: **İnsanlar, Elfler, Orklar.**
- **Krallık açma (Aşama 7'de uygulandı):** Koşuda kilitli bir krallığın boss'unu yenince o krallığın **mührü** düşer. Fethi tamamlarsan (20. savaş) mühür kalıcı olur ve krallık açılır. Koşu kaybedilirse mühür gider.
- **Şan:** kazanılan savaş +2, yenilen boss +5, tamamlanan fetih +25. Kazanılan bir koşu ~85 Şan.
- **Hazine (kalıcı geliştirmeler):**

| Geliştirme | Etki | Fiyat |
|---|---|---|
| Geniş Ganimet | Savaş sonrası +1 kart (2 seviye: 4, sonra 5 kart) | 40, 90 |
| Sağlam Moral | +1 can | 60 |
| Gaziler | Başlangıç bölükleri Sv 2 | 30 |
| Keşif | Koşu başına kart yeniden çekme hakkı (3 seviye) | 20, 35, 50 |

- Hepsi 325 Şan: yaklaşık 4 kazanılmış koşu.
- **Kayıt:** `user://save.json` (Windows: `%APPDATA%\Godot\app_userdata\Fetih`). Yarım kalan koşu kaydedilir; savaş başında da kaydedildiği için çıkıp dönen oyuncu dizilişi değiştirip kaybedilen savaşı tekrar deneyemez.
- Böylece 7 krallığı açmak en az 7 başarılı koşu ister. Oyunun ana hedefi bu olur.
- Ek kalıcı ödüller (Öneri): kart seçim sayısı (+1), başlangıç bölüğü, ekstra can (en fazla 4).

---

## 7. Teknik kararlar

- **Tamamen offline.** Sunucu, hesap, internet yok. Kayıt `user://save.json` dosyasında.
- **Bölük tabanlı simülasyon:** Her bölük tek bir varlık olarak hesaplanır. Toplam can = asker sayısı × asker canı. Hasar aldıkça askerler tek tek düşer ve ekrandan silinir. 20 okçu için 20 ayrı fizik nesnesi yok.
- **Fizik motoru kullanılmaz.** Hareket ve menzil hesabı basit matematikle yapılır (`CharacterBody2D` yok). Yüzlerce birimde bile hızlı çalışır.
- **Deterministik savaş:** Her savaş bir seed ile başlar (`RandomNumberGenerator.seed`). Aynı ordu ve aynı seed her zaman aynı sonucu verir.
- **Veri odaklı:** Birlikler, krallıklar ve kartlar `.tres` kaynak dosyalarında. Denge ayarı kod değil, sayı değişikliği.
- **Otomatik denge testi:** Görüntüsüz çalışan bir script iki orduyu 1000 kez savaştırır, kazanma oranlarını yazar.
- Oyun boyutu hedefi: **200 MB altı.**

### Örnek birlik verisi
```gdscript
# scripts/data/unit_data.gd
class_name UnitData
extends Resource

@export var id: StringName          # "elf_archer"
@export var kingdom: StringName     # "elves"
@export var role: StringName        # "archer"
@export var display_name: String    # "Elf Okçusu"
@export var hp: float = 10.0          # tek askerin canı
@export var damage: float = 3.0
@export var attack_speed: float = 1.0
@export var attack_range: float = 0.25  # karo, bölük kenarları arası
@export var move_speed: float = 1.0
@export var armor: float = 0.0
@export var placeholder_color: Color  # sprite gelene kadar
```
Güncel hali: `Fetih/scripts/data/unit_data.gd`. Sprite alanı Aşama 9'da eklenecek.

---

## 8. Sonraya bırakılanlar

Öncelikli değil, geliştirme sırasında karar verilecek:

1. Komşuluk bonusu olsun mu?
2. Final boss için ayrı bir "büyük kötü" (şimdilik 20. savaşın rakip krallığının boss'u + %10 güç).

## 9. Karar kaydı

- Krallıklar: 10 krallık, tabloya göre (onaylandı)
- Yerleştirme: var, ordu ızgarası (onaylandı)
- Grafik: piksel sanat (onaylandı)
- Ana referans: 9 Kings (onaylandı)
- Kazanılan kartlar, o savaşta karşılaşılan krallıktan gelir (onaylandı, temel kural)
