# Görsel yön A (tutarlı piksel) - önce / sonra

Kareler 1920x1080 (3x). `notips` sonekli olanlarda ilk ipucu penceresi kapalı. Komutlar:
`battle_showcase.gd --write-movie f.png --quit-after 40 -- 22` (normal), `-- boss 1` (boss),
`--quit-after 8 -- scene res://scenes/run/prep.tscn` (hazırlık).

| Senaryo | Önce | Sonra |
|---|---|---|
| Normal savaş (seed 22) | once/normal.png, once/normal_notips.png | sonra/normal.png, sonra/normal_notips.png |
| Boss (Dağ Kralı Thrain) | once/boss.png, once/boss_notips.png | sonra/boss.png, sonra/boss_notips.png |
| Hazırlık ekranı | once/prep.png, once/prep_notips.png | sonra/prep.png, sonra/prep_notips.png |
| Sonuç paneli (koşu, boss 1, x4) | - | sonra/result_run.png |

"Önce" notips kareleri `eca6aca` çıkışından alındı (ayrı kopya), ipuçlu kareler orijinal ölçümdür.

## Kapsam durumu

1. Resurrect 64: TAMAM. `assets/palette/resurrect-64.hex` (SpritePalette.HEX'ten). `import_sprites.gd` sayfaları
   OKLab eşlemesiyle palete indirir ve raporlar: palet dışı piksel 152113 -> 0 (34 sayfa, kontur #1c1612 istisna).
2. Piksel zemin: TAMAM. `tools/build_ground.gd` -> `assets/terrain/px/` (biyom başına sayfa, 64x32 karo, 0.34x ağaç,
   palet dışı 0). `GroundArt` Nearest, tam sayı konum. BIOMES'a `ramp` (3 palet rengi) eklendi; `tint` yalnız süs boyar.
   Eski HD zemin/ağaç dokuları projeden silindi (kaynak `kaynak_assetler/`de duruyor).
3. Krallık renkleri: TAMAM. `KingdomData.accent_color`; 10 `.tres` belge 4.3 tablosuna göre (İblis `#FF7A2A`).
   Hiçbir ana renk mavi (202-232°) ya da kırmızı (348-18°) bandında değil. Vurgu: kart üstünde ve krallık seçim
   ayrıntısında 3 px ana + 1 px vurgu şeridi (`UiKit.kingdom_strip`).
4. B10 kuşatma: TAMAM. `unit_art/siege_art.gd`: Cüce Topçusu pirinç namlulu top (yatay siluet), Golem Kaya Fırlatan
   taş mancınık (yükselen kol + kaya). Not: bu dalda siege birlikleri aslında silahsız insansı çiziliyordu (tahta araba
   yoktu). Boss Thrain taçlı insansı kaldı (isteğe göre sonra ayrı çizilebilir).
5. B11 HUD: TAMAM. Alt bilgi şeridi (yarı saydam koyu + 1 px altın çizgi); sonuç başlığı + "Devam" ekran ortasında
   çerçeveli panelde, `_pop_result` Tween korunur (panel yerleşimi için 1 kare beklenir).
