# Grafik devrimi: 9 Kings görsel dili

Tarih: 2026-10-15. Durum: kullanıcı onayladı (sohbette). Öncelik: en yüksek (Meydan sahne
birleştirmesinden ve denge birleşiminden önce).

## Amaç

Savaş alanı ve oyun içi arayüz 9 Kings'in görsel diline geçer: uzaktan bakan izometrik kamera,
sakin düz zemin, minik ve kalabalık birlikler, ordu arkasında krallık yapıları, parlak efektler,
piksel yazı tipli sade arayüz ve türüne göre çerçeveli kartlar.

## Referans gözlemleri (9 Kings Steam ekran görüntüleri, 2026-10-15)

- İzometrik, uzak kamera; harita bütünüyle görünür.
- Birlikler ~8-12 px, koyu çerçeveli siluetler, düzgün sıralar halinde onlarca asker.
- Zemin biyom başına tek düz renk + çok seyrek, düşük kontrastlı motif (kum dalgası, ot tutamı).
  Büyük süsler (ağaç, kaya, sur) alan kenarında.
- Krallık yapıları tıknaz, doygun renkli, koyu çerçeveli, parlayan vurgular.
- Takım rengi çok belirgin (oyuncu altın, rakip mor/kırmızı). Aura halkaları, mermi izleri, parçacık.
- Arayüz köşelerde ve az: sol üst kaynak, üst orta zaman çizelgesi, sağ üst hız, alt orta kartlar.
  Kartlar türe göre renkli çerçeveli, üstte büyük piksel resim. Piksel yazı tipi.

## Kararlar (kullanıcıyla)

| Soru | Karar |
|------|-------|
| Kapsam | Meydan (savaş alanı) + oyun içi arayüz. Ana menü, hazine, ayarlar sonra. |
| Birlikler | Minik kalabalık: ~10-12 px figür, koyu çerçeve, düzgün sıralar |
| Yapılar | Her ordunun arkasında krallığa özgü kale/kamp süsü (sadece görüntü) |
| Yazı tipi | Piksel yazı tipi, Türkçe harf desteği doğrulanmış |
| Sanat kaynağı | Hepsi koddan üretilir, Resurrect 64 paleti (karar: Claude; tutarlılık, lisans) |
| Sıra | Önce grafik (mevcut ekranlar üstünde), sonra Meydan veri ve sahne task'ları |

## Kapsam dışı

- Simülasyon, denge sayıları, asker sayıları (1 asker = 1 figür kalır).
- Ana menü (krallık seçimi), hazine, ayarlar, koşu sonu ekranlarının yeniden çizimi
  (yeni `UiKit` temasını kendiliğinden alırlar; düzenleri değişmez).
- Hazırlık/kart ekranlarının birleşmesi (Meydan spec'i, sonra).

## G1. Kamera ve zemin

- Ayna izometrik (Meydan spec'i A3 aynen): `field_offset_to_world(d) = (32 (d.y - d.x), 16 (d.x + d.y))`,
  oyuncu sağ altta. Görünmez `Ground` TileMapLayer, `Highlight` ve karo yazısı kalkar (A2).
- Kamera: varsayılan yakınlık bütün alanı ve iki ordunun yapılarını gösterir. `BattleCamera.ZOOM_LEVELS`
  `[0.75, 1.0, 1.5, 2.0]`; takip sadece bölükler alanın bir köşesine toplanınca 1.5'e çıkar.
- Zemin (Meydan spec'i A1'in yerine): biyom başına tek düz renk (`BIOMES.ramp[1]`), üstünde
  çok seyrek motif: `ramp[0]` ve `ramp[2]` tonlarında 2-5 px'lik ot tutamı / kum dalgası / taşçık,
  karo başına ortalama 0.3 motif, deterministik. Alan sınırı çizilmez; alan dışında aynı renk
  sürer, kenar ağaç/kaya/sur süsleri seyrekten sıka geçer. Hazırlıkta oyuncu bölgesi çok hafif
  (alfa 0.08) belirir.
- Mevcut `assets/terrain/px/` çimen karoları kullanılmaz; ağaç ve kaya dokuları kalır.

## G2. Minik birlikler

- Yeni `scripts/battle/unit_art/mini_unit_art.gd` (`MiniUnitArt`): role göre 16x16 hücreye
  ~10-12 px figür çizer. Roller: piyade, mızrakçı, okçu, büyücü, atlı, kuşatma, tank (+ boss ayrı).
  - 1 px koyu çerçeve (Resurrect 64 en koyu tonu), gövde takım renginde
    (oyuncu `TEAM_COLORS` altın `f9c22b`, rakip `e83b3b`; mevcut mavi yerine altın, 9 Kings gibi),
    silah/şapka birliğin `placeholder_color` vurgusu.
  - Sayfa biçimi değişmez: 4 satır (durma 2, yürüme 4, saldırı 3, ölüm 4 kare), figür sağa bakar.
- `UnitSprites.sheet_for` önce `MiniUnitArt` kullanır; `assets/sprites/units/*.png` artık
  okunmaz (dosyalar silinmez). Boss'lar mevcut büyük çizimle (~40 px) kalır.
- Formasyon: `SquadView` sütun sayısı asker sayısına göre (`ceil(sqrt(n * 1.6))`), aralık
  figür genişliğine göre (Meydan A4'ün yerine): üst üste binme yok, düzgün sıralar.
- Sancak yerine küçük sayı etiketi (piksel font, takım renginde, bölüğün üstünde);
  boss can çubuğu kalır.
- Takım diski küçülür: figür başına 5x2 px yarı saydam gölge.

## G3. Krallık yapıları

- Yeni `scripts/battle/kingdom_camp.gd` (`KingdomCamp`, `Node2D`): bir ordunun arkasına
  (oyuncu: alanın arka kenarının 1-3 karo dışı; rakip: ayna) 5-7 yapı dizer, y-sort'lu `Units`
  düğümüne `Sprite2D` olarak ekler (ağaçlar gibi).
- Yapılar koddan (`unit_art/building_art.gd`, `BuildingArt`): ortak kit (sur parçası, kule,
  çadır, sancak direği, nöbet ateşi) krallığın `color` / `accent_color` renklerine boyanır,
  + krallık başına bir imza yapı (insanlar taş kale, elfler ağaç kulesi, orklar dikenli kulübe,
  cüceler maden girişi, ölümsüzler mezar taşı kulesi, iblisler ateş sunağı, balçıklar balçık
  kubbesi, çamurlar çamur höyüğü, golemler taş dikilitaş, kentaurlar çadır kampı).
- Nöbet ateşi ve imza yapının bir parçası yavaş parlar (Tween ile `modulate`; CPU hafif).
- Sadece görüntü: simülasyon ve kamera sınırlarına etkisi yok (kamera sınırı yapıları kapsar).

## G4. Efektler

- `BattleFx` ölçeği minik figüre iner: vuruş kıvılcımı 3-5 px, ölüm tozu 4-6 parçacık,
  mermi izi 1 px çizgi + parlak uç, büyü 3 px parlayan top. Hasar sayıları küçük piksel font.
- Fermanın uygulandığı bölüklerin altında krallık renginde hafif aura elipsi (alfa 0.25).
- Boss: mor/kırmızı parıltı (additive `CanvasItemMaterial.BLEND_MODE_ADD`).
- Simülasyona dokunulmaz; ayarlar (vuruş flaşı, sarsıntı kapatma) aynen geçerli.

## G5. Arayüz teması

- Piksel yazı tipi: aday Pixel Operator (CC0) ya da monogram-extended (CC0). Seçim ölçütü:
  cmap'te Ğ ğ (U+011E-011F), İ ı (U+0130-0131), Ş ş (U+015E-015F), Ç ç Ö ö Ü ü. Lisans
  `kaynak_assetler/LISANSLAR.md`'ye yazılır. Font `Fetih/assets/fonts/` altına, Nearest,
  antialias kapalı, tam sayı boyutlar (font tasarım boyutunun katları).
- `UiKit.theme()`: varsayılan font bu font; panel `StyleBoxFlat` koyu (`COLOR_PANEL`), 1 px açık
  kenar, köşe yarıçapı 0, 2 px gölge. Düğmeler aynı dil, üstüne gelince altın kenar.
- Üst şerit (savaş ve hazırlık): sol üst güç/can, üst orta "Savaş n / 20" + koşu haritası şeridi,
  sağ üst hız ve duraklatma. Alt şerit sadece savaşta, ince.
- Kartlar: tür rengi çerçeve (birlik: krallık rengi, yükseltme: altın, ferman: mor), üst yarıda
  büyük piksel resim (birlik için `MiniUnitArt` figürü 4x, yükseltme/ferman için ikon), altta ad ve
  kısa metin. Kart seçimi animasyonları aynen.
- Sonuç paneli aynı çerçeve dili.

## Test ve kabul

- Simülasyon değişmez: `run_test.gd`, `boss_test.gd`, `upgrade_test.gd` çıktıları grafikten önceki
  ile aynı.
- `tools/field_test.gd` (Meydan planı T1 ile ortak): ayna dönüşüm gidiş-dönüş, zemin motif
  yoğunluğu, formasyonda figür çakışması yok (komşu figür merkezleri arası >= figür genişliği x 0.7).
- `tools/font_test.gd`: Türkçe harflerin her biri fontta glif olarak var (`Font.has_char`).
- `tools/sprite_preview.gd`: bütün birliklerin yeni minik sayfaları tek görüntüde; her rol
  siluetle ayırt edilir (gözle onay).
- Ekran görüntüleri `Fetih/tools/reports/grafik_9k/` altında önce/sonra: hazırlık, normal savaş,
  boss savaşı, kart seçimi, sonuç paneli; İngilizce bir tane.
- Performans: `perf_test.gd -- only=battle5,boss secs=4` ortalama FPS önceki ile aynı ya da iyi.

## Meydan spec'i ile ilişki

- Meydan A1 (zemin) ve A4 (top aralığı) bu spec'in G1 ve G2'siyle değişir.
- Meydan A2, A3 aynen G1'e alınır.
- Meydan B ve C (serbest yerleşim, tek sahne) bu işten sonra, yeni temayla yapılır.
