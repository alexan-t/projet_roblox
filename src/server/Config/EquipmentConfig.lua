--!strict
-- Bonus de combat de l'équipement porté (#73, voir docs/ITEMS.md § Équipement V1 et docs/COMBAT.md).
-- Uniquement des données, lues par EquipmentRules ; HeroService les ajoute aux stats de niveau (#68) de
-- l'exemplaire, au lancement du combat (roster figé) et dans la vue de la Sacoche.
--
-- ALPHA 0.0.2 PROVISOIRE — à valider par l'équilibrage #112. Seules sont des règles :
--   - V1 ne modifie que MaxHealth et AttackDamage (jamais cadence, portée, vitesse, énergie, ultime) ;
--   - bonus PLATS, ajoutés après le niveau : profil de combat → niveau → + équipement → stats finales ;
--   - la puissance d'un objet dépend de son SlotType et de sa rareté (ItemConfig), pas de son ItemId :
--     bonus = arrondi(base du slot × multiplicateur de la rareté) ;
--   - UpgradeLevel (Forge) n'a AUCUN effet en V1.
-- Philosophie des slots : Arme ATK, Casque PV, Armure PV, Gants ATK, Bottes PV, Accessoire PV + ATK léger,
-- Relique PV + ATK.
--
-- Repères (profils de combat niveau 1) : Épéiste 150 PV / 16 ATK, Paladin 220 / 12, Archer 90 / 14.
-- Une Armure Commune (+30 PV) donne +20 % de PV à l'Épéiste ; une Arme Rare (+6 ATK), +38 % d'ATK.

local EquipmentConfig = {
	-- Stats que l'équipement peut modifier en V1 (toute autre clé est ignorée).
	Stats = table.freeze({ "MaxHealth", "AttackDamage" }),

	-- ALPHA 0.0.2 PROVISOIRE : bonus d'un objet Commun, par slot (ItemConfig.SlotTypes).
	SlotStats = table.freeze({
		weapon = table.freeze({ AttackDamage = 3 }),
		helmet = table.freeze({ MaxHealth = 20 }),
		armor = table.freeze({ MaxHealth = 30 }),
		gloves = table.freeze({ AttackDamage = 2 }),
		boots = table.freeze({ MaxHealth = 15 }),
		accessory = table.freeze({ MaxHealth = 10, AttackDamage = 1 }),
		relic = table.freeze({ MaxHealth = 15, AttackDamage = 2 }),
	}),

	-- ALPHA 0.0.2 PROVISOIRE : multiplicateur par rareté d'équipement (RarityConfig.Tiers).
	RarityMultiplier = table.freeze({
		Commun = 1,
		PeuCommun = 1.5,
		Rare = 2,
		Epique = 3,
		Legendaire = 4,
		Mythique = 5,
		Maudit = 6,
		Supreme = 7.5,
		Calamite = 9,
		Transcendant = 11,
	}),

	-- Délai minimal (s) entre deux actions Équiper / Retirer d'un même joueur (anti-rafale).
	ActionCooldown = 0.2,
}

return table.freeze(EquipmentConfig)
