--!strict
-- Équiper / retirer un objet sur un exemplaire de héros (#73, voir docs/ITEMS.md § Équipement V1).
-- Seul point d'écriture de PlayerData.HeroEquipment. Les règles sont dans EquipmentRules (pures) ; les stats sont
-- calculées par HeroService (roster figé au lancement du combat, vue de la Sacoche).
--
-- Remote (ReplicatedStorage.Remotes) :
--   EquipmentAction (RemoteFunction)
--     ("Equip", heroInstanceId, itemInstanceId)  -> (true, { Slot, Replaced? }) | (false, raison)
--     ("Unequip", heroInstanceId, slotType)       -> (true, { Slot, Replaced = objet retiré }) | (false, raison)
-- Le client n'envoie que des identifiants d'exemplaires (et le slot pour Retirer) : le serveur retrouve lui-même
-- ItemId, SlotType, rareté, bonus et propriété. Tout argument en plus est refusé ; aucune stat n'est acceptée.
-- Refus : données non chargées, action inconnue, rafale (EquipmentConfig.ActionCooldown), combat en cours (le
-- roster est figé au lancement ; changer la Sacoche ne doit pas modifier la session), héros ou objet inconnu ou
-- non possédé, slot incompatible, objet porté par un autre héros, emplacement vide.
-- Après un succès : HeroesChanged (stats finales) puis InventoryChanged (porteur de chaque objet).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local EquipmentConfig = require(script.Parent.Parent.Config.EquipmentConfig)
local EquipmentRules = require(script.Parent.Parent.Inventory.EquipmentRules)
local DataService = require(script.Parent.DataService)
local HeroService = require(script.Parent.HeroService)
local InventoryService = require(script.Parent.InventoryService)
local CombatService = require(script.Parent.CombatService)

local SCOPE = "EquipmentService"
local CATALOGS = { Item = ItemConfig }

local EquipmentService = {}

local lastAction: { [Player]: number } = {}
local enabled = true

local function loaded(player: Player): any
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
		return nil
	end
	return DataService:GetData(player)
end

-- Après une mutation : stats finales (héros) puis porteurs (inventaire).
local function publish(player: Player)
	HeroService:Push(player)
	InventoryService:Push(player)
end

-- Équipe `itemInstanceId` sur `heroInstanceId` (le slot vient du catalogue).
function EquipmentService:Equip(player: Player, heroInstanceId: any, itemInstanceId: any): (boolean, any)
	local data = loaded(player)
	if not data then
		return false, "données non chargées"
	end
	if CombatService:IsInCombat(player) then
		return false, "combat en cours"
	end
	local ok, reason, result = EquipmentRules.equip(data, heroInstanceId, itemInstanceId, CATALOGS)
	if not ok then
		return false, reason
	end
	publish(player)
	return true, result
end

-- Retire l'objet du slot `slotType` de `heroInstanceId` ; l'objet reste dans l'inventaire.
function EquipmentService:Unequip(player: Player, heroInstanceId: any, slotType: any): (boolean, any)
	local data = loaded(player)
	if not data then
		return false, "données non chargées"
	end
	if CombatService:IsInCombat(player) then
		return false, "combat en cours"
	end
	local ok, reason, result = EquipmentRules.unequip(data, heroInstanceId, slotType, CATALOGS)
	if not ok then
		return false, reason
	end
	publish(player)
	return true, result
end

function EquipmentService:Init()
	local problems = EquipmentRules.configProblems(EquipmentConfig, CATALOGS, RarityConfig.Tiers)
	if #problems > 0 then
		-- Config invalide : aucune mutation ; HeroService et InventoryService n'appliquent alors aucun bonus
		-- (EquipmentRules.activeConfig) : les stats de combat restent celles du niveau seul, sans erreur.
		enabled = false
		for _, problem in problems do
			Log.warn(SCOPE, `EquipmentConfig invalide : {problem}`)
		end
	end
end

function EquipmentService:Start()
	-- Liens invalides (héros supprimé, objet absent, slot incompatible, doublon) nettoyés au chargement ; les
	-- objets restent dans l'inventaire.
	DataService:OnPlayerReady(function(player: Player, data: any)
		if data then
			local removed = EquipmentRules.normalize(data, CATALOGS)
			if removed > 0 then
				Log.warn(SCOPE, `{removed} lien(s) d'équipement invalide(s) retiré(s) pour {player.Name}`)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastAction[player] = nil
	end)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	assert(remotes)
	local action = Instance.new("RemoteFunction")
	action.Name = "EquipmentAction"
	action.OnServerInvoke = function(player: Player, verb: any, heroInstanceId: any, target: any, ...: any): (boolean, any)
		if select("#", ...) > 0 then
			return false, "arguments interdits"
		end
		if not enabled then
			return false, "équipement indisponible"
		end
		local now = os.clock()
		if now - (lastAction[player] or -math.huge) < EquipmentConfig.ActionCooldown then
			return false, "réessaie dans un instant"
		end
		lastAction[player] = now
		if verb == "Equip" then
			return EquipmentService:Equip(player, heroInstanceId, target)
		elseif verb == "Unequip" then
			return EquipmentService:Unequip(player, heroInstanceId, target)
		end
		return false, "action inconnue"
	end
	action.Parent = remotes
end

return EquipmentService
