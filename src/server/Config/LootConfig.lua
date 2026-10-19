--!strict
-- Table de loot de la Zone 1 (#72, voir docs/REWARDS.md § Loot). Uniquement des données, lues par
-- LootRules (validation, tirage, aperçu) ; RewardService les applique à la victoire. Jamais dans RewardConfig
-- (les récompenses de stage restent des monnaies).
--
-- ALPHA 0.0.2 PROVISOIRE — placeholder, à remplacer après simulation (tools/simulate-loot.ps1).
-- TOUTES les valeurs de ce fichier (chances, quantités, poids de rareté, plafond, garantie) sont des
-- placeholders : aucun équilibrage n'a été décidé. Seules sont des règles : les raretés autorisées par zone,
-- les familles de ressources de la Zone 1 et l'exclusion de resource_010 / resource_020.
--
-- Catalogues : ItemConfig (100 équipements) et ResourceConfig (60 ressources) existent déjà et ne sont pas
-- réinventés ici : ce fichier ne fait que RÉFÉRENCER leurs ItemId / ResourceId et les raretés de RarityConfig.
-- Les ressources n'ont aucune rareté ; la rareté ne concerne que l'équipement.
--
-- Forme d'une entrée (clé "<zone>-<stage>", comme RewardConfig) :
--   Equipment           = { Chance, Rarities = { { Rarity, Weight } } }
--                         un tirage par victoire : avec la probabilité Chance, UN équipement ; la rareté est
--                         choisie d'abord (poids entiers), puis l'item uniformément parmi les items du catalogue
--                         de cette rareté (pas de poids par ItemId) ;
--   FirstClearEquipment = { Rarities = { { Rarity, Weight } } } (facultatif, Normal seulement)
--                         UN équipement garanti à la PREMIÈRE victoire de ce stage (result.FirstClear), en plus
--                         du tirage Equipment ;
--   Items               = { { ItemId, Chance } } (facultatif) item précis, chance indépendante (1 = garanti) ;
--   Resources           = { { ResourceId, Chance, Min, Max } } chance indépendante, quantité entière Min..Max.
-- x1 / x2 (vitesse de combat) n'a aucun effet sur le loot. Défaite : aucun loot.

local function res(resourceId: string, chance: number, min: number, max: number)
	return { ResourceId = resourceId, Chance = chance, Min = min, Max = max }
end

local function rarities(...: any): { any }
	local out = {}
	local list = { ... }
	for i = 1, #list, 2 do
		table.insert(out, { Rarity = list[i], Weight = list[i + 1] })
	end
	return out
end

local LootConfig = {
	-- ALPHA 0.0.2 PROVISOIRE : plafond d'instances d'équipement possédées. Au-delà, l'équipement n'est pas
	-- créé (Overflow = true dans le résultat) ; ressources et monnaies sont toujours accordées.
	EquipmentCap = 500,

	-- Règles de zone (invariants validés par LootRules.problems, vrais pour toute valeur de la table).
	--   Normal / Elite     : raretés d'équipement autorisées ; jamais au-dessus de Legendaire en Zone 1 ;
	--   ResourceFamilies   : familles de ressources de la zone (slime, horde) ;
	--   ExcludedResources  : trophées de boss absents de la Zone 1 (resource_010 Bois du King Tréant,
	--                        resource_020 Couronne Fondue), exclus du loot (point ouvert).
	Zones = {
		[1] = {
			Normal = { "Commun", "PeuCommun", "Rare" },
			Elite = { "Rare", "Epique", "Legendaire" },
			ResourceFamilies = { "slime", "horde" },
			ExcludedResources = { "resource_010", "resource_020" },
		},
	},

	-- Mode Normal. 1-5 = Roi Orc : resource_030 (Corne du Roi Orc) à chaque victoire (PROVISOIRE),
	-- resource_029 (Défense d'Orc) avec une chance, et un équipement garanti au premier clear (PROVISOIRE).
	Stages = {
		["1-1"] = {
			Equipment = { Chance = 0.04, Rarities = rarities("Commun", 85, "PeuCommun", 15) },
			Resources = { res("resource_011", 0.60, 1, 2), res("resource_012", 0.25, 1, 1), res("resource_021", 0.50, 1, 2), res("resource_022", 0.30, 1, 1) },
		},
		["1-2"] = {
			Equipment = { Chance = 0.05, Rarities = rarities("Commun", 70, "PeuCommun", 28, "Rare", 2) },
			Resources = { res("resource_011", 0.55, 1, 3), res("resource_012", 0.35, 1, 2), res("resource_013", 0.25, 1, 1),
				res("resource_021", 0.50, 1, 2), res("resource_022", 0.35, 1, 2), res("resource_023", 0.25, 1, 1) },
		},
		["1-3"] = {
			Equipment = { Chance = 0.06, Rarities = rarities("Commun", 55, "PeuCommun", 38, "Rare", 7) },
			Resources = { res("resource_012", 0.40, 1, 2), res("resource_013", 0.35, 1, 2), res("resource_014", 0.25, 1, 1),
				res("resource_022", 0.40, 1, 2), res("resource_023", 0.40, 1, 2), res("resource_024", 0.25, 1, 1), res("resource_025", 0.15, 1, 1) },
		},
		["1-4"] = {
			Equipment = { Chance = 0.08, Rarities = rarities("Commun", 40, "PeuCommun", 45, "Rare", 15) },
			Resources = { res("resource_013", 0.40, 1, 2), res("resource_014", 0.35, 1, 2), res("resource_015", 0.25, 1, 1),
				res("resource_023", 0.40, 1, 2), res("resource_024", 0.35, 1, 2), res("resource_025", 0.25, 1, 1), res("resource_026", 0.20, 1, 1) },
		},
		["1-5"] = {
			Equipment = { Chance = 0.12, Rarities = rarities("Commun", 30, "PeuCommun", 50, "Rare", 20) },
			FirstClearEquipment = { Rarities = rarities("Commun", 20, "PeuCommun", 50, "Rare", 30) },
			Resources = { res("resource_015", 0.30, 1, 2), res("resource_016", 0.25, 1, 2), res("resource_017", 0.15, 1, 1), res("resource_018", 0.10, 1, 1),
				res("resource_025", 0.35, 1, 2), res("resource_026", 0.30, 1, 2), res("resource_027", 0.20, 1, 1), res("resource_028", 0.20, 1, 1),
				res("resource_029", 0.35, 1, 1), res("resource_030", 1.00, 1, 1) },
		},
	},

	-- Mode Élite : ressources plus généreuses, pool d'équipement Rare / Epique / Legendaire, 1-5 Élite =
	-- meilleure source de la Zone 1 (invariant vérifié par les tests, pas par la config elle-même).
	EliteStages = {
		["1-1"] = {
			Equipment = { Chance = 0.22, Rarities = rarities("Rare", 90, "Epique", 10) },
			Resources = { res("resource_011", 0.80, 1, 3), res("resource_012", 0.45, 1, 2), res("resource_021", 0.75, 1, 3), res("resource_022", 0.50, 1, 2) },
		},
		["1-2"] = {
			Equipment = { Chance = 0.25, Rarities = rarities("Rare", 80, "Epique", 20) },
			Resources = { res("resource_011", 0.75, 1, 4), res("resource_012", 0.55, 1, 3), res("resource_013", 0.40, 1, 2),
				res("resource_021", 0.75, 1, 3), res("resource_022", 0.55, 1, 3), res("resource_023", 0.40, 1, 2) },
		},
		["1-3"] = {
			Equipment = { Chance = 0.28, Rarities = rarities("Rare", 70, "Epique", 28, "Legendaire", 2) },
			Resources = { res("resource_012", 0.60, 1, 3), res("resource_013", 0.55, 1, 3), res("resource_014", 0.40, 1, 2),
				res("resource_022", 0.60, 1, 3), res("resource_023", 0.60, 1, 3), res("resource_024", 0.40, 1, 2), res("resource_025", 0.25, 1, 2) },
		},
		["1-4"] = {
			Equipment = { Chance = 0.32, Rarities = rarities("Rare", 60, "Epique", 35, "Legendaire", 5) },
			Resources = { res("resource_013", 0.60, 1, 3), res("resource_014", 0.55, 1, 3), res("resource_015", 0.40, 1, 2),
				res("resource_023", 0.60, 1, 3), res("resource_024", 0.55, 1, 3), res("resource_025", 0.40, 1, 2), res("resource_026", 0.30, 1, 2) },
		},
		["1-5"] = {
			Equipment = { Chance = 0.45, Rarities = rarities("Rare", 45, "Epique", 42, "Legendaire", 13) },
			Resources = { res("resource_015", 0.50, 1, 3), res("resource_016", 0.40, 1, 3), res("resource_017", 0.30, 1, 2), res("resource_018", 0.25, 1, 2), res("resource_019", 0.15, 1, 1),
				res("resource_025", 0.55, 1, 3), res("resource_026", 0.50, 1, 3), res("resource_027", 0.35, 1, 2), res("resource_028", 0.35, 1, 2),
				res("resource_029", 0.60, 1, 2), res("resource_030", 1.00, 1, 1) },
		},
	},
}

return LootConfig
