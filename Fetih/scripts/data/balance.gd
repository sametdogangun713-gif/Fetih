class_name Balance
## Oyunun ekonomi ve ilerleme sayıları tek yerde.
##
## GÜÇ BİRİMİ: "eşdeğer bütçe". 100 = taban bir bölük (ör. 20 savaşçı, 8 şövalye).
##
## Neden bu formüller: savaşlarımızda bütün askerler aynı anda vuruşur. Böyle savaşlar
## Lanchester kare yasasına uyar: bir bölüğün savaş gücü ~ asker² x can x hasar/sn.
## Eşdeğer bütçe asker sayısıyla doğru orantılı olduğu için:
##     eşdeğer bütçe ~ asker x kök(can çarpanı x hasar/sn çarpanı)
## Örnek: asker +%40 gücü %40 artırır; ama hasar +%40 sadece kök(1.4) = %18 artırır.

const RUN_LENGTH := 20  ## Bir koşudaki savaş sayısı.
const BOSS_EVERY := 5  ## Her 5. savaş boss savaşı (5, 10, 15, 20). Sonuncusu Büyük Fetih.
## Boss savaşında rakip gücü bu kadar artar; boss ordusu krallığın fermanlarını da kullanır.
const BOSS_POWER_MULT := 1.0
const FINAL_POWER_MULT := 1.1  ## Büyük Fetih (son savaş).
const BOSS_LIFE_REWARD := 1  ## Boss yenilince geri gelen can (en fazla START_LIVES).
const START_LIVES := 3
const GRID_SIZE := Vector2i(3, 3)
const MAX_SQUADS := 5  ## Komuta sınırı: orduda en fazla bu kadar bölük.
const SQUAD_BUDGET := 100.0  ## Bir birlik kartının bütçesi.

const MAX_LEVEL := 5
## Her seviye, seçilen türde bölüğün gücünü taban bütçesinin %40'ı kadar artırır.
## Üç tür, yukarıdaki formüle göre eşit değerdedir (k = o türdeki seviye sayısı):
##   Takviye: asker x(1 + 0.4k)                    -> güç x(1 + 0.4k)
##   Saldırı: hasar x(1 + 0.4k)^2                  -> güç x(1 + 0.4k)
##   Savunma: alınan hasar / (1 + 0.4k)^2          -> güç x(1 + 0.4k)
## Simülasyon ölçümünden çıkan iki düzeltme:
## - Saldırı hızı değil hasar artar: askerler toplu vuruş yapar; yavaş vuran bölük her vuruşta, son
##   vuruştan beri eksilen askerlerini henüz saymadan vurur. Hız artışı formülden az değerli çıktı.
## - Savunma can değil dayanıklılık artırır: asker başına can artınca yaralı askerler daha uzun
##   "hayatta" sayılıp vurmaya devam eder; Sv5 savunma formülden fazla değerli çıktı.
## Farklı türler çarpılarak birleşir; bu yüzden karışık yükseltmek tek türe yığmaktan biraz güçlüdür
## (Sv 5'te: tek tür x2.6, 2+1+1 karışım x3.5).
const UPGRADE_STEP := 0.4

const CARDS_ON_WIN := 3
const CARDS_ON_LOSS := 2
## Kazanınca gelen 3. kartın türü: birlik / yükseltme / ferman olasılıkları.
const THIRD_CARD_UNIT := 0.35
const THIRD_CARD_UPGRADE := 0.30

## Rakip gücü = beklenen oyuncu gücü x zorluk. Zorluk ilk savaştan son savaşa doğru artar.
## Oyuncunun avantajı: rakibi önceden görür, ona göre kart seçer ve dizer.
const DIFFICULTY_START := 0.85
const DIFFICULTY_END := 0.85
## Ortalama bir yükseltmenin güç katkısı: 40 + karışım payı.
const EXPECTED_UPGRADE_VALUE := 44.0


## Oyuncunun bu savaşa kadar her kartı aldığı varsayılırsa beklenen ordu gücü.
## İlk kartlar yeni bölük (+100), komuta sınırı dolunca yükseltme (+44).
static func expected_player_power(battle_index: int) -> float:
	var squads := 2
	var power := 2 * SQUAD_BUDGET
	for i in battle_index:
		if squads < MAX_SQUADS:
			squads += 1
			power += SQUAD_BUDGET
		else:
			power += EXPECTED_UPGRADE_VALUE
	return power


static func difficulty(battle_index: int) -> float:
	return lerpf(DIFFICULTY_START, DIFFICULTY_END, float(battle_index) / maxi(RUN_LENGTH - 1, 1))


static func enemy_power(battle_index: int) -> float:
	var power := expected_player_power(battle_index) * difficulty(battle_index)
	if is_final_battle(battle_index):
		power *= FINAL_POWER_MULT
	elif is_boss_battle(battle_index):
		power *= BOSS_POWER_MULT
	return power


static func is_boss_battle(battle_index: int) -> bool:
	return (battle_index + 1) % BOSS_EVERY == 0


static func is_final_battle(battle_index: int) -> bool:
	return battle_index == RUN_LENGTH - 1


## Rakip de oyuncu gibi her savaşta bir bölük kazanır, sonra yükseltir.
static func enemy_squad_count(battle_index: int) -> int:
	return mini(2 + battle_index, MAX_SQUADS)


## Bir türde k seviyenin çarpanı.
static func level_multiplier(k: int) -> float:
	return 1.0 + UPGRADE_STEP * k
