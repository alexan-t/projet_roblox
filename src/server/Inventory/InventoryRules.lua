--!strict
-- Règles pures de l'inventaire (#72, voir docs/ITEMS.md et docs/RESOURCES.md). Aucune API Roblox : testé par
-- tools/test-inventory.ps1. Modifie directement la table PlayerData passée en argument.
--
-- PlayerData.Inventory = {
--   Equipment = { [ItemInstanceId] = { ItemId = "item_015", UpgradeLevel = 0 } },  -- une entrée par EXEMPLAIRE
--   Resources = { [ResourceId] = entier >= 0 },                                     -- empilables
-- }
-- ItemId (catalogue) n'est pas l'instance possédée : deux exemplaires d'un même ItemId sont deux entrées
-- indépendantes, jamais fusionnées. Les ressources n'ont aucune rareté.
--
-- Lecture tolérante : table absente ou de mauvais type recréée vide ; entrée invalide (ItemId inconnu, niveau
-- ou quantité incorrects) IGNORÉE par les vues et les écritures, mais jamais supprimée de la sauvegarde.
--
-- catalogs = { Item = ItemConfig, Resource = ResourceConfig } (les catalogues existants).

export type Catalogs = { Item: any, Resource: any }
export type LootItem = { InstanceId: string, ItemId: string }
export type LootResource = { ResourceId: string, Amount: number }
export type Loot = { Items: { LootItem }, Resources: { LootResource }, Overflow: boolean }

local InventoryRules = {}

-- Borne technique d'une pile de ressources (sûreté des nombres, pas une règle de design).
InventoryRules.MAX_STACK = 1000000000

local ID_TRIES = 8

local function isCount(value: any): boolean
	return typeof(value) == "number" and value == value and value >= 0 and value < math.huge and value % 1 == 0
end

-- Inventaire de ces données, recréé (clés fixes Equipment / Resources) s'il manque ou si un type est faux.
function InventoryRules.ensure(data: any): any
	if typeof(data.Inventory) ~= "table" then
		data.Inventory = {}
	end
	local inventory = data.Inventory
	if typeof(inventory.Equipment) ~= "table" then
		inventory.Equipment = {}
	end
	if typeof(inventory.Resources) ~= "table" then
		inventory.Resources = {}
	end
	return inventory
end

-- Exemplaire lisible : id texte, ItemId du catalogue, UpgradeLevel entier >= 0.
local function validInstance(id: any, entry: any, catalogs: Catalogs): boolean
	return typeof(id) == "string" and id ~= "" and typeof(entry) == "table"
		and typeof(entry.ItemId) == "string" and catalogs.Item.Items[entry.ItemId] ~= nil
		and isCount(entry.UpgradeLevel)
end

-- Nombre d'exemplaires d'équipement valides (ceux qui comptent pour le plafond).
function InventoryRules.countEquipment(data: any, catalogs: Catalogs): number
	local count = 0
	for id, entry in InventoryRules.ensure(data).Equipment do
		if validInstance(id, entry, catalogs) then
			count += 1
		end
	end
	return count
end

-- Crée UN exemplaire d'équipement. newId : fabrique d'identifiants (injectable pour les tests).
-- Renvoie l'InstanceId, ou nil et la raison : "item inconnu", "plafond atteint", "identifiant invalide".
function InventoryRules.addEquipment(data: any, itemId: any, cap: number, newId: () -> string, catalogs: Catalogs): (string?, string?)
	if typeof(itemId) ~= "string" or catalogs.Item.Items[itemId] == nil then
		return nil, "item inconnu"
	end
	local equipment = InventoryRules.ensure(data).Equipment
	if InventoryRules.countEquipment(data, catalogs) >= cap then
		return nil, "plafond atteint"
	end
	for _ = 1, ID_TRIES do
		local id = newId()
		if typeof(id) == "string" and id ~= "" and equipment[id] == nil then
			equipment[id] = { ItemId = itemId, UpgradeLevel = 0 }
			return id, nil
		end
	end
	return nil, "identifiant invalide"
end

-- Ajoute des ressources à une pile. amount : entier >= 1. Renvoie la quantité réellement ajoutée (la pile est
-- bornée à MAX_STACK), ou nil et la raison : "ressource inconnue", "quantité invalide", "pile invalide".
function InventoryRules.addResource(data: any, resourceId: any, amount: any, catalogs: Catalogs): (number?, string?)
	if typeof(resourceId) ~= "string" or catalogs.Resource.Resources[resourceId] == nil then
		return nil, "ressource inconnue"
	end
	if not isCount(amount) or amount < 1 then
		return nil, "quantité invalide"
	end
	local resources = InventoryRules.ensure(data).Resources
	local current = resources[resourceId]
	if current == nil then
		current = 0
	elseif not isCount(current) then
		return nil, "pile invalide" -- jamais écrasée : on ne détruit pas une donnée inconnue
	end
	local after = math.min(InventoryRules.MAX_STACK, current + amount)
	resources[resourceId] = after
	return after - current, nil
end

-- Range le butin tiré (LootRules.roll) dans l'inventaire et renvoie le payload client :
--   Items      = exemplaires réellement créés { InstanceId, ItemId } ;
--   Resources  = quantités réellement ajoutées { ResourceId, Amount } (ordre du catalogue) ;
--   Overflow   = true si au moins un équipement n'a pas été créé (plafond). Les ressources sont toujours
--                accordées. Entrées invalides ignorées.
-- opts = { Cap, NewId, Catalogs }.
function InventoryRules.apply(data: any, rolled: any, opts: { Cap: number, NewId: () -> string, Catalogs: Catalogs }): Loot
	local loot: Loot = { Items = {}, Resources = {}, Overflow = false }
	for _, drop in if typeof(rolled) == "table" and typeof(rolled.Items) == "table" then rolled.Items else {} do
		local instanceId, reason = InventoryRules.addEquipment(data, drop.ItemId, opts.Cap, opts.NewId, opts.Catalogs)
		if instanceId then
			table.insert(loot.Items, { InstanceId = instanceId, ItemId = drop.ItemId })
		elseif reason == "plafond atteint" then
			loot.Overflow = true
		end
	end
	for _, drop in if typeof(rolled) == "table" and typeof(rolled.Resources) == "table" then rolled.Resources else {} do
		local added = InventoryRules.addResource(data, drop.ResourceId, drop.Amount, opts.Catalogs)
		if added and added > 0 then
			table.insert(loot.Resources, { ResourceId = drop.ResourceId, Amount = added })
		end
	end
	table.sort(loot.Resources, function(a, b)
		return opts.Catalogs.Resource.Resources[a.ResourceId].Index < opts.Catalogs.Resource.Resources[b.ResourceId].Index
	end)
	return loot
end

-- Vue en lecture seule envoyée au client (GetInventory / InventoryChanged) :
--   { Equipment = { { InstanceId, ItemId, UpgradeLevel } }  -- trié par InstanceId (ordre d'obtention)
--     Resources = { { ResourceId, Amount } }                 -- Amount >= 1, ordre du catalogue
--     Count = n, Cap = cap }
-- Copies : le client ne partage rien avec PlayerData. Aucune rareté : le client lit les catalogues.
function InventoryRules.view(data: any, cap: number, catalogs: Catalogs): any
	local inventory = InventoryRules.ensure(data)
	local equipment = {}
	for id, entry in inventory.Equipment do
		if validInstance(id, entry, catalogs) then
			table.insert(equipment, { InstanceId = id, ItemId = entry.ItemId, UpgradeLevel = entry.UpgradeLevel })
		end
	end
	table.sort(equipment, function(a, b)
		return a.InstanceId < b.InstanceId
	end)
	local resources = {}
	for _, info in catalogs.Resource.Ordered do
		local amount = inventory.Resources[info.Id]
		if isCount(amount) and amount >= 1 then
			table.insert(resources, { ResourceId = info.Id, Amount = amount })
		end
	end
	return { Equipment = equipment, Resources = resources, Count = #equipment, Cap = cap }
end

return InventoryRules
