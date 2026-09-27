--!strict
-- Outils de test, actifs uniquement en Studio (jamais en jeu publié).
-- La ligne de commande de Studio obtient sa propre copie des modules avec require() :
-- elle ne voit donc pas les données chargées par le vrai DataService.
-- Ce service expose une BindableFunction ServerStorage.DebugData qu'on appelle depuis la ligne de commande (côté Serveur) :
--   game.ServerStorage.DebugData:Invoke(player, "Get")                     -> copie des données
--   game.ServerStorage.DebugData:Invoke(player, "AddCurrency", "Gold", 100) -> nouveau montant
--   game.ServerStorage.DebugData:Invoke(player, "SetKingdomState", 2)       -> résultat de KingdomService:Refresh
--   game.ServerStorage.DebugData:Invoke(player, "AddHero", "Chevalier")     -> identifiant de l'exemplaire ajouté
--   game.ServerStorage.DebugData:Invoke(player, "RemoveHero", id)           -> résultat de KingdomService:Refresh
--   game.ServerStorage.DebugData:Invoke(player, "RefreshKingdom")           -> résultat de KingdomService:Refresh
--   game.ServerStorage.DebugData:Invoke(player, "GetActiveQuest")           -> QuestService:GetActiveQuest
--   game.ServerStorage.DebugData:Invoke(player, "QuestEvent", "StageCompleted", { Zone = 1, Stage = 1 })
--                                                                             -> QuestService:HandleGameplayEvent (simule ZoneService #7)
--   game.ServerStorage.DebugData:Invoke(player, "ClaimQuest", "DefendDomain") -> succès, raison du refus
--   game.ServerStorage.DebugData:Invoke(player, "StartStage", 1, 1)         -> ZoneService:StartStage (session ou raison)
--   game.ServerStorage.DebugData:Invoke(player, "GetStageSession")          -> ZoneService:GetSession
--   game.ServerStorage.DebugData:Invoke(player, "CompleteStage", true)      -> fin de la session active (simule CombatService #8)
--   game.ServerStorage.DebugData:Invoke(player, "CancelStage")              -> ZoneService:CancelStage

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(script.Parent.DataService)
local KingdomService = require(script.Parent.KingdomService)
local QuestService = require(script.Parent.QuestService)
local ZoneService = require(script.Parent.ZoneService)

local debugHeroCount = 0

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
		debugHeroCount += 1
		local id = `Debug_{os.time()}_{debugHeroCount}`
		data.Heroes[id] = { HeroId = heroId, Level = 1 }
		KingdomService:Refresh(player)
		return id
	elseif command == "RemoveHero" then
		local id = ...
		data.Heroes[id] = nil
		return KingdomService:Refresh(player)
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
