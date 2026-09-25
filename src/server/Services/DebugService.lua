--!strict
-- Outils de test, actifs uniquement en Studio (jamais en jeu publié).
-- La ligne de commande de Studio obtient sa propre copie des modules avec require() :
-- elle ne voit donc pas les données chargées par le vrai DataService.
-- Ce service expose une BindableFunction ServerStorage.DebugData qu'on appelle depuis la ligne de commande (côté Serveur) :
--   game.ServerStorage.DebugData:Invoke(player, "Get")                     -> copie des données
--   game.ServerStorage.DebugData:Invoke(player, "AddCurrency", "Gold", 100) -> nouveau montant

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DataService = require(script.Parent.DataService)

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
