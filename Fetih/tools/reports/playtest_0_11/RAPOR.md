# Fetih 0.11.0 playtest raporu (grafik 9 Kings)

Tarih: 2026-10-15. Godot 4.7.2. Kod değişikliği yapılmadı; sadece bu klasöre rapor ve ekran görüntüleri yazıldı. Commit yok.

## Özet: test sonuçları

| Test | Sonuç |
|---|---|
| Derleme (`--headless --quit`) | Hata/uyarı yok |
| `field_test` | Hata: 0, tüm kontroller TAMAM |
| `mini_art_test` | Hata: 0 |
| `card_fit_test` | HEPSİ SIĞDI (en yüksek kart 267 px, sınır 272) |
| `save_test` | Tüm kontroller TAMAM. ERROR "Parse JSON failed" kasıtlı bozuk kayıt testinin çıktısı (bilgi, hata değil) |
| `run_test` | Greedy politika: fetih %48–63 (10 krallık, hedef %50–60), savaş kazanma %86–90. Random/first baseline %0–18 |
| `boss_test` | 10 boss × 2 varyant, ortalama %38–61. Hata yok |
| `upgrade_test` | Yükseltme eşitliği: ortalama %45–60. Hata yok |
| Ekran görüntüsü (12 çekim) | Hepsi üretildi, log'da ERROR/WARNING yok, boş/siyah ekran yok |
| `run_balance_test.ps1` | Çalıştırılmadı (bu turun kapsamı dışında) |
| `update_translations.gd` | Çalıştırılmadı (en.po'yu değiştirebilir). en.po'da boş msgstr: 0 |

## Bulgular

**Yüksek:** yok.

**Orta:** yok.

**Düşük**

1. **Dil: savaş alt bilgisi İngilizce modda Türkçe kalıyor (geliştirici modu).** `Fetih/scripts/battle/battle_controller.gd:105` satırında `"Seed: %d   Süre: %.1f sn   (R: tekrar, N: yeni)"` tr() ile sarılmamış. Yalnız `RunState.active` değilken (showcase/test) görünür, oyuncu koşusunda görünmez (satır 103 tr() kullanıyor). Görüntü: `11_en_seed7.png` (alt bar). Düzeltme: satırı tr() ile sar, `en.po`'ya ekle. Oyuncuya etkisi yok.

2. **Okunurluk: Ezici Golem birlikleri (beyaz kümeler) tek tek ayırt edilemiyor.** `02_seed40.png`: beyaz figürler birbirine yapışık, sınırları bulanık. Tasarım/sprite kararı gerekir (`unit_art/` veya `assets/sprites/units/`), bu tur düzeltilmedi.

3. **Kenar kesilmesi (doğrulanamadı):** `04_boss5.png` sol kenarda (yaklaşık x 0–40, y 395–435) kesik turuncu bir nesne var. Kaynağı belirlenemedi (kamp/dekor olabilir).

4. **Olası HUD çakışması:** `07_run7-15.png` sol üst savaş başlığının (x ≈ 0–485) sağ kenarına, üst sıradaki düşman kamp bayrağı (x ≈ 480–512, y ≈ 10–70) yaslanıyor. Hafif örtüşme olabilir; kamp konumu veya HUD genişliği ile ilgili. Doğrulamak için tam çözünürlük kırpma gerekir.

5. **Kapsam eksiği:** İngilizce yalnızca savaş ekranı (`11_en_seed7.png`) yakalandı. Kingdom select, prep, card select, hazine İngilizce yakalanmadı; "çevrilmemiş metin" kontrolü bu ekranlarda yapılmadı.

## Ekran görüntüleri (bu klasörde)

`01_seed7`, `02_seed40`, `03_boss1`, `04_boss5`, `05_boss9`, `06_run3-6`, `07_run7-15`, `08_kingdom_select`, `09_prep`, `10_card_select`, `11_en_seed7`, `12_treasury` (.png)

Göz kontrolünde sorun görülmeyenler: prep ve kart ekranı metinleri sığıyor (kart başlıkları, açıklamalar taşmıyor); kingdom select ve hazine Türkçe ve düzenli; boss etiketleri ve HUD okunuyor; ordular kameradan taşmıyor. Sprite yönü (yanlış yöne bakma) sistematik kontrol edilmedi.
