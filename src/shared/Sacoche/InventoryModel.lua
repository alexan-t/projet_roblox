--!strict
-- Logique d'affichage de l'inventaire (Sacoche > Équipement / Ressources), pure et testée
-- (tools/test-sacoche.ps1). Les données viennent de la vue du serveur (GetInventory / InventoryChanged) ;
-- nom, rareté, emplacement, famille et icône viennent des catalogues (ItemConfig, ResourceConfig). La vue
-- n'invente ni objet, ni quantité, ni rareté : une entrée inconnue du catalogue ou une quantité invalide est
-- ignorée, jamais affichée.
--   sanitize(view)                -> vue nettoyée, ou nil si ce n'est pas une table
--   equipmentCards(entries, ctx)  -> une carte par instance (jamais fusionnées), triées : rareté décroissante,
--                                    puis ordre du catalogue, puis InstanceId ; filtre par emplacement
--   slotFilters(entries, ctx, order) -> « Tous » + les emplacements réellement possédés (avec effectif)
--   activeSlot(filters, slot)     -> emplacement effectif (retombe sur « all » si plus aucun objet dedans)
--   resourceGroups(entries, ctx)  -> groupes par famille NON VIDE, dans l'ordre des familles du catalogue
--   amountText(n) / levelText(n)  -> « 12 », « 10k » ; « +2 » seulement si le niveau est > 0 (jamais « +0 »)
--   initials(name)                -> repli d'icône : deux premiers caractères (UTF-8) en majuscules
-- La rareté des ressources n'existe pas : aucune clé de rareté dans les groupes de ressources.

local InventoryModel = {}

export type EquipmentEntry = { InstanceId: string, ItemId: string, UpgradeLevel: number? }
export type ResourceEntry = { ResourceId: string, Amount: number }
export type View = { Equipment: { EquipmentEntry }, Resources: { ResourceEntry }, Count: number, Cap: number? }
export type ItemInfo = { Id: string, Name: string, Rarity: string, SlotType: string, Index: number, Icon: string? }
export type ResourceInfo = { Id: string, Name: string, Family: string, Index: number, Icon: string? }
export type ItemCard = {
	InstanceId: string, ItemId: string, Name: string, Rarity: string, Rank: number, SlotType: string, SlotName: string,
	Icon: string?, Index: number, LevelText: string?, New: boolean,
}
export type EquipmentContext = {
	Items: { [string]: ItemInfo },
	RankOf: (rarity: string?) -> number, -- RarityStyle.rank côté client
	SlotNames: { [string]: string },
	Slot: string?, -- "all" ou un SlotType
	New: { [string]: boolean }?, -- InstanceId apparus depuis l'ouverture du jeu, pas encore vus
}
export type SlotFilter = { Id: string, Label: string, Count: number }
export type ResourceTile = { ResourceId: string, Name: string, Icon: string?, Amount: number, AmountText: string, Index: number }
export type ResourceGroup = { Id: string, Name: string, Tiles: { ResourceTile }, Total: number }
export type ResourceContext = {
	Resources: { [string]: ResourceInfo },
	Families: { { Id: string, Name: string } },
}

local function validAmount(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value < 1 or value == math.huge then
		return nil
	end
	return math.floor(value)
end

-- Vue serveur -> vue sûre. Une entrée mal formée est ignorée (jamais corrigée ni inventée).
function InventoryModel.sanitize(view: any): View?
	if typeof(view) ~= "table" then
		return nil
	end
	local out: View = { Equipment = {}, Resources = {}, Count = 0, Cap = nil }
	if typeof(view.Equipment) == "table" then
		for _, entry in view.Equipment do
			if typeof(entry) == "table" and typeof(entry.InstanceId) == "string" and typeof(entry.ItemId) == "string" then
				local level = if typeof(entry.UpgradeLevel) == "number" then math.max(math.floor(entry.UpgradeLevel), 0) else 0
				table.insert(out.Equipment, { InstanceId = entry.InstanceId, ItemId = entry.ItemId, UpgradeLevel = level })
			end
		end
	end
	if typeof(view.Resources) == "table" then
		for _, entry in view.Resources do
			local amount = if typeof(entry) == "table" then validAmount(entry.Amount) else nil
			if amount and typeof(entry.ResourceId) == "string" then
				table.insert(out.Resources, { ResourceId = entry.ResourceId, Amount = amount })
			end
		end
	end
	out.Count = if typeof(view.Count) == "number" then math.max(math.floor(view.Count), 0) else #out.Equipment
	out.Cap = if typeof(view.Cap) == "number" and view.Cap >= 1 then math.floor(view.Cap) else nil
	return out
end

function InventoryModel.amountText(amount: number): string
	if amount >= 10000 then
		return `{math.floor(amount / 1000)}k`
	end
	return tostring(math.floor(amount))
end

-- « +2 » seulement pour un niveau d'amélioration > 0 : jamais « +0 ».
function InventoryModel.levelText(level: number?): string?
	if level and level >= 1 then
		return `+{math.floor(level)}`
	end
	return nil
end

-- Deux premiers caractères (UTF-8 : « Épée » -> « ÉP ») pour une icône absente du catalogue.
function InventoryModel.initials(name: string): string
	local second = utf8.offset(name, 3)
	local head = if second then string.sub(name, 1, second - 1) else name
	return string.upper(head)
end

local function allCards(entries: { EquipmentEntry }, ctx: EquipmentContext): { ItemCard }
	local list: { ItemCard } = {}
	for _, entry in entries do
		local info = ctx.Items[entry.ItemId]
		if info then
			table.insert(list, {
				InstanceId = entry.InstanceId, ItemId = entry.ItemId, Name = info.Name, Rarity = info.Rarity,
				Rank = ctx.RankOf(info.Rarity), SlotType = info.SlotType, SlotName = ctx.SlotNames[info.SlotType] or info.SlotType,
				Icon = info.Icon, Index = info.Index, LevelText = InventoryModel.levelText(entry.UpgradeLevel),
				New = ctx.New ~= nil and ctx.New[entry.InstanceId] == true,
			})
		end
	end
	return list
end

-- Rareté décroissante, puis ordre du catalogue, puis InstanceId (ordre d'obtention) : total et stable.
local function before(a: ItemCard, b: ItemCard): boolean
	if a.Rank ~= b.Rank then
		return a.Rank > b.Rank
	end
	if a.Index ~= b.Index then
		return a.Index < b.Index
	end
	return a.InstanceId < b.InstanceId
end

InventoryModel.before = before

function InventoryModel.equipmentCards(entries: { EquipmentEntry }, ctx: EquipmentContext): { ItemCard }
	local slot = ctx.Slot or "all"
	local list: { ItemCard } = {}
	for _, card in allCards(entries, ctx) do
		if slot == "all" or card.SlotType == slot then
			table.insert(list, card)
		end
	end
	table.sort(list, before)
	return list
end

-- « Tous » puis les emplacements possédés, dans l'ordre de ItemConfig.SlotTypes (slotOrder).
function InventoryModel.slotFilters(entries: { EquipmentEntry }, ctx: EquipmentContext, slotOrder: { string }): { SlotFilter }
	local counts: { [string]: number } = {}
	local total = 0
	for _, card in allCards(entries, ctx) do
		counts[card.SlotType] = (counts[card.SlotType] or 0) + 1
		total += 1
	end
	local filters: { SlotFilter } = { { Id = "all", Label = "Tous", Count = total } }
	for _, slot in slotOrder do
		local count = counts[slot]
		if count then
			table.insert(filters, { Id = slot, Label = ctx.SlotNames[slot] or slot, Count = count })
		end
	end
	return filters
end

function InventoryModel.activeSlot(filters: { SlotFilter }, slot: string?): string
	for _, filter in filters do
		if filter.Id == slot then
			return filter.Id
		end
	end
	return "all"
end

-- Groupes par famille NON VIDE ; tuiles dans l'ordre du catalogue ; une ressource inconnue est ignorée,
-- un doublon d'entrée est additionné.
function InventoryModel.resourceGroups(entries: { ResourceEntry }, ctx: ResourceContext): { ResourceGroup }
	local byId: { [string]: ResourceTile } = {}
	local byFamily: { [string]: ResourceGroup } = {}
	local groups: { ResourceGroup } = {}
	for _, family in ctx.Families do
		byFamily[family.Id] = { Id = family.Id, Name = family.Name, Tiles = {}, Total = 0 }
	end
	for _, entry in entries do
		local info = ctx.Resources[entry.ResourceId]
		local amount = validAmount(entry.Amount)
		local group = if info then byFamily[info.Family] else nil
		if info and amount and group then
			local tile = byId[info.Id]
			if tile then
				tile.Amount += amount
			else
				local created: ResourceTile = { ResourceId = info.Id, Name = info.Name, Icon = info.Icon, Amount = amount, AmountText = "", Index = info.Index }
				byId[info.Id] = created
				table.insert(group.Tiles, created)
			end
		end
	end
	for _, family in ctx.Families do
		local group = byFamily[family.Id]
		if #group.Tiles > 0 then
			table.sort(group.Tiles, function(a: ResourceTile, b: ResourceTile): boolean
				return a.Index < b.Index
			end)
			for _, tile in group.Tiles do
				tile.AmountText = InventoryModel.amountText(tile.Amount)
				group.Total += tile.Amount
			end
			table.insert(groups, group)
		end
	end
	return groups
end

return InventoryModel
