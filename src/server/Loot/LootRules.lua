--!strict
-- Règles pures du loot (#72, voir docs/REWARDS.md § Loot). Aucune API Roblox : testé par tools/test-loot.ps1.
-- Valide LootConfig, tire le butin d'une victoire et produit l'aperçu « Butin possible ».
-- Le tirage n'écrit RIEN : il renvoie ce qui est dû ; InventoryRules.apply le range dans l'inventaire.
--
-- catalogs = { Item = ItemConfig, Resource = ResourceConfig, Rarity = RarityConfig } (les catalogues
-- existants ; LootRules ne connaît aucun ItemId ni ResourceId en dur).
-- rng = { NextNumber(self) -> [0, 1), NextInteger(self, min, max) -> entier min..max } (Random de Roblox,
-- ou un générateur à graine pour les tests et la simulation).

export type Catalogs = { Item: any, Resource: any, Rarity: any }
export type Rolled = {
	Items: { { ItemId: string } },
	Resources: { { ResourceId: string, Amount: number } },
}
export type Drop = { Kind: string, Id: string, Chance: number, Min: number, Max: number }

local LootRules = {}

-- Plafond DUR de rareté par zone, indépendant de la config : une table de zone ne peut jamais le dépasser.
-- Zone 1 : jamais au-dessus de Legendaire (pas de Mythique / Maudit / Suprême / Calamité / Transcendant).
LootRules.MAX_RARITY = table.freeze({ [1] = "Legendaire" } :: { [number]: string })
-- Borne de sûreté d'une quantité par tirage (pas une règle de design).
LootRules.MAX_AMOUNT = 1000

local function isInteger(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge and value % 1 == 0
end

local function isList(value: any): boolean
	if typeof(value) ~= "table" then
		return false
	end
	local count = 0
	for _ in value do
		count += 1
	end
	return count == #value
end

local function contains(list: any, value: any): boolean
	if typeof(list) ~= "table" then
		return false
	end
	for _, item in list do
		if item == value then
			return true
		end
	end
	return false
end

-- "1-5" -> 1, 5 ; nil si la clé n'a pas la forme "<zone>-<stage>".
local function parseKey(key: any): (number?, number?)
	if typeof(key) ~= "string" then
		return nil, nil
	end
	local zone, stage = string.match(key, "^(%d+)%-(%d+)$")
	if not zone then
		return nil, nil
	end
	return tonumber(zone), tonumber(stage)
end

-- Items du catalogue de cette rareté, dans l'ordre du catalogue.
local function itemsOfRarity(rarity: string, catalogs: Catalogs): { any }
	local out = {}
	for _, info in catalogs.Item.Ordered do
		if info.Rarity == rarity then
			table.insert(out, info)
		end
	end
	return out
end

local function raritiesProblems(list: any, where: string, allowed: any, zone: number, catalogs: Catalogs, problems: { string })
	if not isList(list) or #list == 0 then
		table.insert(problems, `{where} : liste de raretés non vide attendue`)
		return
	end
	local ceiling = LootRules.MAX_RARITY[zone]
	local seen: { [string]: boolean } = {}
	local total = 0
	for index, entry in list do
		local at = `{where}[{index}]`
		if typeof(entry) ~= "table" or typeof(entry.Rarity) ~= "string" then
			table.insert(problems, `{at} : Rarity attendue`)
			continue
		end
		local rank = catalogs.Rarity.Rank[entry.Rarity]
		if rank == nil then
			table.insert(problems, `{at} : rareté inconnue ({entry.Rarity})`)
		else
			if ceiling and rank > catalogs.Rarity.Rank[ceiling] then
				table.insert(problems, `{at} : {entry.Rarity} dépasse {ceiling} en zone {zone}`)
			end
			if not contains(allowed, entry.Rarity) then
				table.insert(problems, `{at} : {entry.Rarity} hors des raretés autorisées de la zone {zone}`)
			end
			if #itemsOfRarity(entry.Rarity, catalogs) == 0 then
				table.insert(problems, `{at} : aucun item {entry.Rarity} dans le catalogue`)
			end
		end
		if seen[entry.Rarity] then
			table.insert(problems, `{at} : rareté en double ({entry.Rarity})`)
		end
		seen[entry.Rarity] = true
		if not isInteger(entry.Weight) or entry.Weight < 1 then
			table.insert(problems, `{at} : Weight doit être un entier >= 1`)
		else
			total += entry.Weight
		end
	end
	if total < 1 then
		table.insert(problems, `{where} : poids total nul`)
	end
end

local function chanceProblem(chance: any, where: string, problems: { string })
	if typeof(chance) ~= "number" or chance ~= chance or chance <= 0 or chance > 1 then
		table.insert(problems, `{where} : Chance doit être un nombre dans ]0, 1]`)
	end
end

-- Problèmes d'une entrée (clé "<zone>-<stage>", mode "Normal" / "Elite") ; vide si elle est utilisable.
function LootRules.entryProblems(entry: any, key: string, mode: string, config: any, catalogs: Catalogs): { string }
	local problems: { string } = {}
	local zone = parseKey(key)
	if not zone then
		table.insert(problems, `{key} : clé "<zone>-<stage>" attendue`)
		return problems
	end
	if typeof(entry) ~= "table" then
		table.insert(problems, `{key} : entrée attendue`)
		return problems
	end
	local rules = if typeof(config.Zones) == "table" then config.Zones[zone] else nil
	if typeof(rules) ~= "table" then
		table.insert(problems, `{key} : zone {zone} sans règle de loot`)
		return problems
	end
	local allowedRarities = if mode == "Elite" then rules.Elite else rules.Normal
	local ceilingName = LootRules.MAX_RARITY[zone]
	local ceilingRank = if ceilingName then catalogs.Rarity.Rank[ceilingName] else nil
	for _, rarity in if typeof(allowedRarities) == "table" then allowedRarities else {} do
		local rank = catalogs.Rarity.Rank[rarity]
		if rank == nil or (ceilingRank and rank > ceilingRank) then
			table.insert(problems, `{key} : raretés de zone invalides ({tostring(rarity)})`)
		end
	end
	if entry.Equipment ~= nil then
		local equipment = entry.Equipment
		if typeof(equipment) ~= "table" then
			table.insert(problems, `{key}.Equipment : table attendue`)
		else
			chanceProblem(equipment.Chance, `{key}.Equipment`, problems)
			raritiesProblems(equipment.Rarities, `{key}.Equipment.Rarities`, allowedRarities, zone, catalogs, problems)
		end
	end
	if entry.FirstClearEquipment ~= nil then
		local first = entry.FirstClearEquipment
		if typeof(first) ~= "table" then
			table.insert(problems, `{key}.FirstClearEquipment : table attendue`)
		else
			raritiesProblems(first.Rarities, `{key}.FirstClearEquipment.Rarities`, allowedRarities, zone, catalogs, problems)
		end
	end
	if entry.Items ~= nil then
		if not isList(entry.Items) then
			table.insert(problems, `{key}.Items : liste attendue`)
		else
			local seen: { [string]: boolean } = {}
			for index, drop in entry.Items do
				local at = `{key}.Items[{index}]`
				local info = if typeof(drop) == "table" and typeof(drop.ItemId) == "string" then catalogs.Item.Items[drop.ItemId] else nil
				if not info then
					table.insert(problems, `{at} : ItemId inconnu`)
				else
					if seen[drop.ItemId] then
						table.insert(problems, `{at} : ItemId en double`)
					end
					seen[drop.ItemId] = true
					local rank = catalogs.Rarity.Rank[info.Rarity]
					if ceilingRank and rank and rank > ceilingRank then
						table.insert(problems, `{at} : {info.Rarity} dépasse {ceilingName} en zone {zone}`)
					end
					if not contains(allowedRarities, info.Rarity) then
						table.insert(problems, `{at} : {info.Rarity} hors des raretés autorisées de la zone {zone}`)
					end
				end
				if typeof(drop) == "table" then
					chanceProblem(drop.Chance, at, problems)
				end
			end
		end
	end
	if entry.Resources ~= nil then
		if not isList(entry.Resources) then
			table.insert(problems, `{key}.Resources : liste attendue`)
		else
			local seen: { [string]: boolean } = {}
			for index, drop in entry.Resources do
				local at = `{key}.Resources[{index}]`
				if typeof(drop) ~= "table" then
					table.insert(problems, `{at} : entrée attendue`)
					continue
				end
				local info = if typeof(drop.ResourceId) == "string" then catalogs.Resource.Resources[drop.ResourceId] else nil
				if not info then
					table.insert(problems, `{at} : ResourceId inconnu`)
				else
					if seen[drop.ResourceId] then
						table.insert(problems, `{at} : ResourceId en double`)
					end
					seen[drop.ResourceId] = true
					if not contains(rules.ResourceFamilies, info.Family) then
						table.insert(problems, `{at} : famille {info.Family} hors zone {zone} ({drop.ResourceId})`)
					end
					if contains(rules.ExcludedResources, drop.ResourceId) then
						table.insert(problems, `{at} : {drop.ResourceId} exclu du loot de la zone {zone}`)
					end
				end
				chanceProblem(drop.Chance, at, problems)
				if not isInteger(drop.Min) or not isInteger(drop.Max) or drop.Min < 1 or drop.Max < drop.Min or drop.Max > LootRules.MAX_AMOUNT then
					table.insert(problems, `{at} : Min / Max doivent être des entiers 1 <= Min <= Max <= {LootRules.MAX_AMOUNT}`)
				end
			end
		end
	end
	return problems
end

-- Problèmes de toute la config ; vide si elle est utilisable. LootConfig invalide = aucun loot (RewardService).
function LootRules.problems(config: any, catalogs: Catalogs): { string }
	local problems: { string } = {}
	if typeof(config) ~= "table" then
		table.insert(problems, "LootConfig : table attendue")
		return problems
	end
	if not isInteger(config.EquipmentCap) or config.EquipmentCap < 1 then
		table.insert(problems, "EquipmentCap doit être un entier >= 1")
	end
	for _, section in { { "Stages", "Normal" }, { "EliteStages", "Elite" } } do
		local entries = config[section[1]]
		if typeof(entries) ~= "table" then
			table.insert(problems, `{section[1]} : table attendue`)
			continue
		end
		for key, entry in entries do
			for _, problem in LootRules.entryProblems(entry, tostring(key), section[2], config, catalogs) do
				table.insert(problems, `{section[1]} {problem}`)
			end
		end
	end
	return problems
end

-- Rareté tirée selon les poids (entiers) : un seul NextInteger.
local function pickRarity(list: { { Rarity: string, Weight: number } }, rng: any): string
	local total = 0
	for _, entry in list do
		total += entry.Weight
	end
	local roll = rng:NextInteger(1, total)
	for _, entry in list do
		if roll <= entry.Weight then
			return entry.Rarity
		end
		roll -= entry.Weight
	end
	return list[#list].Rarity
end

-- Un équipement : rareté d'abord, puis item uniforme parmi les items de cette rareté du catalogue.
local function pickItem(list: { { Rarity: string, Weight: number } }, rng: any, catalogs: Catalogs): string
	local rarity = pickRarity(list, rng)
	local pool = itemsOfRarity(rarity, catalogs)
	return pool[rng:NextInteger(1, #pool)].Id
end

local function chanceHit(chance: number, rng: any): boolean
	return chance >= 1 or rng:NextNumber() < chance
end

-- Tire le butin d'UNE victoire. entry : entrée validée (LootRules.problems vide) ; ctx = { FirstClear, Catalogs }.
-- Ordre des tirages fixe (reproductible à graine) : équipement garanti du premier clear, tirage d'équipement,
-- items précis, ressources dans l'ordre de l'entrée. Ressources renvoyées dans l'ordre du catalogue.
function LootRules.roll(entry: any, rng: any, ctx: { FirstClear: boolean?, Catalogs: Catalogs }): Rolled
	local catalogs = ctx.Catalogs
	local rolled: Rolled = { Items = {}, Resources = {} }
	if ctx.FirstClear == true and entry.FirstClearEquipment then
		table.insert(rolled.Items, { ItemId = pickItem(entry.FirstClearEquipment.Rarities, rng, catalogs) })
	end
	if entry.Equipment and chanceHit(entry.Equipment.Chance, rng) then
		table.insert(rolled.Items, { ItemId = pickItem(entry.Equipment.Rarities, rng, catalogs) })
	end
	for _, drop in entry.Items or {} do
		if chanceHit(drop.Chance, rng) then
			table.insert(rolled.Items, { ItemId = drop.ItemId })
		end
	end
	for _, drop in entry.Resources or {} do
		if chanceHit(drop.Chance, rng) then
			local amount = if drop.Max > drop.Min then rng:NextInteger(drop.Min, drop.Max) else drop.Min
			table.insert(rolled.Resources, { ResourceId = drop.ResourceId, Amount = amount })
		end
	end
	table.sort(rolled.Resources, function(a, b)
		return catalogs.Resource.Resources[a.ResourceId].Index < catalogs.Resource.Resources[b.ResourceId].Index
	end)
	return rolled
end

-- Aperçu « Butin possible » (StagePreview.PotentialDrops) : ressources avec leurs chances réelles, puis les
-- items précis configurés. L'équipement aléatoire n'est PAS listé ligne par ligne (aucune extension du
-- contrat Drop). nil si le stage n'a pas d'entrée ou rien à lister. Les entrées mal formées sont ignorées.
function LootRules.preview(config: any, mode: string?, key: string): { Drop }?
	if typeof(config) ~= "table" then
		return nil
	end
	local source = if mode == "Elite" then config.EliteStages else config.Stages
	local entry = if typeof(source) == "table" then source[key] else nil
	if typeof(entry) ~= "table" then
		return nil
	end
	local out: { Drop } = {}
	for _, drop in if typeof(entry.Resources) == "table" then entry.Resources else {} do
		if typeof(drop) == "table" and typeof(drop.ResourceId) == "string" and typeof(drop.Chance) == "number" and drop.Chance > 0 and drop.Chance <= 1 then
			table.insert(out, { Kind = "Resource", Id = drop.ResourceId, Chance = drop.Chance, Min = drop.Min, Max = drop.Max })
		end
	end
	for _, drop in if typeof(entry.Items) == "table" then entry.Items else {} do
		if typeof(drop) == "table" and typeof(drop.ItemId) == "string" and typeof(drop.Chance) == "number" and drop.Chance > 0 and drop.Chance <= 1 then
			table.insert(out, { Kind = "Item", Id = drop.ItemId, Chance = drop.Chance, Min = 1, Max = 1 })
		end
	end
	return if #out > 0 then out else nil
end

export type RarityChance = { Rarity: string, Chance: number }
export type EquipmentPreview = { Chance: number, Rarities: { RarityChance }, FirstClear: { RarityChance }? }

-- Rareté par rareté, dans l'ordre de l'entrée : Chance = scale * poids / total des poids.
local function rarityChances(list: any, scale: number): { RarityChance }
	local total = 0
	for _, entry in list do
		total += entry.Weight
	end
	local out: { RarityChance } = {}
	for _, entry in list do
		table.insert(out, { Rarity = entry.Rarity, Chance = scale * entry.Weight / total })
	end
	return out
end

-- Aperçu de l'équipement ALÉATOIRE d'un stage (fenêtre Expédition, #120), calculé depuis la table réelle :
--   Chance     : probabilité d'obtenir UN équipement par victoire (Equipment.Chance, jamais par ennemi) ;
--   Rarities   : probabilité par victoire de chaque rareté (Chance x poids / total des poids) ;
--   FirstClear : équipement garanti de la première victoire (FirstClearEquipment), part de chaque rareté.
-- nil si le stage n'a pas d'entrée ni d'équipement. N'appeler qu'avec une config validée (LootRules.problems).
function LootRules.equipment(config: any, mode: string?, key: string): EquipmentPreview?
	local source = if typeof(config) == "table" then (if mode == "Elite" then config.EliteStages else config.Stages) else nil
	local entry = if typeof(source) == "table" then source[key] else nil
	if typeof(entry) ~= "table" or (entry.Equipment == nil and entry.FirstClearEquipment == nil) then
		return nil
	end
	local equipment = entry.Equipment
	local first = entry.FirstClearEquipment
	return {
		Chance = if equipment then equipment.Chance else 0,
		Rarities = if equipment then rarityChances(equipment.Rarities, equipment.Chance) else {},
		FirstClear = if first then rarityChances(first.Rarities, 1) else nil,
	}
end

return LootRules
