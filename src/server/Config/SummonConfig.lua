--!strict
-- Invocation Alpha (voir docs/HEROES.md). Uniquement des données, lues par HeroService.
-- Premier héros : l'invocation tutorielle (Starter, gratuite). Toute invocation payante, première
-- comprise, est un tirage pondéré par rareté (RarityConfig) parmi tous les héros activés (HeroConfig),
-- avec la mise en avant de la bannière choisie (SummonBannerConfig). Aucun héros garanti.

local SummonConfig = {
	-- Tickets consommés par invocation (Currencies.SummonTickets, donnés par RewardService).
	Cost = 1,
	-- Portail du plot du joueur (enfant direct du plot attribué par PlotService).
	PortalName = "PortailInvocation",
	-- Distance horizontale maximale (studs) entre le personnage (position serveur) et le pivot du
	-- portail de SON plot. Le portail fait environ 19 studs de large : ~9 studs autour de lui.
	MaxDistance = 18,
	-- La première invocation payante (Summons.Total == 0) fait passer le royaume de cet état à l'état
	-- suivant, une seule fois. Elle ne décide jamais du héros.
	KingdomFrom = 1,
	KingdomTo = 2,
	-- Invocation tutorielle (onboarding) : le premier héros d'un nouveau profil. Gratuite, garantie,
	-- une seule fois, seulement pendant la quête QuestId : ni ticket, ni Summons.Total (compteur des
	-- invocations payantes), ni évolution du royaume. Signale Event à QuestService.
	Starter = table.freeze({
		HeroId = "ecuyer_du_rempart",
		QuestId = "SummonStarter",
		Event = "StarterHeroSummoned",
	}),
}

return table.freeze(SummonConfig)
