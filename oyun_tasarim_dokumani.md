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

### Kart türleri
1. **Birlik kartı:** "20 Elf Okçusu", "5 Golem", "40 Slime". Orduya bir **bölük** ekler.
2. **Güçlendirme kartı:** Tek bir bölüğe uygulanır: "Bu bölük +%20 hasar", "Bu bölük ateş oku atar".
3. **Ferman kartı:** Nadir, tüm orduyu etkileyen kalıcı kural (9 Kings'teki kraliyet fermanları gibi): "Süvariler savaşın ilk 5 saniyesinde hasar almaz", "Tüm okçular +1 menzil".

### Hangi krallığın kartları gelir? (TEMEL KURAL)
- **Savaştan sonra sunulan kartlar, o savaşta karşılaşılan krallığın kartlarıdır.** Elflerle savaştıysan 3 Elf kartı gelir ("20 Elf Okçusu" gibi).
- Kendi krallığın, koşu başındaki başlangıç ordunu verir.
- Sonuç: rakiplerin sırası, ordunun nasıl şekilleneceğini belirler. Bu yüzden sıradaki rakipler hazırlık ekranında önceden gösterilir.

### Ordu ızgarası (yerleştirme)
9 Kings'teki krallık ızgarasının ordu versiyonu.

- Her **kare bir bölük** taşır. Kart seçince bölüğü boş bir kareye yerleştirirsin.
- Izgara **3x3** başlar, boss'ları yendikçe büyür: 3x3 → 3x4 → 4x4 → 4x5 → 5x5. Izgara boyutu aynı zamanda **komuta sınırıdır**; ordu sonsuz büyümez.
- Izgaranın **üst satırı ön cephe**, alt satırı arka saftır. Tankı öne, okçuyu arkaya koymak oyuncunun kararı.
- Savaş başlarken ızgara izometrik savaş alanına aynen aktarılır: her bölük, ızgaradaki yerine karşılık gelen noktadan savaşa girer.
- Savaşlar arasında bölükler sürükle-bırak ile yer değiştirebilir.
- **Komşuluk bonusu (Öneri):** Bazı birimler yanındakileri güçlendirir. Örnek: İnsan Sancaktarı yan karelerdeki bölüklere +%10 hasar; Golem Kalkanı arkasındaki bölüğe hasar azaltma. Yerleştirmeyi gerçek bir bulmacaya çevirir.

### Bölük birleşme ve seviye
- Aynı birlik kartını tekrar seçersen yeni kare kullanmaz, mevcut bölük **seviye atlar**: 20 → 40 okçu, daha güçlü askerler.
- En fazla **seviye 3**. (9 Kings oyuncularının bir şikâyeti: seviye 3 sınırı yüzünden geç oyunda az sayıda kare işe yarıyor. Bunu izlemeliyiz; gerekirse seviye 3 bölüklere özel yetenek veririz.)
- Izgara doluysa yeni birlik kartı ancak var olan bir bölüğün yerine konabilir.

---

## 5. Koşu yapısı (bir oyun)

- Koşu = **20 savaş**, 4 perde × 5 savaş.
- **5., 10. ve 15. savaş:** rakip bir krallığın **boss'u** ve ordusu.
- **20. savaş:** büyük fetih savaşı (final boss).
- Diğer savaşlar: rastgele seçilen rakip krallıkların normal orduları.
- Rakip ordular bilgisayar tarafından üretilir: her savaşa bir **ordu bütçesi** verilir, bütçe her turda artar.

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
- **(Öneri) Krallık açma kuralı:** Koşuda kilitli bir krallığın boss'unu yenince o krallığın **mührü** düşer. Koşuyu kazanırsan (20. savaş) mühür kalıcı olur ve krallık açılır. Koşu kaybedilirse mühür gider.
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

1. Final boss (20. savaş) kim? Sabit bir "kötü" mü, yoksa koşuda en güçlü kalan krallık mı?
2. Komşuluk bonusu olsun mu?

## 9. Karar kaydı

- Krallıklar: 10 krallık, tabloya göre (onaylandı)
- Yerleştirme: var, ordu ızgarası (onaylandı)
- Grafik: piksel sanat (onaylandı)
- Ana referans: 9 Kings (onaylandı)
- Kazanılan kartlar, o savaşta karşılaşılan krallıktan gelir (onaylandı, temel kural)
