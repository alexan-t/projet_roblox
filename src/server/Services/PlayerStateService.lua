--!strict
-- Vues en lecture seule de l'état du joueur pour l'interface (voir docs/UI_DESIGN_SYSTEM.md § 13).
-- Jamais PlayerData brut : seulement des copies des champs que le HUD affiche.
-- Remotes :
--   GetCurrencies (RemoteFunction) -> { Gold, Gems, SummonTickets } du joueur, ou nil (données non
--                                     chargées). Le client relit cet état après chaque événement qui
--                                     change les monnaies (fin de combat, invocation) ; il ne calcule
--                                     jamais une valeur lui-même.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

export type Currencies = { Gold: number, Gems: number, SummonTickets: number }

local PlayerStateService = {}

-- Copie des trois monnaies affichées, ou nil si les données ne sont pas chargées.
function PlayerStateService:GetCurrencies(player: Player): Currencies?
	local data = if player:GetAttribute("DataLoaded") == true then DataService:GetData(player) else nil
	local currencies = data and data.Currencies
	if not currencies then
		return nil
	end
	return {
		Gold = currencies.Gold,
		Gems = currencies.Gems,
		SummonTickets = currencies.SummonTickets,
	}
end

function PlayerStateService:Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	assert(remotes)
	local get = Instance.new("RemoteFunction")
	get.Name = "GetCurrencies"
	get.OnServerInvoke = function(player: Player): Currencies?
		return PlayerStateService:GetCurrencies(player)
	end
	get.Parent = remotes
end

return PlayerStateService
