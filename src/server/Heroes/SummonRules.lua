--!strict
-- Règles pures de l'invocation Alpha (voir docs/HEROES.md). Aucune API Roblox, aucun yield :
-- testé par tools/test-heroes.ps1. Modifie directement la table PlayerData.

local HeroRules = require(script.Parent.HeroRules)

local SummonRules = {}

export type Result = {
	InstanceId: string,
	HeroId: string,
	New: boolean, -- premier exemplaire de ce HeroId pour le joueur
	Slot: number?, -- raccourci de hotbar utilisé, nil si la hotbar était pleine
	First: boolean, -- toute première invocation du profil
	KingdomChanged: boolean, -- Kingdom.VisualState vient de passer de KingdomFrom à KingdomTo
}

-- Problèmes de config (HeroId inconnus du catalogue, coût invalide) ; vide si elle est utilisable.
function SummonRules.configProblems(config: any, catalog: { [string]: any }): { string }
	local problems: { string } = {}
	if typeof(config.Cost) ~= "number" or config.Cost < 1 or config.Cost % 1 ~= 0 then
		table.insert(problems, "Cost doit être un entier >= 1")
	end
	if not catalog[config.FirstSummon] then
		table.insert(problems, `FirstSummon inconnu : {tostring(config.FirstSummon)}`)
	end
	if typeof(config.Pool) ~= "table" or #config.Pool == 0 then
		table.insert(problems, "Pool doit être une liste non vide")
	else
		for _, heroId in config.Pool do
			if not catalog[heroId] then
				table.insert(problems, `Pool : HeroId inconnu {tostring(heroId)}`)
			end
		end
	end
	return problems
end

-- Le joueur a-t-il de quoi payer une invocation ?
function SummonRules.canPay(data: any, config: any): boolean
	local tickets = data.Currencies.SummonTickets
	return typeof(tickets) == "number" and tickets >= config.Cost
end

-- Transaction complète, synchrone : revérifie le ticket, choisit le héros, débite, crée
-- l'exemplaire (hotbar si une case est libre), compte l'invocation et, à la toute première,
-- fait évoluer le royaume une seule fois. `pick(n)` renvoie un entier dans [1, n] (tirages suivants).
-- Renvoie le résultat, ou nil et la raison sans rien modifier.
function SummonRules.summon(data: any, config: any, makeId: () -> string, pick: (number) -> number): (Result?, string?)
	if not SummonRules.canPay(data, config) then
		return nil, "pas de ticket d'invocation"
	end
	local summons = data.Summons
	local total = if typeof(summons) == "table" and typeof(summons.Total) == "number" then summons.Total else 0
	local first = total == 0
	local heroId = if first then config.FirstSummon else config.Pool[math.clamp(pick(#config.Pool), 1, #config.Pool)]
	local new = not HeroRules.owns(data, heroId)

	data.Currencies.SummonTickets -= config.Cost
	local instanceId = makeId()
	local slot = HeroRules.addHero(data, instanceId, heroId)
	data.Summons = { Total = total + 1 }
	local kingdomChanged = false
	if first and data.Kingdom.VisualState == config.KingdomFrom then
		data.Kingdom.VisualState = config.KingdomTo
		kingdomChanged = true
	end
	return {
		InstanceId = instanceId,
		HeroId = heroId,
		New = new,
		Slot = slot,
		First = first,
		KingdomChanged = kingdomChanged,
	}, nil
end

return SummonRules
