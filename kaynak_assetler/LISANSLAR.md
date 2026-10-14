# Hazır görsel kaynakları

Bu klasör Godot projesinin (`Fetih/`) dışındadır: Godot içe aktarmaz, export'a girmez.
`Fetih/tools/import_sprites.gd` buradaki dosyalardan `Fetih/assets/sprites/units/<birlik id>.png`
sayfalarını üretir. Hangi birliğin hangi figürü kullandığı o aracın `SPECS` tablosundadır.

Hepsi **CC0 1.0** (kamu malı): ticari kullanım, değiştirme serbest; isim vermek zorunlu değil.
Yine de oyunun jeneriğinde teşekkür etmek iyi olur.

| Klasör | Paket | Yazar | Kaynak | İndirme |
|---|---|---|---|---|
| `puny_characters/` | Puny Characters (orcs included) | Shade | https://opengameart.org/content/puny-characters (ayrıca https://merchant-shade.itch.io/16x16-puny-characters) | 2026-10-14 |
| `puny_monsters/` | PunyMonsters | Shade | https://merchant-shade.itch.io/16x16-puny-characters | 2026-10-14 |
| `dungeontileset_ii/` | 16x16 DungeonTileset II v1.7 | 0x72 (Robert) | https://0x72.itch.io/dungeontileset-ii | 2026-10-14 |

## Sayfa düzenleri (araç bunlara göre keser)

- **Puny Characters:** 768x256, kare 32x32, 8 satır = 8 yön (satır 2 sağa bakar), 24 sütun:
  0-1 durma, 1-4 yürüme, 5-8 kılıç, 9-12 yay, 13-15 asa, 16-18 fırlatma, 19-20 hasar, 21-23 ölüm.
  Ayaklar y=22. `Slime.png` tek satır 15 kare: 0-2 durma, 3-8 zıplama, 9 hasar, 10-14 patlama.
- **PunyMonsters:** 384x256, kare 32x32, 8 satır = 8 yön (satır 2 sağa bakar), 12 sütun:
  0 durma, 1-4 yürüme, 5-8 saldırı, 9-10 hasar. Ölüm yok (araç üretir).
- **DungeonTileset II:** her kare ayrı dosya (`<ad>_idle_anim_f0..3`, `<ad>_run_anim_f0..3`,
  bazılarında tek `<ad>_anim_f0..3`). Figürler sağa bakar. Saldırı ve ölüm yok (araç üretir).
