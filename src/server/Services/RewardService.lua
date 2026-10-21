--!strict
-- Récompenses de stage et First Clear (voir docs/REWARDS.md). Seul propriétaire de :
-- « premier clear ? → quelle récompense ? → mutation PlayerData → résultat présenté au client ».
-- Appelé par ZoneService à la victoire (même point que QuestService), jamais par le client :
-- aucun remote de réclamation. La récompense est sauvegardée avant tout affichage.
--
-- Garanties :
--   • First Clear unique dans toute la sauvegarde (Progression.FirstClears["<zone>-<stage>"] en Normal,
--     Progression.EliteFirstClears en Élite : deux progressions indépendantes, RewardConfig.EliteStages) ;
--   • une seule attribution par completion (identifiant de la session de stage) : une même
--     victoire traitée deux fois ne donne jamais FirstClearReward + RepeatReward ;
--   • vérification et mutation synchrones, sans aucun yield entre les deux ;
--   • loot (#72) : tirage et rangement dans PlayerData.Inventory dans cette MÊME section synchrone et avec la
--     même identité de completion (marquée avant) : une victoire ne donne jamais deux butins. Le tirage est
--     serveur (Random), jamais le client. Une erreur ou une config de loot invalide ne bloque JAMAIS le First
--     Clear ni les monnaies : Result.Loot est alors nil. Défaite : RewardService n'est pas appelé, aucun loot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local DataService = require(script.Parent.DataService)
local RewardConfig = require(script.Parent.Parent.Config.RewardConfig)
local RewardRules = require(script.Parent.Parent.Rewards.RewardRules)
local LootConfig = require(script.Parent.Parent.Config.LootConfig)
local LootRules = require(script.Parent.Parent.Loot.LootRules)
local InventoryRules = require(script.Parent.Parent.Inventory.InventoryRules)
local InventoryService = require(script.Parent.InventoryService)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)

-- Butin d'une victoire, séparé des monnaies (jamais dans Rewards). Le client lit nom / rareté / slot / famille
-- dans ItemConfig et ResourceConfig : le serveur n'envoie jamais de rareté.
export type Loot = InventoryRules.Loot
export type Result = { FirstClear: boolean, Rewards: { RewardRules.Reward }, Loot: Loot? }

local SCOPE = "RewardService"

local RewardService = {}

-- stages[key] = entrée validée ; false = entrée déclarée mais invalide (aucune récompense).
local stages: { [string]: RewardRules.StageRewards | false } = {}
-- Même chose pour le Mode Élite (RewardConfig.EliteStages).
local eliteStages: { [string]: RewardRules.StageRewards | false } = {}
-- LootConfig validée à l'Init (nil = aucun loot, avec warning). Catalogues = ceux du jeu, jamais copiés.
local lootConfig: any = nil
local random: Random? = nil
local LOOT_CATALOGS = { Item = ItemConfig, Resource = ResourceConfig, Rarity = RarityConfig }
-- Completions déjà récompensées, par joueur (mémoire du serveur).
local handled: { [Player]: { [any]: boolean } } = {}

local function loadTable(source: any, target: { [string]: RewardRules.StageRewards | false })
	table.clear(target)
	for key, entry in source do
		local problems = RewardRules.stageProblems(entry)
		if typeof(key) ~= "string" then
			table.insert(problems, "clé \"<zone>-<stage>\" attendue")
		end
		if #problems > 0 then
			for _, problem in problems do
				Log.warn(SCOPE, `Récompenses {tostring(key)} invalides : {problem}`)
			end
			target[tostring(key)] = false
		else
			target[key] = entry
		end
	end
end

local function loadConfig(config: any)
	table.clear(stages)
	table.clear(eliteStages)
	if typeof(config) ~= "table" or typeof(config.Stages) ~= "table" then
		Log.warn(SCOPE, "RewardConfig.Stages manquant : aucune récompense de stage")
		return
	end
	loadTable(config.Stages, stages)
	if typeof(config.EliteStages) == "table" then
		loadTable(config.EliteStages, eliteStages)
	end
end

local function loadLoot(config: any)
	lootConfig = nil
	local problems = LootRules.problems(config, LOOT_CATALOGS)
	if #problems > 0 then
		for _, problem in problems do
			Log.warn(SCOPE, `LootConfig invalide : {problem}`)
		end
		Log.warn(SCOPE, "LootConfig invalide : aucun loot (First Clear et monnaies inchangés)")
		return
	end
	lootConfig = config
end

-- Tire et range le butin de cette victoire. Sans yield. Toute erreur est absorbée (pcall) : le loot est un
-- bonus, il ne doit jamais empêcher le First Clear ni les monnaies déjà attribués.
local function grantLoot(player: Player, data: any, key: string, isElite: boolean, firstClear: boolean): Loot?
	local config = lootConfig
	if not config then
		return nil
	end
	local entries = if isElite then config.EliteStages else config.Stages
	local entry = entries[key]
	if not entry then
		return nil -- zone / stage sans table de loot : aucun loot, pas d'erreur
	end
	local ok, loot = pcall(function(): Loot
		local rng = random
		assert(rng, "Random manquant")
		local rolled = LootRules.roll(entry, rng, { FirstClear = firstClear, Catalogs = LOOT_CATALOGS })
		return InventoryRules.apply(data, rolled, {
			Cap = config.EquipmentCap,
			NewId = function(): string
				return InventoryService:NewInstanceId()
			end,
			Catalogs = LOOT_CATALOGS,
		})
	end)
	if not ok then
		Log.warn(SCOPE, `Loot {key} de {player.Name} en échec : {tostring(loot)}`)
		InventoryService:Push(player) -- une mutation partielle éventuelle reste visible dans la Sacoche
		return nil
	end
	return loot :: Loot
end

-- Attribue les récompenses de la victoire `completionId` du stage zone-stage, dans ce mode (nil = Normal ;
-- "Elite" : RewardConfig.EliteStages et Progression.EliteFirstClears).
-- Renvoie { FirstClear, Rewards, Loot? } (récompenses et butin réellement ajoutés), ou nil et la raison.
function RewardService:HandleStageCompleted(player: Player, zone: number, stage: number, completionId: any, mode: string?): (Result?, string?)
	local data = if player:GetAttribute("DataLoaded") == true then DataService:GetData(player) else nil
	if player.Parent ~= Players or not data then
		return nil, "données non chargées"
	end
	if completionId == nil then
		return nil, "completion inconnue"
	end
	local isElite = mode == "Elite"
	if mode ~= nil and mode ~= "Normal" and not isElite then
		return nil, "mode inconnu"
	end
	local key = `{zone}-{stage}`
	local entry = if isElite then eliteStages[key] else stages[key]
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
	-- Section critique, sans yield : marquer la completion, puis First Clear et devises, puis loot.
	done[completionId] = true
	local granted = RewardRules.grant(data, key, entry, if isElite then "EliteFirstClears" else "FirstClears")
	local result: Result = { FirstClear = granted.FirstClear, Rewards = granted.Rewards, Loot = nil }
	result.Loot = grantLoot(player, data, key, isElite, result.FirstClear)
	if result.Loot then
		InventoryService:Push(player)
	end
	Log.info(SCOPE, `{player.Name} : stage {key}{if isElite then " Élite" else ""} {if result.FirstClear then "premier clear" else "replay"} récompensé`)
	return result, nil
end

function RewardService:Init()
	loadConfig(RewardConfig)
	loadLoot(LootConfig)
	random = Random.new()
end

function RewardService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		handled[player] = nil
	end)
end

return RewardService
