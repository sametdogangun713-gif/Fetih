# Fetih — mağaza metni ve yayın kontrol listesi

Steam ve itch.io sayfası için hazır metinler. Ana mağaza dili İngilizce; Türkçesi de aşağıda.

> **Not:** `ekran_goruntuleri/` içindeki görüntüler geçici sprite'larla alındı (1920x1080, oyunun 640x360 görüntüsünün 3 katı). Gerçek çizimler gelince yeniden alınmalı:
> `godot --path Fetih -s res://tools/battle_showcase.gd --write-movie out.png --quit-after 260 -- en notips zoom run <krallık 0-9> <savaş sayısı>`

## Sayılarla oyun (sayfada kullanılabilir)

- 10 krallık, 40 birlik, 10 boss, 30 ferman
- 7 rol, taş-kağıt-makas karşılık tablosu
- 20 savaşlık koşu, her 5. savaşta boss
- Kalıcı ilerleme: Şan, 4 kalıcı geliştirme, kilitli krallıklar
- Türkçe ve İngilizce

## English

**Short description** (Steam, en fazla 300 karakter)

> Build an army, not a deck. Pick one of ten kingdoms and conquer twenty battles in a row. Your squads fight on their own: you choose the formation, the reinforcements and the royal edicts. Every victory hands you the spoils of the kingdom you just crushed.

**About this game**

Fetih is a single-player, offline auto-battler roguelite about conquest.

Choose a kingdom and march through twenty battles. Before each fight you arrange up to five squads on a small grid: who holds the front line, who shoots from the back. Then the battle plays itself — hundreds of soldiers clash, arrows fly, cannons roar.

After each victory you pick a card from the kingdom you defeated: a new unit, an upgrade for one of your squads, or an edict that lasts the whole run. Beat the elven queen and her archers may join you. Crush the undead and your own fallen may rise again.

- **10 kingdoms, 40 units, 10 bosses.** Humans, elves, orcs, golems, centaurs, demons, dwarves, mudfolk, undead and slimes, each with its own mechanic: burning, slowing, regeneration, revival, splitting.
- **Counters matter.** Spearmen stop cavalry, cavalry runs down archers, mages melt armor. Read the enemy army and plan your formation.
- **No deck, no clutter.** Every card you pick applies immediately.
- **Three lives.** A lost battle costs a life and is never replayed. Win the Grand Conquest in battle 20 to finish your run.
- **Permanent progress.** Earn Glory, unlock kingdoms by taking their seals, buy upgrades for future runs.
- **Plays offline.** No account, no internet required.

**Tags:** Auto Battler, Roguelite, Strategy, Fantasy, Isometric, Singleplayer, Pixel Graphics

## Türkçe

**Kısa açıklama**

> Deste değil, ordu kur. On krallıktan birini seç ve art arda yirmi savaşı fethet. Bölüklerin kendi savaşır: sen dizilişi, takviyeleri ve kraliyet fermanlarını seçersin. Her zafer, az önce ezdiğin krallığın ganimetini getirir.

**Oyun hakkında**

Fetih, tek oyunculu ve çevrimdışı bir fetih temalı auto-battler roguelite.

Bir krallık seç ve yirmi savaş boyunca ilerle. Her savaştan önce en fazla beş bölüğü küçük bir ızgaraya dizersin: ön cepheyi kim tutacak, arkadan kim vuracak. Sonra savaş kendi kendine oynar: yüzlerce asker çarpışır, oklar uçar, toplar gürler.

Her zaferden sonra yendiğin krallığın kartlarından birini seçersin: yeni bir birlik, bir bölüğüne yükseltme ya da koşu boyu süren bir ferman.

- **10 krallık, 40 birlik, 10 boss**, her krallığın kendi mekaniği: yanma, yavaşlatma, onarım, diriliş, bölünme.
- **Karşılıklar önemli:** mızrakçı süvariyi durdurur, süvari okçuyu ezer, büyü zırhı deler.
- **Deste yok:** seçtiğin kart hemen uygulanır.
- **Üç can:** kaybedilen savaş bir can götürür ve tekrar oynanmaz. 20. savaştaki Büyük Fetih'i kazanmadan koşu bitmez.
- **Kalıcı ilerleme:** Şan kazan, mühürlerle krallık aç, sonraki koşular için geliştirme al.
- **Çevrimdışı:** hesap ve internet gerekmez.

## Sistem gereksinimleri (tahmin, gerçek donanımda doğrulanmalı)

Varsayım: Godot 4.7 Compatibility (OpenGL 3.3) çiziciyle 640x360 piksel sanat; ağır grafik yok.

- **İşletim sistemi:** Windows 10 / 11, 64 bit
- **İşlemci:** 2 GHz çift çekirdek
- **Bellek:** 2 GB RAM
- **Ekran kartı:** OpenGL 3.3 destekli
- **Depolama:** 200 MB

## Yayın kontrol listesi

Kodda hazır olanlar:

- [x] Windows export ayarı (`Fetih/export_presets.cfg`, çıktı `Fetih/build/windows/Fetih.exe`, `tools/` pakete girmez)
- [x] Uygulama ikonu (geçici: `Fetih/icon.png`, `Fetih/icon.ico`, `tools/build_icon.gd`)
- [x] Sürüm numarası (`project.godot` → `config/version`, ana menünün altında görünür)
- [x] Türkçe + İngilizce, ayarlar, duraklatma, ipuçları
- [x] 8 ekran görüntüsü (geçici sprite'larla)

Senin yapman gerekenler:

- [ ] **Export şablonlarını kur** (Godot editörü → Editör → Export Şablonlarını Yönet → İndir ve Kur, 4.7.2). Sonra: `godot --headless --path Fetih --export-release "Windows Desktop" build/windows/Fetih.exe`
- [ ] Gerçek sprite'lar (`UnitData.sprite_sheet`) ve gerçek ses/müzik (`assets/audio/`, aynı dosya adları)
- [ ] Gerçek ikon ve Steam kapsül görselleri (boyutlar Steamworks belgesinden doğrulanmalı; bilinen: header 920x430, small 462x174, main 1232x706, vertical 748x896, library 600x900 + hero 3840x1240 + logo)
- [ ] 30-60 sn fragman (savaş kaydı: `--write-movie out.avi`)
- [ ] 5 kişiye oynat (Aşama 6 kontrol noktası hâlâ açık)
- [ ] itch.io: ücretsiz demo sayfası
- [ ] Steamworks hesabı, Steam Direct ücreti, mağaza sayfası ("Coming Soon" en az 2 hafta), Next Fest demosu
- [ ] Gizlilik: proje gizli; build'leri yalnız sen yükle (repo hiçbir uzak depoya gönderilmez)
