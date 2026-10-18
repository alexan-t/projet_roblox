--!strict
-- Bannières d'invocation (voir docs/HEROES.md § Bannières). Partagé : le client les affiche au portail,
-- le serveur valide l'Id reçu et applique la mise en avant.
-- Toutes les bannières tirent dans le même pool (tous les héros de HeroConfig) avec les mêmes chances
-- par rareté (RarityConfig). Mise en avant : quand la rareté tirée contient des héros Featured de la
-- bannière, la branche FeaturedShare choisit leur sous-pool ; l'autre branche choisit le palier
-- complet, qui inclut aussi ces vedettes. Les probabilités totales sont publiées par le serveur.

export type Banner = {
	Id: string,
	Name: string,
	Subtitle: string,
	Featured: { string }, -- vedette principale, puis les deux secondaires ; ordre visuel contractuel
	FeaturedShare: number, -- 0..1
}

local Banners: { Banner } = {
	{
		Id = "royaume",
		Name = "Appel du Royaume",
		Subtitle = "Les héros du royaume répondent à ton appel",
		Featured = { "dame_aux_mille_bannieres", "chevalier_du_soleil_creux", "pretresse_aux_lucioles" },
		FeaturedShare = 0.5,
	},
	{
		Id = "aube",
		Name = "Première Aube",
		Subtitle = "Une lumière plus ancienne que le royaume",
		Featured = { "aureon_porteur_de_la_premiere_aube", "seraphin_des_sept_sceaux", "chevalier_de_l_eclipse_blanche" },
		FeaturedShare = 0.5,
	},
	{
		Id = "eclipse",
		Name = "Serment Brisé",
		Subtitle = "Certains pouvoirs ont un prix",
		Featured = { "soleil_devore", "lame_du_serment_brise", "roi_des_corbeaux_sans_ombre" },
		FeaturedShare = 0.5,
	},
}

local ROTATION_SECONDS, EPOCH = 15 * 60, 0

local ById: { [string]: Banner } = {}
for _, banner in Banners do
	ById[banner.Id] = banner
	table.freeze(banner.Featured)
	table.freeze(banner)
end

return table.freeze({
	Banners = table.freeze(Banners),
	ById = table.freeze(ById),
	-- Bannière utilisée quand le client n'en précise aucune.
	Default = "royaume",
	RotationSeconds = ROTATION_SECONDS,
	Epoch = EPOCH, -- UTC Unix : même créneau sur chaque serveur et après reconnexion
	active = function(now: number): (Banner, number, number)
		local slot = math.floor((now - EPOCH) / ROTATION_SECONDS)
		return Banners[slot % #Banners + 1], slot, EPOCH + (slot + 1) * ROTATION_SECONDS
	end,
})
