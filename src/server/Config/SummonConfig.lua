--!strict
-- Invocation Alpha (voir docs/HEROES.md). Uniquement des données, lues par HeroService.
-- Premier tirage garanti, puis tirage pondéré par rareté (RarityConfig) parmi tous les héros activés
-- (HeroConfig), avec la mise en avant de la bannière choisie (SummonBannerConfig).

local SummonConfig = {
	-- Tickets consommés par invocation (Currencies.SummonTickets, donnés par RewardService).
	Cost = 1,
	-- Portail du plot du joueur (enfant direct du plot attribué par PlotService).
	PortalName = "PortailInvocation",
	-- Distance horizontale maximale (studs) entre le personnage (position serveur) et le pivot du
	-- portail de SON plot. Le portail fait environ 19 studs de large : ~9 studs autour de lui.
	MaxDistance = 18,
	-- Toute première invocation du profil (Summons.Total == 0) : ce héros, toujours.
	FirstSummon = "tireuse_des_faubourgs",
	-- La première invocation fait passer le royaume de cet état à l'état suivant, une seule fois.
	KingdomFrom = 1,
	KingdomTo = 2,
}

return table.freeze(SummonConfig)
