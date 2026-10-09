--!strict
-- Récompenses de stage et First Clear (voir docs/REWARDS.md). Seul propriétaire de :
-- « premier clear ? → quelle récompense ? → mutation PlayerData → résultat présenté au client ».
-- Appelé par ZoneService à la victoire (même point que QuestService), jamais par le client :
-- aucun remote de réclamation. La récompense est sauvegardée avant tout affichage.
--
-- Garanties :
--   • First Clear unique dans toute la sauvegarde (Progression.FirstClears["<zone>-<stage>"]) ;
--   • une seule attribution par completion (identifiant de la session de stage) : une même
--     victoire traitée deux fois ne donne jamais FirstClearReward + RepeatReward ;
--   • vérification et mutation synchrones, sans aucun yield entre les deux.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local DataService = require(script.Parent.DataService)
local RewardConfig = require(script.Parent.Parent.Config.RewardConfig)
local RewardRules = require(script.Parent.Parent.Rewards.RewardRules)

export type Result = RewardRules.Result

local SCOPE = "RewardService"

local RewardService = {}

-- stages[key] = entrée validée ; false = entrée déclarée mais invalide (aucune récompense).
local stages: { [string]: RewardRules.StageRewards | false } = {}
-- Completions déjà récompensées, par joueur (mémoire du serveur).
local handled: { [Player]: { [any]: boolean } } = {}

local function loadConfig(config: any)
	table.clear(stages)
	if typeof(config) ~= "table" or typeof(config.Stages) ~= "table" then
		Log.warn(SCOPE, "RewardConfig.Stages manquant : aucune récompense de stage")
		return
	end
	for key, entry in config.Stages do
		local problems = RewardRules.stageProblems(entry)
		if typeof(key) ~= "string" then
			table.insert(problems, "clé \"<zone>-<stage>\" attendue")
		end
		if #problems > 0 then
			for _, problem in problems do
				Log.warn(SCOPE, `Récompenses {tostring(key)} invalides : {problem}`)
			end
			stages[tostring(key)] = false
		else
			stages[key] = entry
		end
	end
end

-- Attribue les récompenses de la victoire `completionId` du stage zone-stage.
-- Renvoie { FirstClear, Rewards } (récompenses réellement ajoutées), ou nil et la raison.
function RewardService:HandleStageCompleted(player: Player, zone: number, stage: number, completionId: any): (Result?, string?)
	local data = if player:GetAttribute("DataLoaded") == true then DataService:GetData(player) else nil
	if player.Parent ~= Players or not data then
		return nil, "données non chargées"
	end
	if completionId == nil then
		return nil, "completion inconnue"
	end
	local key = `{zone}-{stage}`
	local entry = stages[key]
	if entry == nil then
		return nil, "stage inconnu"
	end
	if entry == false then
		return nil, "récompenses invalides"
	end
	local done = handled[player]
	if not done then
		done = {}
		handled[player] = done
	end
	if done[completionId] then
		return nil, "completion déjà récompensée"
	end
	-- Section critique, sans yield : marquer la completion, puis First Clear et devises.
	done[completionId] = true
	local result = RewardRules.grant(data, key, entry)
	Log.info(SCOPE, `{player.Name} : stage {key} {if result.FirstClear then "premier clear" else "replay"} récompensé`)
	return result, nil
end

function RewardService:Init()
	loadConfig(RewardConfig)
end

function RewardService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		handled[player] = nil
	end)
end

return RewardService
