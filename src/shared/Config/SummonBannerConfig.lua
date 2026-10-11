--!strict
-- Bannières d'invocation (voir docs/HEROES.md § Bannières). Partagé : le client les affiche au portail,
-- le serveur valide l'Id reçu et applique la mise en avant.
-- Toutes les bannières tirent dans le même pool (tous les héros de HeroConfig) avec les mêmes chances
-- par rareté (RarityConfig). Mise en avant : quand la rareté tirée contient des héros Featured de la
-- bannière, l'un d'eux sort avec la probabilité FeaturedShare (sinon un héros quelconque de ce palier).

export type Banner = {
	Id: string,
	Name: string,
	Subtitle: string,
	Featured: { string }, -- HeroId mis en avant (affichés en grand, du plus rare au moins rare)
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
})
