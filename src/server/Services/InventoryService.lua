--!strict
-- Inventaire en LECTURE SEULE pour le client (#72, voir docs/ITEMS.md et docs/RESOURCES.md).
-- Les mutations (loot) sont faites par RewardService via InventoryRules ; ce service ne fait que fabriquer les
-- identifiants d'exemplaires et publier la vue.
--
-- Remotes (ReplicatedStorage.Remotes) :
--   GetInventory (RemoteFunction)    -> vue { Equipment, Resources, Count, Cap } du joueur, ou nil sans données ;
--   InventoryChanged (RemoteEvent)   -> la même vue, poussée après chaque mutation.
-- AUCUN remote d'écriture (pas de GrantItem / GrantResource / équiper) : les arguments client sont ignorés.
-- La vue ne contient jamais de rareté : le client lit nom / rareté / slot / icône / famille dans ItemConfig et
-- ResourceConfig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local DataService = require(script.Parent.DataService)
local InventoryRules = require(script.Parent.Parent.Inventory.InventoryRules)
local LootConfig = require(script.Parent.Parent.Config.LootConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)

local CATALOGS = { Item = ItemConfig, Resource = ResourceConfig }

local InventoryService = {}

local changedEvent: RemoteEvent? = nil
local idSequence = 0

-- Identifiant d'exemplaire unique, horodaté (largeur fixe), même patron que HeroService.newId : le tri par
-- InstanceId donne l'ordre d'obtention. Préfixe « I_T » (équipement) ; le GUID évite toute collision.
function InventoryService:NewInstanceId(): string
	idSequence = (idSequence + 1) % 10000
	return string.format("I_T%010d%04d_%s", os.time(), idSequence, HttpService:GenerateGUID(false))
end

-- Plafond d'instances d'équipement (LootConfig.EquipmentCap, PROVISOIRE).
function InventoryService:GetCap(): number
	return LootConfig.EquipmentCap
end

local function loaded(player: Player): any
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
		return nil
	end
	return DataService:GetData(player)
end

-- Vue de l'inventaire du joueur, ou nil si ses données ne sont pas chargées.
function InventoryService:GetView(player: Player): any
	local data = loaded(player)
	return if data then InventoryRules.view(data, LootConfig.EquipmentCap, CATALOGS) else nil
end

-- Pousse la vue à jour au client (après une mutation). Sans effet si les données ne sont pas chargées.
function InventoryService:Push(player: Player)
	local event = changedEvent
	local view = InventoryService:GetView(player)
	if event and view then
		event:FireClient(player, view)
	end
end

function InventoryService:Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	assert(remotes)
	local event = Instance.new("RemoteEvent")
	event.Name = "InventoryChanged"
	event.Parent = remotes
	changedEvent = event
	local get = Instance.new("RemoteFunction")
	get.Name = "GetInventory"
	get.OnServerInvoke = function(player: Player): any
		-- Les arguments du client sont ignorés : la vue ne dépend que des données serveur du joueur.
		return InventoryService:GetView(player)
	end
	get.Parent = remotes
end

return InventoryService
