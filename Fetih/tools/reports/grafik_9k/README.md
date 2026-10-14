# Grafik devrimi (9 Kings görsel dili) — önce / sonra

Tarih: 2026-10-15. Spec: `docs/superpowers/specs/2026-10-15-grafik-devrimi-design.md`,
plan: `docs/superpowers/plans/2026-10-15-grafik-devrimi.md`.

| Görüntü | Önce | Sonra |
|---|---|---|
| Normal savaş (seed 22) | `once/normal.png` | `sonra/normal.png` |
| Boss savaşı (cüceler) | `once/boss.png` | `sonra/boss.png` |
| Geç oyun, kalabalık | - | `sonra/late.png` |
| Hazırlık | `once/prep.png` | `sonra/prep.png` |
| Kart seçimi | `once/cards.png` | `sonra/cards.png` |
| İngilizce savaş | - | `sonra/battle_en.png` |

Ara adım görüntüleri `ara/` altında (her task'ın kendi kontrolü).

## Ne değişti

- **GR1 ayna kamera:** oyuncu sağ altta, rakip sol üstte. Görünmez TileMap ve fare karo vurgusu kalktı.
- **GR2 düz zemin:** biyom başına tek renk, seyrek ot / kum dalgası / taşçık motifi. Karo ve kamuflaj deseni yok.
- **GR3 uzak kamera:** savaş tek bakışta. İlk kare iki ordunun kampını da gösteriyor.
- **GR4 minik birlikler:** `MiniUnitArt`, 16x16 karede ~10-12 px figür, 7 rol silueti, 1 px koyu çerçeve. Takım rengi gövdede: oyuncu altın `f9c22b`, rakip kırmızı `e83b3b`.
- **GR5 bölük görünümü:** sık ve düzgün sıralar, figür başına küçük gölge, sancak yerine küçük sayı.
- **GR6 krallık yapıları:** `BuildingArt` + `KingdomCamp`. Her ordunun arkasında kale/kamp, krallığa özgü imza yapı, parlayan ateş. Ağaç gölgeleri küçüldü, ağaçlar öbek öbek.
- **GR7 efektler:** minik ölçek kıvılcım, toz, mermi; additive parıltı. Ferman aurası, ölü bedenler 2 sn sonra solar.
- **GR8 tema:** `UiKit.theme()` paneller ve düğmeler: koyu kutu, 1 px kenar, keskin köşe, gölge, altın hover.
- **GR9 düzen:**
  - savaşta sol üstte eşleşme etiketi, ince alt şerit
  - tür renkli kart çerçeveleri (birlik krallık rengi, yükseltme altın, ferman mor), üstte büyük resim
  - kart ekranının alt satırı artık ekrana sığıyor (eski hata)

## Doğrulama

- `field_test`, `mini_art_test`: Hata 0. `card_fit_test`: hepsi sığdı.
- `save_test`: hepsi geçti.
- `run_test`, `boss_test`, `upgrade_test`: grafik öncesi çıktıyla birebir aynı (simülasyon değişmedi).

## Açık konular

- **Piksel yazı tipi (GR11):** font indirilmesi kullanıcı onayı bekliyor. `UiKit.FONT_PATH` kancası hazır; `assets/fonts/pixel.ttf` konunca tema kullanır.
- **Hazırlık ekranı:** düzen hâlâ ızgara. Meydan planında (B, C) savaş alanına taşınacak.
- **Aura:** boss savaşında bütün bölükler fermanlı olduğu için hepsinde aura var; ileride sadece seçili bölükte gösterilebilir.
- **Birlik çeşitliliği:** aynı roldeki birlikler sadece vurgu rengiyle ayrılıyor; krallığa özgü küçük ayrıntılar eklenebilir.
