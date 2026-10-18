--!strict
-- Invocation Alpha (voir docs/HEROES.md). Uniquement des données, lues par HeroService.
-- Starter gratuit séparé ; premier résultat payant Épique ou mieux, puis pool normal de la
-- bannière active. Volumes 1/10/100, sans remise ; la garantie dérive de Summons.Total == 0.

local SummonConfig = {
	-- Tickets consommés par invocation (Currencies.SummonTickets, donnés par RewardService).
	Cost = 1,
	GuaranteeRank = 4, -- ALPHA 0.0.2 : premier résultat payant Épique ou mieux
	-- Portail du plot du joueur (enfant direct du plot attribué par PlotService).
	PortalName = "PortailInvocation",
	-- Distance horizontale maximale (studs) entre le personnage (position serveur) et le pivot du
	-- portail de SON plot. Le portail fait environ 19 studs de large : ~9 studs autour de lui.
	MaxDistance = 18,
	-- La première invocation payante (Summons.Total == 0) fait passer le royaume de cet état à l'état
	-- suivant, une seule fois. Elle active aussi GuaranteeRank pour le premier résultat du lot.
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
