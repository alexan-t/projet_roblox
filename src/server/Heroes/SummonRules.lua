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
	First: boolean, -- premier résultat payé du profil ; pool garanti Épique ou mieux
	KingdomChanged: boolean, -- Kingdom.VisualState vient de passer de KingdomFrom à KingdomTo
	Guaranteed: boolean?,
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
function SummonRules.canPay(data: any, config: any, quantity: number?): boolean
	local tickets = data.Currencies.SummonTickets
	return typeof(tickets) == "number" and tickets >= config.Cost * (quantity or 1)
end

function SummonRules.guaranteePool(pool: Pool, minimumRank: number): Pool
	local tiers, total = {}, 0
	for rank, tier in pool.Tiers do
		local weight = if rank >= minimumRank then tier.Weight else 0
		table.insert(tiers, { Id = tier.Id, Weight = weight, Heroes = tier.Heroes })
		total += weight
	end
	return { Tiers = tiers, Total = total }
end

-- Probabilités EXACTES du même mélange que roll : le pool normal contient aussi les vedettes.
function SummonRules.rates(pool: Pool, banner: Banner): any
	local tiers, heroes = {}, {}
	for _, tier in pool.Tiers do
		local featured = 0
		for _, id in tier.Heroes do
			if table.find(banner.Featured, id) then featured += 1 end
		end
		local share = if featured > 0 then math.floor(banner.FeaturedShare * 100 + 0.5) / 100 else 0
		local chance = if pool.Total > 0 then tier.Weight / pool.Total else 0
		table.insert(tiers, { Id = tier.Id, Probability = chance })
		for _, id in tier.Heroes do
			heroes[id] = chance * ((1 - share) / #tier.Heroes + (if table.find(banner.Featured, id) then share / featured else 0))
		end
	end
	return { Tiers = tiers, Heroes = heroes }
end

-- Le compteur payé est aussi la version de transaction persistée : une requête rejouée est refusée,
-- même après un rejoin. Aucun champ de coût, héros ou taux n'est accepté du client.
function SummonRules.validateRequest(request: any, data: any, bannerId: string, slot: number): (boolean, string?)
	if typeof(request) ~= "table" then return false, "requête invalide" end
	for key in request do
		if key ~= "BannerId" and key ~= "Slot" and key ~= "Quantity" and key ~= "ExpectedTotal" then
			return false, "champ d'invocation interdit"
		end
	end
	if request.Quantity ~= 1 and request.Quantity ~= 10 and request.Quantity ~= 100 then return false, "quantité invalide" end
	if request.BannerId ~= bannerId or request.Slot ~= slot then return false, "bannière expirée, rouvre le portail" end
	local total = if typeof(data.Summons) == "table" then data.Summons.Total or 0 else 0
	if request.ExpectedTotal ~= total then return false, "invocation déjà traitée ou état périmé" end
	return true, nil
end

function SummonRules.batch(data: any, config: any, quantity: number, makeId: () -> string, pick: (number) -> number, pool: Pool, banner: Banner?): (any, string?)
	if quantity ~= 1 and quantity ~= 10 and quantity ~= 100 then return nil, "quantité invalide" end
	if not SummonRules.canPay(data, config, quantity) then return nil, "pas assez de tickets d'invocation" end
	local total = if typeof(data.Summons) == "table" then data.Summons.Total or 0 else 0
	local guaranteed = total == 0
	local firstPool = if guaranteed then SummonRules.guaranteePool(pool, config.GuaranteeRank or 4) else pool
	if firstPool.Total <= 0 then return nil, "aucun héros éligible à la garantie" end
	local results, ids, owned = {}, {}, {}
	for _, hero in data.Heroes do owned[hero.HeroId] = true end
	-- Prépare tout le lot avant la moindre mutation (y compris erreurs RNG/ID au 100e résultat).
	for index = 1, quantity do
		local heroId = SummonRules.roll(if index == 1 then firstPool else pool, banner, pick)
		local id = makeId()
		assert(typeof(id) == "string" and id ~= "" and not ids[id] and not data.Heroes[id], "identifiant d'exemplaire dupliqué")
		ids[id] = true
		table.insert(results, { InstanceId = id, HeroId = heroId, New = not owned[heroId], First = guaranteed and index == 1,
			Guaranteed = guaranteed and index == 1, KingdomChanged = false })
		owned[heroId] = true
	end
	for _, result in results do result.Slot = HeroRules.addHero(data, result.InstanceId, result.HeroId) end
	data.Currencies.SummonTickets -= config.Cost * quantity
	data.Summons = data.Summons or {}
	data.Summons.Total = total + quantity
	if guaranteed and data.Kingdom.VisualState == config.KingdomFrom then
		data.Kingdom.VisualState = config.KingdomTo
		results[1].KingdomChanged = true
	end
	return { Results = results, Quantity = quantity, Tickets = data.Currencies.SummonTickets, Total = total + quantity, Guaranteed = guaranteed }, nil
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

-- Adaptateur interne x1 ; le réseau passe par validateRequest + batch.
function SummonRules.summon(data: any, config: any, makeId: () -> string, pick: (number) -> number, pool: Pool, banner: Banner?): (Result?, string?)
	local batch, reason = SummonRules.batch(data, config, 1, makeId, pick, pool, banner)
	return if batch then batch.Results[1] else nil, reason
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
