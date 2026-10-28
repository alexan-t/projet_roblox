--!strict
-- Règles pures de l'équipement porté (#73, voir docs/ITEMS.md § Équipement V1). Aucune API Roblox : testé par
-- tools/test-equipment.ps1. Modifie directement la table PlayerData passée en argument.
--
-- PlayerData.HeroEquipment = { [HeroInstanceId] = { [SlotType] = ItemInstanceId } }
-- L'équipement appartient à l'EXEMPLAIRE de héros (deux exemplaires d'un même HeroId portent des objets
-- différents). Un lien est VALIDE si : le héros existe (data.Heroes), l'objet existe (Inventory.Equipment) avec un
-- ItemId du catalogue, et le slot est le SlotType de cet ItemId. Un exemplaire d'objet n'est porté qu'une fois :
-- en cas de doublon (données corrompues), le premier dans l'ordre HeroInstanceId croissant puis ordre des
-- slots garde l'objet. Retirer ou remplacer ne supprime JAMAIS l'objet de l'inventaire : seul le lien change.
--
-- catalogs = { Item = ItemConfig } ; config = EquipmentConfig.

export type Catalogs = { Item: any }
export type Bonus = { MaxHealth: number, AttackDamage: number }
export type Holder = { Hero: string, Slot: string }
export type Result = { Slot: string, Replaced: string? }

local EquipmentRules = {}

local function isId(value: any): boolean
	return typeof(value) == "string" and value ~= ""
end

local function slotIds(catalogs: Catalogs): { string }
	local ids = {}
	for _, slotType in catalogs.Item.SlotTypes do
		table.insert(ids, slotType.Id)
	end
	return ids
end

local function isSlot(slot: any, catalogs: Catalogs): boolean
	return typeof(slot) == "string" and catalogs.Item.SlotTypeNames[slot] ~= nil
end

-- Catalogue de l'exemplaire possédé `instanceId`, ou nil (absent, entrée invalide, ItemId inconnu).
function EquipmentRules.itemOf(data: any, instanceId: any, catalogs: Catalogs): any
	if not isId(instanceId) then
		return nil
	end
	local inventory = data.Inventory
	local equipment = if typeof(inventory) == "table" then inventory.Equipment else nil
	local entry = if typeof(equipment) == "table" then equipment[instanceId] else nil
	if typeof(entry) ~= "table" or typeof(entry.ItemId) ~= "string" then
		return nil
	end
	return catalogs.Item.Items[entry.ItemId]
end

local function ownsHero(data: any, heroId: any): boolean
	return isId(heroId) and typeof(data.Heroes) == "table" and typeof(data.Heroes[heroId]) == "table"
end

-- Table HeroEquipment de ces données, recréée si elle manque ou si son type est faux.
function EquipmentRules.ensure(data: any): any
	if typeof(data.HeroEquipment) ~= "table" then
		data.HeroEquipment = {}
	end
	return data.HeroEquipment
end

local function validLink(data: any, heroId: any, slot: any, instanceId: any, catalogs: Catalogs): boolean
	if not ownsHero(data, heroId) or not isSlot(slot, catalogs) then
		return false
	end
	local item = EquipmentRules.itemOf(data, instanceId, catalogs)
	return item ~= nil and item.SlotType == slot
end

local function sortedHeroes(table_: any): { string }
	local ids = {}
	for heroId in table_ do
		if typeof(heroId) == "string" then
			table.insert(ids, heroId)
		end
	end
	table.sort(ids)
	return ids
end

-- Porteurs VALIDES : { [ItemInstanceId] = { Hero, Slot } }, doublons tranchés de façon déterministe.
function EquipmentRules.holders(data: any, catalogs: Catalogs): { [string]: Holder }
	local holders: { [string]: Holder } = {}
	local all = data.HeroEquipment
	if typeof(all) ~= "table" then
		return holders
	end
	local slots = slotIds(catalogs)
	for _, heroId in sortedHeroes(all) do
		local heroSlots = all[heroId]
		if typeof(heroSlots) == "table" then
			for _, slot in slots do
				local instanceId = heroSlots[slot]
				if validLink(data, heroId, slot, instanceId, catalogs) and holders[instanceId] == nil then
					holders[instanceId] = { Hero = heroId, Slot = slot }
				end
			end
		end
	end
	return holders
end

-- Objets réellement portés par cet exemplaire : { [SlotType] = ItemInstanceId } (liens valides seulement).
function EquipmentRules.heroItems(data: any, heroId: string, catalogs: Catalogs, holders: { [string]: Holder }?): { [string]: string }
	local items: { [string]: string } = {}
	local all = data.HeroEquipment
	local heroSlots = if typeof(all) == "table" then all[heroId] else nil
	if typeof(heroSlots) ~= "table" then
		return items
	end
	local owners = holders or EquipmentRules.holders(data, catalogs)
	for _, slot in slotIds(catalogs) do
		local instanceId = heroSlots[slot]
		local holder = if isId(instanceId) then owners[instanceId] else nil
		if holder and holder.Hero == heroId and holder.Slot == slot then
			items[slot] = instanceId
		end
	end
	return items
end

-- Bonus V1 d'un ItemId : base du slot × multiplicateur de rareté, arrondi ; { MaxHealth = 0, AttackDamage = 0 }
-- pour un ItemId inconnu. UpgradeLevel n'entre pas dans le calcul (Forge hors V1).
-- config nil (config invalide, voir activeConfig) : bonus nul. Défense en profondeur : base ou multiplicateur non
-- fini ou <= 0 ignorés (jamais de NaN ni de PV négatifs dans un roster).
local function positive(value: any): boolean
	return typeof(value) == "number" and value > 0 and value < math.huge
end

function EquipmentRules.itemBonus(itemId: any, catalogs: Catalogs, config: any): Bonus
	local bonus: Bonus = { MaxHealth = 0, AttackDamage = 0 }
	local item = if typeof(itemId) == "string" and config then catalogs.Item.Items[itemId] else nil
	local base = item and config.SlotStats[item.SlotType]
	local multiplier = item and config.RarityMultiplier[item.Rarity]
	if typeof(base) ~= "table" or not positive(multiplier) then
		return bonus
	end
	for _, key in config.Stats do
		local value = base[key]
		if (key == "MaxHealth" or key == "AttackDamage") and positive(value) then
			(bonus :: any)[key] = math.floor(value * multiplier + 0.5)
		end
	end
	return bonus
end

-- Somme des bonus des objets portés par cet exemplaire.
function EquipmentRules.heroBonus(data: any, heroId: string, catalogs: Catalogs, config: any, holders: { [string]: Holder }?): Bonus
	local total: Bonus = { MaxHealth = 0, AttackDamage = 0 }
	for _, instanceId in EquipmentRules.heroItems(data, heroId, catalogs, holders) do
		local item = EquipmentRules.itemOf(data, instanceId, catalogs)
		local bonus = EquipmentRules.itemBonus(item and item.Id, catalogs, config)
		total.MaxHealth += bonus.MaxHealth
		total.AttackDamage += bonus.AttackDamage
	end
	return total
end

-- Stats finales : copie de `stats` (déjà au niveau de l'exemplaire) + bonus PLATS, sur config.Stats seulement.
-- Toute autre stat (cadence, portée, vitesse, énergie, ultime) est recopiée telle quelle.
function EquipmentRules.applyBonus(stats: { [string]: any }, bonus: Bonus, config: any): { [string]: any }
	local final = table.clone(stats)
	for _, key in if config then config.Stats else {} do
		local add = (bonus :: any)[key]
		if typeof(final[key]) == "number" and typeof(add) == "number" then
			final[key] += add
		end
	end
	return final
end

-- Supprime les liens invalides (héros absent, objet absent ou inconnu, slot incompatible ou inconnu, valeur
-- vide, doublon) ; jamais un objet de l'inventaire. Renvoie le nombre de liens retirés.
function EquipmentRules.normalize(data: any, catalogs: Catalogs): number
	local removed = 0
	local all = EquipmentRules.ensure(data)
	local holders = EquipmentRules.holders(data, catalogs)
	for heroId, heroSlots in all do
		if typeof(heroId) ~= "string" or not ownsHero(data, heroId) or typeof(heroSlots) ~= "table" then
			all[heroId] = nil
			removed += 1
		else
			for slot, instanceId in heroSlots do
				local holder = if isId(instanceId) then holders[instanceId] else nil
				if not holder or holder.Hero ~= heroId or holder.Slot ~= slot then
					heroSlots[slot] = nil
					removed += 1
				end
			end
			if next(heroSlots) == nil then
				all[heroId] = nil
			end
		end
	end
	return removed
end

-- Équipe l'exemplaire d'objet `instanceId` sur l'exemplaire de héros `heroId`. Le slot est lu dans le catalogue
-- (jamais fourni par le client). Slot occupé : remplacement, l'ancien objet reste possédé (Replaced).
-- Refus : héros inconnu, équipement inconnu, emplacement inconnu, objet porté par un autre héros.
function EquipmentRules.equip(data: any, heroId: any, instanceId: any, catalogs: Catalogs): (boolean, string?, Result?)
	if not ownsHero(data, heroId) then
		return false, "héros inconnu", nil
	end
	local item = EquipmentRules.itemOf(data, instanceId, catalogs)
	if not item then
		return false, "équipement inconnu", nil
	end
	local slot = item.SlotType
	if not isSlot(slot, catalogs) then
		return false, "emplacement inconnu", nil
	end
	EquipmentRules.normalize(data, catalogs)
	local holder = EquipmentRules.holders(data, catalogs)[instanceId]
	if holder and holder.Hero ~= heroId then
		return false, "équipé par un autre héros", nil
	end
	if holder and holder.Slot == slot then
		return true, nil, { Slot = slot, Replaced = nil }
	end
	local all = EquipmentRules.ensure(data)
	local heroSlots = all[heroId]
	if typeof(heroSlots) ~= "table" then
		heroSlots = {}
		all[heroId] = heroSlots
	end
	local previous = heroSlots[slot]
	heroSlots[slot] = instanceId
	return true, nil, { Slot = slot, Replaced = if isId(previous) and previous ~= instanceId then previous else nil }
end

-- Retire l'objet du slot `slot` de l'exemplaire `heroId` ; l'objet reste dans l'inventaire.
-- Refus : héros inconnu, emplacement inconnu, emplacement vide.
function EquipmentRules.unequip(data: any, heroId: any, slot: any, catalogs: Catalogs): (boolean, string?, Result?)
	if not ownsHero(data, heroId) then
		return false, "héros inconnu", nil
	end
	if not isSlot(slot, catalogs) then
		return false, "emplacement inconnu", nil
	end
	EquipmentRules.normalize(data, catalogs)
	local all = EquipmentRules.ensure(data)
	local heroSlots = all[heroId]
	local current = if typeof(heroSlots) == "table" then heroSlots[slot] else nil
	if not isId(current) then
		return false, "emplacement vide", nil
	end
	heroSlots[slot] = nil
	if next(heroSlots) == nil then
		all[heroId] = nil
	end
	return true, nil, { Slot = slot, Replaced = current }
end

-- Retire tous les liens d'un exemplaire de héros (héros supprimé) ; ses objets restent dans l'inventaire.
function EquipmentRules.dropHero(data: any, heroId: string)
	local all = data.HeroEquipment
	if typeof(all) == "table" then
		all[heroId] = nil
	end
end

-- Problèmes de config ; vide si elle est utilisable (chaque slot et chaque rareté du catalogue couverts,
-- nombres positifs finis, uniquement les stats autorisées).
function EquipmentRules.configProblems(config: any, catalogs: Catalogs, rarities: { any }): { string }
	local problems: { string } = {}
	local allowed: { [string]: boolean } = {}
	for _, key in config.Stats or {} do
		allowed[key] = true
	end
	if not allowed.MaxHealth or not allowed.AttackDamage then
		table.insert(problems, "Stats doit contenir MaxHealth et AttackDamage")
	end
	for _, slot in slotIds(catalogs) do
		local base = config.SlotStats and config.SlotStats[slot]
		if typeof(base) ~= "table" or next(base) == nil then
			table.insert(problems, `SlotStats.{slot} manquant`)
		else
			for key, value in base do
				if not allowed[key] then
					table.insert(problems, `SlotStats.{slot}.{key} : stat non autorisée en V1`)
				elseif typeof(value) ~= "number" or value <= 0 or value ~= value or value == math.huge then
					table.insert(problems, `SlotStats.{slot}.{key} : nombre positif attendu`)
				end
			end
		end
	end
	for _, tier in rarities do
		local multiplier = config.RarityMultiplier and config.RarityMultiplier[tier.Id]
		if typeof(multiplier) ~= "number" or multiplier <= 0 or multiplier ~= multiplier or multiplier == math.huge then
			table.insert(problems, `RarityMultiplier.{tier.Id} : nombre positif attendu`)
		end
	end
	return problems
end

-- Config utilisable par le serveur : `config` si configProblems est vide, sinon nil (bonus nul partout : roster,
-- vues, et EquipmentService refuse les mutations). Une erreur de config ne doit jamais fausser un combat.
function EquipmentRules.activeConfig(config: any, catalogs: Catalogs, rarities: { any }): any
	return if #EquipmentRules.configProblems(config, catalogs, rarities) == 0 then config else nil
end

return EquipmentRules
