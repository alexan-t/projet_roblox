--!strict
-- Outils de test, actifs uniquement en Studio (jamais en jeu publié).
-- La ligne de commande de Studio obtient sa propre copie des modules avec require() :
-- elle ne voit donc pas les données chargées par le vrai DataService.
-- Ce service expose une BindableFunction ServerStorage.DebugData qu'on appelle depuis la ligne de commande (côté Serveur) :
--   game.ServerStorage.DebugData:Invoke(player, "Get")                     -> copie des données
--   game.ServerStorage.DebugData:Invoke(player, "AddCurrency", "Gold", 100) -> nouveau montant
--   game.ServerStorage.DebugData:Invoke(player, "SetKingdomState", 2)       -> résultat de KingdomService:Refresh
--   game.ServerStorage.DebugData:Invoke(player, "AddHero", "tireuse_des_faubourgs") -> identifiant (héros activé de HeroConfig, sinon nil)
--   game.ServerStorage.DebugData:Invoke(player, "RemoveHero", id)           -> true si retiré (HeroService)
--   game.ServerStorage.DebugData:Invoke(player, "SetHeroLevel", id, 20)      -> niveau de test (Studio uniquement)
--   game.ServerStorage.DebugData:Invoke(player, "AddItem", "item_015")        -> ItemInstanceId, ou nil et la raison
--                                                                             (exemplaire d'équipement de test, même
--                                                                             chemin que le loot : catalogue, plafond)
--   game.ServerStorage.DebugData:Invoke(player, "RefreshKingdom")           -> résultat de KingdomService:Refresh
--   game.ServerStorage.DebugData:Invoke(player, "GetActiveQuest")           -> QuestService:GetActiveQuest
--   game.ServerStorage.DebugData:Invoke(player, "QuestEvent", "StageCompleted", { Zone = 1, Stage = 1 })
--                                                                             -> QuestService:HandleGameplayEvent (simule ZoneService #7)
--   game.ServerStorage.DebugData:Invoke(player, "ClaimQuest", "DefendDomain") -> succès, raison du refus
--   game.ServerStorage.DebugData:Invoke(player, "SetQuestState", "DefeatRoiOrc", 1, false)
--                                                                             -> remet l'état d'UNE quête (test du panneau
--                                                                                Quêtes : terminée non réclamée) et pousse la vue
--   game.ServerStorage.DebugData:Invoke(player, "StartStage", 1, 1)         -> ZoneService:StartStage (session ou raison)
--   game.ServerStorage.DebugData:Invoke(player, "GetStageSession")          -> ZoneService:GetSession
--   game.ServerStorage.DebugData:Invoke(player, "CompleteStage", true)      -> fin de la session active (simule CombatService #8)
--   game.ServerStorage.DebugData:Invoke(player, "CancelStage")              -> ZoneService:CancelStage

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(script.Parent.DataService)
local HeroService = require(script.Parent.HeroService)
local KingdomService = require(script.Parent.KingdomService)
local QuestService = require(script.Parent.QuestService)
local ZoneService = require(script.Parent.ZoneService)
local HeroProgressionConfig = require(script.Parent.Parent.Config.HeroProgressionConfig)
local InventoryService = require(script.Parent.InventoryService)
local InventoryRules = require(script.Parent.Parent.Inventory.InventoryRules)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ITEM_CATALOGS = {
	Item = require(ReplicatedStorage.Shared.Config.ItemConfig),
	Resource = require(ReplicatedStorage.Shared.Config.ResourceConfig),
}

local DebugService = {}

local function handle(player: Player, command: string, ...: any): any
	local data = DataService:GetData(player)
	if not data then
		return "Données pas encore chargées"
	end
	if command == "Get" then
		return data
	elseif command == "AddCurrency" then
		local currency, amount = ...
		local currencies = data.Currencies :: { [string]: number }
		if typeof(currencies[currency]) ~= "number" or typeof(amount) ~= "number" then
			return `Devise ou montant invalide : {currency}, {amount}`
		end
		currencies[currency] += amount
		return currencies[currency]
	elseif command == "SetKingdomState" then
		local state = ...
		data.Kingdom.VisualState = state
		return KingdomService:Refresh(player)
	elseif command == "AddHero" then
		local heroId = ...
		if typeof(heroId) ~= "string" then
			return "HeroId invalide"
		end
		-- Hotbar si une case est libre, sinon collection (HeroService).
		return HeroService:AddHero(player, heroId)
	elseif command == "RemoveHero" then
		local id = ...
		return HeroService:RemoveHero(player, id)
	elseif command == "SetHeroLevel" then
		local id, level = ...
		local hero = if typeof(id) == "string" then data.Heroes[id] else nil
		if not hero or typeof(level) ~= "number" or level ~= math.floor(level)
			or level < 1 or level > HeroProgressionConfig.MaxLevel then
			return "Héros ou niveau invalide"
		end
		hero.Level, hero.XP = level, 0
		return level
	elseif command == "AddItem" then
		-- Recette de l'équipement (#73) : un exemplaire du catalogue, comme un loot (plafond compris).
		local itemId = ...
		local instanceId, reason = InventoryRules.addEquipment(data, itemId, InventoryService:GetCap(), function(): string
			return InventoryService:NewInstanceId()
		end, ITEM_CATALOGS)
		if instanceId then
			InventoryService:Push(player)
		end
		return instanceId, reason
	elseif command == "RefreshKingdom" then
		return KingdomService:Refresh(player)
	elseif command == "GetActiveQuest" then
		return QuestService:GetActiveQuest(player)
	elseif command == "QuestEvent" then
		local eventName, payload = ...
		return QuestService:HandleGameplayEvent(player, eventName, payload)
	elseif command == "ClaimQuest" then
		local questId = ...
		local ok, reason = QuestService:ClaimQuest(player, questId)
		return { Success = ok, Reason = reason }
	elseif command == "SetQuestState" then
		local questId, progress, claimed = ...
		if typeof(questId) ~= "string" or typeof(progress) ~= "number" or typeof(claimed) ~= "boolean" or data.Quests[questId] == nil then
			return `Quête, progression ou état invalide : {questId}, {progress}, {claimed}`
		end
		data.Quests[questId] = { Progress = progress, Claimed = claimed }
		QuestService:Notify(player)
		return QuestService:GetActiveQuest(player)
	elseif command == "StartStage" then
		local zone, stage = ...
		local session, reason = ZoneService:StartStage(player, zone, stage)
		return { Success = session ~= nil, Reason = reason, SessionId = session and session.Id }
	elseif command == "GetStageSession" then
		local session = ZoneService:GetSession(player)
		return session and { Id = session.Id, Zone = session.Zone, Stage = session.Stage, Status = session.Status }
	elseif command == "CompleteStage" then
		local victory = ...
		local session = ZoneService:GetSession(player)
		return session ~= nil and ZoneService:CompleteStage(player, session.Id, victory == true)
	elseif command == "CancelStage" then
		return ZoneService:CancelStage(player)
	end
	return `Commande inconnue : {command}`
end

function DebugService:Start()
	if not RunService:IsStudio() then
		return
	end
	local debugData = Instance.new("BindableFunction")
	debugData.Name = "DebugData"
	debugData.OnInvoke = handle
	debugData.Parent = ServerStorage
end

return DebugService
