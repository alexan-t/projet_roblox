--!strict
-- Règles pures des niveaux et de l'XP des héros (voir docs/HEROES.md § Niveaux et XP). Aucune API
-- Roblox, aucun yield : testé par tools/test-heroes.ps1. Toutes les valeurs viennent de
-- HeroProgressionConfig (passée en paramètre).
--   Level : 1..MaxLevel ; XP : progression DANS le niveau courant (0 ≤ XP < xpToNext), 0 au niveau max.

local HeroProgressionRules = {}

export type Config = {
	MaxLevel: number,
	FirstLevelXP: number,
	PerLevelXP: number,
	StatGrowth: { [string]: number },
	StageXP: { [string]: number },
	EliteStageXP: { [string]: number }?,
}

local function isLevel(value: any, config: Config): boolean
	return typeof(value) == "number" and value % 1 == 0 and value >= 1 and value <= config.MaxLevel
end

-- XP requise pour passer de `level` à `level + 1` ; 0 au niveau maximum.
function HeroProgressionRules.xpToNext(level: number, config: Config): number
	if level >= config.MaxLevel then
		return 0
	end
	return config.FirstLevelXP + config.PerLevelXP * (level - 1)
end

-- Niveau et XP valides d'un exemplaire (lecture tolérante : valeurs absentes ou invalides réparées).
function HeroProgressionRules.normalize(hero: any, config: Config): (number, number)
	local level = if isLevel(hero.Level, config) then hero.Level else 1
	local xp = hero.XP
	if typeof(xp) ~= "number" or xp ~= xp or xp < 0 or level >= config.MaxLevel then
		xp = 0
	end
	xp = math.floor(xp)
	local need = HeroProgressionRules.xpToNext(level, config)
	if need > 0 and xp >= need then
		xp = need - 1 -- jamais un niveau « plein » non converti
	end
	return level, xp
end

export type Grant = { LevelBefore: number, LevelAfter: number, XPGranted: number, XP: number, XPToNext: number }

-- Ajoute `amount` XP à l'exemplaire (modifie hero.Level et hero.XP) : plusieurs niveaux d'un coup
-- possibles ; au niveau maximum, l'XP reste à 0 et le surplus est perdu. Renvoie le détail.
function HeroProgressionRules.grantXP(hero: any, amount: number, config: Config): Grant
	local level, xp = HeroProgressionRules.normalize(hero, config)
	local before = level
	local gained = if typeof(amount) == "number" and amount > 0 and amount == amount then math.floor(amount) else 0
	if level >= config.MaxLevel then
		gained = 0
	end
	xp += gained
	while level < config.MaxLevel do
		local need = HeroProgressionRules.xpToNext(level, config)
		if xp < need then
			break
		end
		xp -= need
		level += 1
	end
	if level >= config.MaxLevel then
		xp = 0
	end
	hero.Level, hero.XP = level, xp
	return { LevelBefore = before, LevelAfter = level, XPGranted = gained, XP = xp, XPToNext = HeroProgressionRules.xpToNext(level, config) }
end

-- Stats de combat d'un exemplaire de ce niveau : copie des stats de base (CombatConfig.Heroes[profil]),
-- seules les stats de StatGrowth sont multipliées par 1 + (Level - 1) × bonus, arrondies à l'entier.
-- Lv1 = stats de base exactement.
function HeroProgressionRules.combatStats(base: { [string]: any }, level: number, config: Config): { [string]: any }
	local stats = table.clone(base)
	local lv = if isLevel(level, config) then level else 1
	for key, growth in config.StatGrowth do
		local value = base[key]
		if typeof(value) == "number" then
			stats[key] = math.floor(value * (1 + (lv - 1) * growth) + 0.5)
		end
	end
	return stats
end

-- XP d'une victoire sur ce stage, dans ce mode (nil / "Normal" : StageXP ; "Elite" : EliteStageXP) ;
-- 0 si le stage ou le mode n'en donne pas.
function HeroProgressionRules.stageXP(zone: number, stage: number, config: Config, mode: string?): number
	local source = if mode == "Elite" then config.EliteStageXP elseif mode == nil or mode == "Normal" then config.StageXP else nil
	local amount = if source then source[`{zone}-{stage}`] else nil
	return if typeof(amount) == "number" and amount > 0 then amount else 0
end

-- Problèmes de config ; vide si elle est utilisable.
function HeroProgressionRules.configProblems(config: any): { string }
	local problems: { string } = {}
	local function positiveInteger(value: any): boolean
		return typeof(value) == "number" and value >= 1 and value % 1 == 0
	end
	if not positiveInteger(config.MaxLevel) then
		table.insert(problems, "MaxLevel doit être un entier >= 1")
	end
	if not positiveInteger(config.FirstLevelXP) or typeof(config.PerLevelXP) ~= "number" or config.PerLevelXP < 0 then
		table.insert(problems, "FirstLevelXP >= 1 et PerLevelXP >= 0 requis")
	end
	for key, growth in config.StatGrowth or {} do
		if typeof(growth) ~= "number" or growth < 0 then
			table.insert(problems, `StatGrowth.{key} invalide`)
		end
	end
	for _, name in { "StageXP", "EliteStageXP" } do
		for key, amount in config[name] or {} do
			if typeof(amount) ~= "number" or amount < 0 or amount % 1 ~= 0 then
				table.insert(problems, `{name}[{key}] doit être un entier >= 0`)
			end
		end
	end
	return problems
end

return HeroProgressionRules
