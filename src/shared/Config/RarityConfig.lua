--!strict
-- Raretés des héros (voir docs/HEROES.md § Raretés). Les monstres n'en ont aucune.
-- Partagé : le serveur tire avec ces poids, le client les affiche (taux du HUD d'invocation).
--   Id     : identifiant stable (HeroConfig, PlayerData, couleurs UITheme.Rarity).
--   Name   : libellé affiché, identique à l'attribut « Rarete » des modèles du Bestiaire.
--   Weight : chance de tirage en pour dix mille (somme = 10 000). Un palier sans héros invocable
--            reporte sa chance sur le palier inférieur le plus proche qui en a.

export type Tier = { Id: string, Name: string, Weight: number }

local Tiers: { Tier } = {
	{ Id = "Commun", Name = "Commun", Weight = 5000 },
	{ Id = "PeuCommun", Name = "Peu commun", Weight = 2500 },
	{ Id = "Rare", Name = "Rare", Weight = 1300 },
	{ Id = "Epique", Name = "Épique", Weight = 700 },
	{ Id = "Legendaire", Name = "Légendaire", Weight = 350 },
	{ Id = "Mythique", Name = "Mythique", Weight = 100 },
	{ Id = "Maudit", Name = "Maudit", Weight = 30 },
	{ Id = "Supreme", Name = "Suprême", Weight = 12 },
	{ Id = "Calamite", Name = "Calamité", Weight = 6 },
	{ Id = "Transcendant", Name = "Transcendant", Weight = 2 },
}

local Rank: { [string]: number } = {}
local ByName: { [string]: string } = {}
for index, tier in Tiers do
	table.freeze(tier)
	Rank[tier.Id] = index
	ByName[tier.Name] = tier.Id
end

local RarityConfig = {
	Tiers = table.freeze(Tiers),
	-- Rang 1 (Commun) à 10 (Transcendant) : l'effet d'invocation grandit avec lui.
	Rank = table.freeze(Rank),
	-- Libellé du Bestiaire (« Peu commun ») → Id (« PeuCommun »).
	ByName = table.freeze(ByName),
	-- Diviseur des poids (pour dix mille).
	Total = 10000,
}

-- Palier d'un Id, ou nil.
function RarityConfig.tier(id: string?): Tier?
	local rank = if id then Rank[id] else nil
	return if rank then Tiers[rank] else nil
end

-- Taux affiché : « 50 % », « 0,02 % ».
function RarityConfig.percent(weight: number): string
	local value = weight * 100 / 10000
	local text = if value >= 1 then string.format("%g", value) else string.format("%.2f", value):gsub("0+$", "")
	return (text:gsub("%.", ",")) .. " %"
end

return table.freeze(RarityConfig)
