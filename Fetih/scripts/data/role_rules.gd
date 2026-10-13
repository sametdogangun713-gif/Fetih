class_name RoleRules
## Roller ve aralarındaki karşılık tablosu (taş-kağıt-makas).
## Avantajlı taraf, yendiği role COUNTER_BONUS kadar fazla hasar verir.

const WARRIOR := &"warrior"
const SPEARMAN := &"spearman"
const TANK := &"tank"
const ARCHER := &"archer"
const MAGE := &"mage"
const CAVALRY := &"cavalry"
const SIEGE := &"siege"

## Raporlarda ve listelerde kullanılan sıra.
const ROLE_ORDER: Array[StringName] = [WARRIOR, SPEARMAN, TANK, ARCHER, MAGE, CAVALRY, SIEGE]

const ROLE_NAMES := {
	WARRIOR: "Savaşçı",
	SPEARMAN: "Mızrakçı",
	TANK: "Tank",
	ARCHER: "Okçu",
	MAGE: "Büyücü",
	CAVALRY: "Süvari",
	SIEGE: "Kuşatma",
}

## anahtar rol -> yendiği roller
const COUNTERS := {
	SPEARMAN: [CAVALRY],  # hızlı gelen süvari mızrağa çarpar
	CAVALRY: [ARCHER, SIEGE],  # arka sıraya dalar; ağır toplar kaçamaz
	ARCHER: [MAGE],  # büyücünün canı az, menzili kısa
	MAGE: [TANK],  # büyü zırhı deler
	TANK: [WARRIOR],  # savaşçı zırhta tıkanır
	WARRIOR: [SPEARMAN],  # yakın dövüşte mızrak hantal
	SIEGE: [TANK],  # top güllesi kalın zırhı ezer
}

const COUNTER_BONUS := 1.25


static func has_advantage(attacker_role: StringName, target_role: StringName) -> bool:
	return COUNTERS.get(attacker_role, []).has(target_role)


static func is_ranged_role(role: StringName) -> bool:
	return role == ARCHER or role == MAGE or role == SIEGE
