--!strict
-- Aperçu d'un stage pour la fenêtre Expédition (voir docs/ZONES.md § Fenêtre Expédition). Module pur,
-- sans Instance : ArenaService l'assemble à partir des VRAIES configs serveur et l'envoie en lecture seule.
-- Le client n'invente rien : ce qui n'est pas configuré n'est pas envoyé (section masquée côté UI).
--   Waves             : vagues dans l'ordre, { Enemies = { { EnemyId, Count } } } (StageConfig) ;
--   Boss              : EnemyId du boss de zone (StageConfig.MiniBoss, après la dernière vague) ou nil ;
--   HeroXP            : XP d'une victoire pour CHAQUE héros posé (HeroProgressionConfig, Normal / Élite) ;
--   FirstClearRewards : récompenses de la première victoire de ce stage dans ce mode (RewardConfig) ;
--   RepeatRewards     : récompenses de chaque victoire suivante. Sémantique de RewardRules.grant : la
--                       première victoire donne FirstClearRewards SEULEMENT, les suivantes RepeatRewards ;
--   Multipliers       : Élite seulement, { MaxHealth, AttackDamage } (EliteConfig) ;
--   PotentialDrops    : butin possible par victoire, { { Kind = "Resource" | "Item", Id, Chance (0..1),
--                       Min, Max } }, UNIQUEMENT si une table de loot réelle est fournie (#72) ; sinon nil.

export type Reward = { Kind: string, Amount: number }
export type Drop = { Kind: string, Id: string, Chance: number, Min: number, Max: number }
export type Wave = { Enemies: { { EnemyId: string, Count: number } } }
export type Preview = {
	Waves: { Wave },
	Boss: string?,
	HeroXP: number,
	FirstClearRewards: { Reward },
	RepeatRewards: { Reward },
	Multipliers: { MaxHealth: number, AttackDamage: number }?,
	PotentialDrops: { Drop }?,
}

local StagePreview = {}

local function rewards(list: any): { Reward }
	local out: { Reward } = {}
	for _, reward in if typeof(list) == "table" then list else {} do
		if typeof(reward) == "table" and typeof(reward.Kind) == "string" and typeof(reward.Amount) == "number" and reward.Amount > 0 then
			table.insert(out, { Kind = reward.Kind, Amount = reward.Amount })
		end
	end
	return out
end

-- Butin : copie des entrées valides seulement (chance 0..1, quantités entières), jamais inventé.
local function drops(list: any): { Drop }?
	if typeof(list) ~= "table" then
		return nil
	end
	local out: { Drop } = {}
	for _, drop in list do
		if typeof(drop) == "table" and (drop.Kind == "Resource" or drop.Kind == "Item") and typeof(drop.Id) == "string"
			and typeof(drop.Chance) == "number" and drop.Chance > 0 and drop.Chance <= 1 then
			local min = if typeof(drop.Min) == "number" then drop.Min else 1
			local max = if typeof(drop.Max) == "number" then drop.Max else min
			table.insert(out, { Kind = drop.Kind, Id = drop.Id, Chance = drop.Chance, Min = min, Max = max })
		end
	end
	return if #out > 0 then out else nil
end

-- stage : entrée de StageConfig ; mode : "Normal" / "Elite" ; key : "<zone>-<stage>" ;
-- sources = { Rewards = RewardConfig, Progression = HeroProgressionConfig, Elite = EliteConfig,
--             Drops = table de butin du stage (#72) ou nil }.
function StagePreview.build(stage: any, zone: number, stageNumber: number, mode: string, sources: any): Preview
	local elite = mode == "Elite"
	local key = `{zone}-{stageNumber}`
	local waves: { Wave } = {}
	for _, wave in if typeof(stage) == "table" and typeof(stage.Waves) == "table" then stage.Waves else {} do
		local enemies = {}
		for _, group in wave.Enemies or {} do
			table.insert(enemies, { EnemyId = group.EnemyId, Count = group.Count })
		end
		table.insert(waves, { Enemies = enemies })
	end
	local rewardTable = sources.Rewards and (if elite then sources.Rewards.EliteStages else sources.Rewards.Stages)
	local entry = rewardTable and rewardTable[key]
	local xpTable = sources.Progression and (if elite then sources.Progression.EliteStageXP else sources.Progression.StageXP)
	local multipliers = nil
	if elite then
		local zoneConfig = sources.Elite and sources.Elite.Zones and sources.Elite.Zones[zone]
		local m = zoneConfig and zoneConfig.Stages and zoneConfig.Stages[stageNumber]
		if m then
			multipliers = { MaxHealth = m.MaxHealth or 1, AttackDamage = m.AttackDamage or 1 }
		end
	end
	return {
		Waves = waves,
		Boss = if typeof(stage) == "table" and typeof(stage.MiniBoss) == "table" then stage.MiniBoss.EnemyId else nil,
		HeroXP = if xpTable and typeof(xpTable[key]) == "number" then xpTable[key] else 0,
		FirstClearRewards = rewards(entry and entry.FirstClearReward),
		RepeatRewards = rewards(entry and entry.RepeatReward),
		Multipliers = multipliers,
		PotentialDrops = drops(sources.Drops),
	}
end

return StagePreview
