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
	First: boolean, -- première invocation payante du profil (Summons.Total était 0) ; ne décide pas du héros
	KingdomChanged: boolean, -- Kingdom.VisualState vient de passer de KingdomFrom à KingdomTo
}

-- Pool de tirage : un palier par rareté (ordre de RarityConfig), avec son poids effectif (les
-- paliers vides ont reporté le leur) et ses héros dans l'ordre du catalogue.
export type PoolTier = { Id: string, Weight: number, Heroes: { string } }
export type Pool = { Tiers: { PoolTier }, Total: number }
export type Banner = { Id: string, Featured: { string }, FeaturedShare: number }

-- Construit le pool : chaque héros du catalogue rejoint le palier de sa rareté ; la chance d'un palier
-- sans héros passe au palier inférieur le plus proche qui en a (au supérieur s'il n'y en a aucun).
function SummonRules.buildPool(tiers: { any }, catalog: { [string]: any }): Pool
	local result: { PoolTier } = {}
	local index: { [string]: PoolTier } = {}
	for _, tier in tiers do
		local entry: PoolTier = { Id = tier.Id, Weight = 0, Heroes = {} }
		table.insert(result, entry)
		index[tier.Id] = entry
	end
	local ids = {}
	for heroId in catalog do
		table.insert(ids, heroId)
	end
	table.sort(ids, function(a: string, b: string): boolean
		local oa, ob = catalog[a].Order or 0, catalog[b].Order or 0
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	for _, heroId in ids do
		local entry = index[catalog[heroId].Rarity]
		if entry then
			table.insert(entry.Heroes, heroId)
		end
	end
	local total = 0
	for i, tier in tiers do
		local target: PoolTier? = nil
		for j = i, 1, -1 do
			if #result[j].Heroes > 0 then
				target = result[j]
				break
			end
		end
		if not target then
			for j = i + 1, #result do
				if #result[j].Heroes > 0 then
					target = result[j]
					break
				end
			end
		end
		if target then
			target.Weight += tier.Weight
			total += tier.Weight
		end
	end
	return { Tiers = result, Total = total }
end

-- Problèmes de config (HeroId inconnus du catalogue, coût invalide, raretés, bannières) ; vide si elle
-- est utilisable.
function SummonRules.configProblems(config: any, catalog: { [string]: any }, tiers: { any }?, banners: { any }?): { string }
	local problems: { string } = {}
	if typeof(config.Cost) ~= "number" or config.Cost < 1 or config.Cost % 1 ~= 0 then
		table.insert(problems, "Cost doit être un entier >= 1")
	end
	local starter = config.Starter
	if typeof(starter) ~= "table" or not catalog[starter.HeroId] then
		table.insert(problems, `Starter.HeroId inconnu : {tostring(if typeof(starter) == "table" then starter.HeroId else nil)}`)
	elseif typeof(starter.QuestId) ~= "string" or typeof(starter.Event) ~= "string" then
		table.insert(problems, "Starter : QuestId et Event requis")
	end
	if tiers then
		local known: { [string]: boolean } = {}
		for _, tier in tiers do
			if typeof(tier.Weight) ~= "number" or tier.Weight < 0 or tier.Weight % 1 ~= 0 then
				table.insert(problems, `Rareté {tostring(tier.Id)} : Weight doit être un entier >= 0`)
			end
			known[tier.Id] = true
		end
		for heroId, info in catalog do
			if not known[info.Rarity] then
				table.insert(problems, `{heroId} : rareté inconnue {tostring(info.Rarity)}`)
			end
		end
		if SummonRules.buildPool(tiers, catalog).Total <= 0 then
			table.insert(problems, "aucun héros invocable")
		end
	end
	for _, banner in banners or {} do
		for _, heroId in banner.Featured do
			if not catalog[heroId] then
				table.insert(problems, `Bannière {banner.Id} : HeroId inconnu {heroId}`)
			end
		end
		if typeof(banner.FeaturedShare) ~= "number" or banner.FeaturedShare < 0 or banner.FeaturedShare > 1 then
			table.insert(problems, `Bannière {banner.Id} : FeaturedShare doit être entre 0 et 1`)
		end
	end
	return problems
end

-- Le joueur a-t-il de quoi payer une invocation ?
function SummonRules.canPay(data: any, config: any): boolean
	local tickets = data.Currencies.SummonTickets
	return typeof(tickets) == "number" and tickets >= config.Cost
end

-- Tirage : un palier selon les poids effectifs, puis un héros de ce palier (un héros mis en avant par
-- la bannière avec la probabilité FeaturedShare). `pick(n)` renvoie un entier dans [1, n].
function SummonRules.roll(pool: Pool, banner: Banner?, pick: (number) -> number): string
	local r = math.clamp(pick(pool.Total), 1, pool.Total)
	local chosen: PoolTier? = nil
	for _, tier in pool.Tiers do
		if tier.Weight > 0 then
			if r <= tier.Weight then
				chosen = tier
				break
			end
			r -= tier.Weight
		end
	end
	local tier = chosen :: PoolTier
	local heroes = tier.Heroes
	if banner and banner.FeaturedShare > 0 then
		local featured: { string } = {}
		for _, heroId in heroes do
			if table.find(banner.Featured, heroId) then
				table.insert(featured, heroId)
			end
		end
		if #featured > 0 and pick(100) <= math.floor(banner.FeaturedShare * 100 + 0.5) then
			heroes = featured
		end
	end
	return heroes[math.clamp(pick(#heroes), 1, #heroes)]
end

-- Transaction complète, synchrone : revérifie le ticket, tire le héros dans `pool` (bannière
-- facultative), prépare l'identifiant, crée l'exemplaire (hotbar si une case est libre), débite, compte
-- l'invocation et, à la première invocation payante, fait évoluer le royaume une seule fois. Aucun héros
-- garanti : la première invocation payante tire comme toutes les autres.
-- Renvoie le résultat, ou nil et la raison sans rien modifier.
function SummonRules.summon(data: any, config: any, makeId: () -> string, pick: (number) -> number, pool: Pool, banner: Banner?): (Result?, string?)
	if not SummonRules.canPay(data, config) then
		return nil, "pas de ticket d'invocation"
	end
	local summons = data.Summons
	local total = if typeof(summons) == "table" and typeof(summons.Total) == "number" then summons.Total else 0
	local firstPaid = total == 0
	local heroId = SummonRules.roll(pool, banner, pick)
	local new = not HeroRules.owns(data, heroId)
	-- Tout ce qui peut échouer (identifiant, tirage) est prêt AVANT la première mutation : une
	-- erreur ici laisse le ticket intact. Ensuite le héros est ajouté puis le ticket débité.
	local instanceId = makeId()

	local slot = HeroRules.addHero(data, instanceId, heroId)
	data.Currencies.SummonTickets -= config.Cost
	data.Summons = { Total = total + 1 }
	local kingdomChanged = false
	if firstPaid and data.Kingdom.VisualState == config.KingdomFrom then
		data.Kingdom.VisualState = config.KingdomTo
		kingdomChanged = true
	end
	return {
		InstanceId = instanceId,
		HeroId = heroId,
		New = new,
		Slot = slot,
		First = firstPaid,
		KingdomChanged = kingdomChanged,
	}, nil
end

-- Invocation tutorielle encore possible ? Jamais si le profil possède déjà le héros de départ.
-- (La quête du tutoriel est vérifiée par HeroService avec QuestService.)
function SummonRules.canStarter(data: any, starter: any): (boolean, string?)
	if HeroRules.owns(data, starter.HeroId) then
		return false, "premier héros déjà obtenu"
	end
	return true, nil
end

-- Invocation tutorielle, synchrone : le héros de départ, gratuit et garanti. Aucun ticket débité,
-- Summons.Total inchangé (compteur des invocations payantes), royaume inchangé.
-- Renvoie le résultat, ou nil et la raison sans rien modifier.
function SummonRules.starter(data: any, starter: any, makeId: () -> string): (Result?, string?)
	local ok, why = SummonRules.canStarter(data, starter)
	if not ok then
		return nil, why
	end
	local instanceId = makeId() -- prêt AVANT la première mutation
	local slot = HeroRules.addHero(data, instanceId, starter.HeroId)
	return {
		InstanceId = instanceId,
		HeroId = starter.HeroId,
		New = true,
		Slot = slot,
		First = false,
		KingdomChanged = false,
	}, nil
end

return SummonRules
