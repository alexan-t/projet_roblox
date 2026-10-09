--!strict
-- Règles pures des récompenses de stage (voir docs/REWARDS.md). Aucune API Roblox : testé par
-- tools/test-rewards.ps1. Modifie directement la table PlayerData passée en argument.

export type Reward = { Kind: string, Amount: number, New: boolean? }
export type StageRewards = { FirstClearReward: { Reward }, RepeatReward: { Reward } }
export type Result = { FirstClear: boolean, Rewards: { Reward } }

local RewardRules = {}

-- Type de récompense -> champ de PlayerData.Currencies. Tout autre Kind est refusé.
RewardRules.CURRENCY = table.freeze({
	Gold = "Gold",
	Gems = "Gems",
	SummonTicket = "SummonTickets",
} :: { [string]: string })

local function isAmount(value: any): boolean
	return typeof(value) == "number" and value == value and value >= 0 and value < math.huge and value % 1 == 0
end

local function listProblems(list: any, where: string, problems: { string })
	if typeof(list) ~= "table" then
		table.insert(problems, `{where} : liste attendue`)
		return
	end
	local count = 0
	for _ in list do
		count += 1
	end
	if count ~= #list then
		table.insert(problems, `{where} : liste 1..n attendue`)
	end
	for index, reward in list do
		local at = `{where}[{index}]`
		if typeof(reward) ~= "table" then
			table.insert(problems, `{at} : récompense attendue`)
		elseif typeof(reward.Kind) ~= "string" or RewardRules.CURRENCY[reward.Kind] == nil then
			table.insert(problems, `{at} : Kind inconnu ({tostring(reward.Kind)})`)
		elseif not isAmount(reward.Amount) then
			table.insert(problems, `{at} : Amount doit être un entier fini >= 0`)
		elseif reward.New ~= nil and typeof(reward.New) ~= "boolean" then
			table.insert(problems, `{at} : New doit être un booléen`)
		end
	end
end

-- Problèmes d'une entrée de stage ; vide si elle est utilisable.
function RewardRules.stageProblems(entry: any): { string }
	local problems: { string } = {}
	if typeof(entry) ~= "table" then
		table.insert(problems, "entrée de stage attendue")
		return problems
	end
	listProblems(entry.FirstClearReward, "FirstClearReward", problems)
	listProblems(entry.RepeatReward, "RepeatReward", problems)
	return problems
end

-- Copie d'une liste de récompenses (le résultat renvoyé ne partage rien avec la config).
local function copy(list: { Reward }): { Reward }
	local out: { Reward } = {}
	for _, reward in list do
		table.insert(out, { Kind = reward.Kind, Amount = reward.Amount, New = reward.New })
	end
	return out
end

-- Attribution synchrone, sans aucun yield entre la vérification et la mutation :
--   pas encore de FirstClear → FirstClears[key] = true, puis FirstClearReward ;
--   sinon                    → RepeatReward.
-- L'entrée doit avoir été validée (stageProblems vide).
function RewardRules.grant(data: any, key: string, entry: StageRewards): Result
	local firstClears = data.Progression.FirstClears
	local first = firstClears[key] ~= true
	local list = if first then entry.FirstClearReward else entry.RepeatReward
	if first then
		firstClears[key] = true
	end
	local currencies = data.Currencies
	for _, reward in list do
		local field = RewardRules.CURRENCY[reward.Kind]
		currencies[field] = (currencies[field] or 0) + reward.Amount
	end
	return { FirstClear = first, Rewards = copy(list) }
end

return RewardRules
