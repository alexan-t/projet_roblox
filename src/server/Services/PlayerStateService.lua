--!strict
-- Vues en lecture seule de l'état du joueur pour l'interface (voir docs/UI_DESIGN_SYSTEM.md § 13).
-- Jamais PlayerData brut : seulement des copies des champs que le HUD affiche.
-- Remotes :
--   GetCurrencies (RemoteFunction) -> { Gold, Gems, SummonTickets } du joueur, ou nil (données non
--                                     chargées). Le client relit cet état après chaque événement qui
--                                     change les monnaies (fin de combat, invocation) ; il ne calcule
--                                     jamais une valeur lui-même.
--   GetPlayerStats (RemoteFunction) -> Stats (fenêtre « Stats » du menu), ou nil (données non chargées) :
--                                     comptes simples relus dans PlayerData, rien n'est calculé côté client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

export type Currencies = { Gold: number, Gems: number, SummonTickets: number }
export type Stats = {
	Heroes: number, -- exemplaires possédés
	UniqueHeroes: number, -- héros différents (HeroId)
	HighestLevel: number, -- meilleur niveau d'un héros
	StagesCleared: number, -- stages Normal gagnés au moins une fois (First Clears)
	EliteCleared: number, -- stages Élite gagnés au moins une fois
	Summons: number, -- invocations réussies
	KingdomLevel: number,
}

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

local function count(map: any): number
	local n = 0
	if typeof(map) == "table" then
		for _, value in map do
			if value == true then
				n += 1
			end
		end
	end
	return n
end

-- Statistiques du joueur (copies et comptes), ou nil si les données ne sont pas chargées.
function PlayerStateService:GetStats(player: Player): Stats?
	local data: any = if player:GetAttribute("DataLoaded") == true then DataService:GetData(player) else nil
	if not data then
		return nil
	end
	local heroes, unique, highest = 0, {}, 0
	for _, hero in if typeof(data.Heroes) == "table" then data.Heroes else {} do
		heroes += 1
		if typeof(hero.HeroId) == "string" then
			unique[hero.HeroId] = true
		end
		if typeof(hero.Level) == "number" then
			highest = math.max(highest, hero.Level)
		end
	end
	local uniqueCount = 0
	for _ in unique do
		uniqueCount += 1
	end
	local progression = data.Progression or {}
	return {
		Heroes = heroes,
		UniqueHeroes = uniqueCount,
		HighestLevel = highest,
		StagesCleared = count(progression.FirstClears),
		EliteCleared = count(progression.EliteFirstClears),
		Summons = if data.Summons and typeof(data.Summons.Total) == "number" then data.Summons.Total else 0,
		KingdomLevel = if data.Kingdom and typeof(data.Kingdom.Level) == "number" then data.Kingdom.Level else 1,
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
	local stats = Instance.new("RemoteFunction")
	stats.Name = "GetPlayerStats"
	stats.OnServerInvoke = function(player: Player): Stats?
		return PlayerStateService:GetStats(player)
	end
	stats.Parent = remotes
end

return PlayerStateService
