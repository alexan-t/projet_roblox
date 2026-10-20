--!strict
-- Progression des héros : niveaux et XP (voir docs/HEROES.md § Niveaux et XP). Uniquement des données,
-- lues par HeroProgressionRules (pur) et HeroService. Serveur seulement : le client reçoit des vues.
--
-- VALEURS ALPHA 0.0.2 PROVISOIRES : de quoi tester le système, pas un balancing final.
--   XP requise de Lv n à n + 1 : FirstLevelXP + PerLevelXP × (n - 1) → 100, 125, 150 … 550 (Lv19 → 20).
--   Stats par niveau : MaxHealth et AttackDamage × (1 + (Level - 1) × 0,05) → Lv20 = 195 %.
--   Aucune autre stat ne progresse (ultime compris).
--   XP gagnée : victoire seulement, par stage (StageXP, clé = Progression.FirstClears) ; défaite = 0.
--   Chaque héros réellement posé dans le combat gagne le montant complet (pas de partage).

local HeroProgressionConfig = {
	MaxLevel = 20,
	FirstLevelXP = 100,
	PerLevelXP = 25,
	-- Bonus par niveau au-delà du premier (0,05 = +5 %), seulement pour ces stats de CombatConfig.Heroes.
	StatGrowth = table.freeze({
		MaxHealth = 0.05,
		AttackDamage = 0.05,
	}),
	-- XP d'une victoire, par stage, en Mode Normal. Zones 2 à 6 : croît avec la zone (niveaux visés,
	-- docs/ZONES.md § Zones 2 à 6).
	StageXP = table.freeze({
		["1-1"] = 25, ["1-2"] = 35, ["1-3"] = 50, ["1-4"] = 70, ["1-5"] = 100,
		["2-1"] = 45, ["2-2"] = 60, ["2-3"] = 80, ["2-4"] = 100, ["2-5"] = 140,
		["3-1"] = 70, ["3-2"] = 90, ["3-3"] = 115, ["3-4"] = 140, ["3-5"] = 190,
		["4-1"] = 95, ["4-2"] = 120, ["4-3"] = 150, ["4-4"] = 180, ["4-5"] = 240,
		["5-1"] = 120, ["5-2"] = 150, ["5-3"] = 185, ["5-4"] = 220, ["5-5"] = 290,
		["6-1"] = 150, ["6-2"] = 185, ["6-3"] = 225, ["6-4"] = 265, ["6-5"] = 350,
	}),
	-- XP d'une victoire en Mode Élite (#69), table distincte : 1-3 Élite ≠ 1-3 Normal.
	EliteStageXP = table.freeze({
		["1-1"] = 60,
		["1-2"] = 80,
		["1-3"] = 110,
		["1-4"] = 150,
		["1-5"] = 220,
	}),
}

return table.freeze(HeroProgressionConfig)
