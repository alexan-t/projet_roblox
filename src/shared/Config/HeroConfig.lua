--!strict
-- Héros jouables Alpha (voir docs/HEROES.md). Partagé : le client en lit les noms, la rareté, la taille
-- de la hotbar et le modèle de combat à montrer ; le serveur reste seul juge de ce que le joueur possède.
--
-- Clé = HeroId réel (le même que l'attribut HeroId des modèles de ServerStorage.Assets.Heros, repris
-- de l'attribut HerosId du Bestiaire) : c'est lui qui est sauvegardé dans PlayerData.Heroes.
-- HeroId réel ≠ profil de combat :
--   Rarity         = Id de RarityConfig (repris de l'attribut « Rarete » du Bestiaire) ;
--   CombatProfile  = clé des stats temporaires de CombatConfig.Heroes (serveur), la même pour toutes
--                    les raretés en Alpha ;
--   CombatTemplate = modèle de ReplicatedStorage.Assets.Combat (articulé ou mannequin). Absent : le
--                    combat montre le vrai modèle du héros (ReplicatedStorage.Assets.Heros, statique).
-- Ces champs de combat sont des détails Alpha provisoires ; seuls les héros listés ici sont jouables.

export type HeroInfo = {
	Name: string,
	Rarity: string,
	PlaceholderIcon: string,
	Order: number,
	CombatProfile: string,
	CombatTemplate: string?,
}

local Heroes: { [string]: HeroInfo } = {}
local order = 0

-- Monogramme PROVISOIRE (initiales des mots en majuscule), pas une solution finale ;
-- à remplacer par les icônes dessinées du design system (docs/UI_DESIGN_SYSTEM.md § 7).
local ACCENTED = { ["É"] = "E", ["À"] = "A", ["Â"] = "A", ["Î"] = "I", ["Ô"] = "O" }

local function monogram(name: string): string
	local letters = ""
	for word in name:gmatch("[^%s%-',]+") do
		local first = word:sub(1, (utf8.offset(word, 2) or 2) - 1)
		first = ACCENTED[first] or first
		if first:match("^%u$") and #letters < 2 then
			letters ..= first
		end
	end
	return if letters ~= "" then letters else name:sub(1, 2):upper()
end

local function hero(heroId: string, name: string, rarity: string, profile: string, template: string?)
	order += 1
	local info: HeroInfo = {
		Name = name,
		Rarity = rarity,
		PlaceholderIcon = monogram(name),
		Order = order,
		CombatProfile = profile,
		CombatTemplate = template,
	}
	Heroes[heroId] = info
	table.freeze(info)
end

-- Ordre du Bestiaire (socles 1 à 68). Profils : Epeiste, Tireur, Archer, Barbare, Paladin, Magicien.
-- Commun
-- Modèles articulés (copies de Workspace.AtelierAnimation, docs/ANIMATION_TOOLS.md § Attaques des
-- héros) : Heros_<Modèle> ; l'Écuyer a aussi son Ultime. Si le modèle manque dans la place, l'arène
-- montre le vrai modèle du héros (ArenaService).
hero("ecuyer_du_rempart", "Écuyer du Rempart", "Commun", "Epeiste", "Heros_EcuyerDuRempart")
hero("tireuse_des_faubourgs", "Tireuse des Faubourgs", "Commun", "Tireur", "Heros_TireuseDesFaubourgs")
-- Peu commun
hero("lancier_des_champs", "Lancier des Champs", "PeuCommun", "Epeiste", "Heros_LancierDesChamps")
hero("apprenti_pyromancien", "Apprenti Pyromancien", "PeuCommun", "Magicien", "Heros_ApprentiPyromancien")
hero("brise_pierre", "Brise-Pierre", "PeuCommun", "Barbare", "Heros_BrisePierre")
hero("guetteuse_des_pins", "Guetteuse des Pins", "PeuCommun", "Archer", "Heros_GuetteuseDesPins")
-- Rare
hero("chevalier_du_lierre", "Chevalier du Lierre", "Rare", "Paladin", "Heros_ChevalierDuLierre")
hero("mage_des_lanternes", "Mage des Lanternes", "Rare", "Magicien", "Heros_MageDesLanternes")
hero("fauconnier_gris", "Fauconnier Gris", "Rare", "Archer", "Heros_FauconnierGris")
hero("lanciere_des_sources", "Lancière des Sources", "Rare", "Epeiste", "Heros_LanciereDesSources")
hero("barde_de_fer", "Barde de Fer", "Rare", "Paladin", "Heros_BardeDeFer")
hero("moine_du_vent_bas", "Moine du Vent Bas", "Rare", "Epeiste", "Heros_MoineDuVentBas")
-- Épique
hero("gardien_des_ronces", "Gardien des Ronces", "Epique", "Paladin", "Heros_GardienDesRonces")
hero("cartomancienne_d_ambre", "Cartomancienne d'Ambre", "Epique", "Magicien", "Heros_CartomancienneDAmbre")
hero("duelliste_du_croissant", "Duelliste du Croissant", "Epique", "Epeiste", "Heros_DuellisteDuCroissant")
hero("forgeron_runique", "Forgeron Runique", "Epique", "Barbare", "Heros_ForgeronRunique")
hero("pretresse_aux_lucioles", "Prêtresse aux Lucioles", "Epique", "Magicien", "Heros_PretresseAuxLucioles")
hero("briseur_de_cloche", "Briseur de Cloche", "Epique", "Barbare", "Heros_BriseurDeCloche")
hero("veneur_de_givre", "Veneur de Givre", "Epique", "Archer", "Heros_VeneurDeGivre")
hero("alchimiste_aux_masques", "Alchimiste aux Masques", "Epique", "Magicien", "Heros_AlchimisteAuxMasques")
-- Légendaire
hero("chevalier_du_soleil_creux", "Chevalier du Soleil Creux", "Legendaire", "Paladin", "Heros_ChevalierDuSoleilCreux")
hero("dame_aux_mille_bannieres", "Dame aux Mille Bannières", "Legendaire", "Paladin", "Heros_DameAuxMilleBannieres")
hero("lancier_des_sept_orages", "Lancier des Sept Orages", "Legendaire", "Epeiste", "Heros_LancierDesSeptOrages")
hero("architecte_de_golems", "Architecte de Golems", "Legendaire", "Magicien", "Heros_ArchitecteDeGolems")
hero("veuve_du_lac_miroir", "Veuve du Lac Miroir", "Legendaire", "Magicien", "Heros_VeuveDuLacMiroir")
hero("chasseur_de_cometes", "Chasseur de Comètes", "Legendaire", "Archer", "Heros_ChasseurDeCometes")
hero("saint_du_brasier_bleu", "Saint du Brasier Bleu", "Legendaire", "Paladin", "Heros_SaintDuBrasierBleu")
hero("gardienne_de_la_derniere_cloche", "Gardienne de la Dernière Cloche", "Legendaire", "Paladin", "Heros_GardienneDeLaDerniereCloche")
hero("prince_des_racines_d_or", "Prince des Racines d'Or", "Legendaire", "Epeiste", "Heros_PrinceDesRacinesDOr")
hero("archiviste_du_temps_mort", "Archiviste du Temps Mort", "Legendaire", "Magicien", "Heros_ArchivisteDuTempsMort")
-- Mythique
hero("navigateur_des_cieux_renverses", "Navigateur des Cieux Renversés", "Mythique", "Tireur", "Heros_NavigateurDesCieuxRenverses")
hero("reine_des_cent_lames", "Reine des Cent Lames", "Mythique", "Epeiste", "Heros_ReineDesCentLames")
hero("berger_des_astres", "Berger des Astres", "Mythique", "Magicien", "Heros_BergerDesAstres")
hero("geant_au_coeur_de_verre", "Géant au Cœur de Verre", "Mythique", "Barbare", "Heros_GeantAuCoeurDeVerre")
hero("sorciere_des_marees_lunaires", "Sorcière des Marées Lunaires", "Mythique", "Magicien", "Heros_SorciereDesMareesLunaires")
hero("chevalier_de_l_eclipse_blanche", "Chevalier de l'Éclipse Blanche", "Mythique", "Paladin", "Heros_ChevalierDeLEclipseBlanche")
hero("maitre_des_portes_oubliees", "Maître des Portes Oubliées", "Mythique", "Magicien", "Heros_MaitreDesPortesOubliees")
hero("gardienne_du_dragon_dormant", "Gardienne du Dragon Dormant", "Mythique", "Paladin", "Heros_GardienneDuDragonDormant")
hero("tisseur_de_destins", "Tisseur de Destins", "Mythique", "Magicien", "Heros_TisseurDeDestins")
hero("empereur_des_cendres_d_or", "Empereur des Cendres d'Or", "Mythique", "Barbare", "Heros_EmpereurDesCendresDOr")
-- Maudit
hero("porteur_du_coeur_noir", "Porteur du Cœur Noir", "Maudit", "Barbare", "Heros_PorteurDuCoeurNoir")
hero("chevalier_aux_mille_clous", "Chevalier aux Mille Clous", "Maudit", "Paladin", "Heros_ChevalierAuxMilleClous")
hero("nonne_de_la_lune_fendue", "Nonne de la Lune Fendue", "Maudit", "Magicien", "Heros_NonneDeLaLuneFendue")
hero("roi_des_corbeaux_sans_ombre", "Roi des Corbeaux sans Ombre", "Maudit", "Archer", "Heros_RoiDesCorbeauxSansOmbre")
hero("marionnettiste_des_tombes", "Marionnettiste des Tombes", "Maudit", "Magicien", "Heros_MarionnettisteDesTombes")
hero("lame_du_serment_brise", "Lame du Serment Brisé", "Maudit", "Epeiste", "Heros_LameDuSermentBrise")
hero("sorcier_de_la_couronne_parasite", "Sorcier de la Couronne Parasite", "Maudit", "Magicien", "Heros_SorcierDeLaCouronneParasite")
hero("chasseur_de_noms", "Chasseur de Noms", "Maudit", "Tireur", "Heros_ChasseurDeNoms")
-- Suprême
hero("seraphin_des_sept_sceaux", "Séraphin des Sept Sceaux", "Supreme", "Paladin", "Heros_SeraphinDesSeptSceaux")
hero("reine_du_firmament_dore", "Reine du Firmament Doré", "Supreme", "Archer", "Heros_ReineDuFirmamentDore")
hero("chevalier_de_l_aube_infinie", "Chevalier de l'Aube Infinie", "Supreme", "Paladin", "Heros_ChevalierDeLAubeInfinie")
hero("oracle_aux_cent_yeux", "Oracle aux Cent Yeux", "Supreme", "Magicien", "Heros_OracleAuxCentYeux")
hero("forgeame", "Forgeâme", "Supreme", "Barbare", "Heros_Forgeame")
hero("gardien_du_trone_vide", "Gardien du Trône Vide", "Supreme", "Paladin", "Heros_GardienDuTroneVide")
-- Calamité
hero("marcheur_du_cataclysme", "Marcheur du Cataclysme", "Calamite", "Barbare", "Heros_MarcheurDuCataclysme")
hero("reine_de_la_mer_renversee", "Reine de la Mer Renversée", "Calamite", "Magicien", "Heros_ReineDeLaMerRenversee")
hero("soleil_devore", "Soleil Dévoré", "Calamite", "Magicien", "Heros_SoleilDevore")
hero("titanide_des_derniers_jours", "Titanide des Derniers Jours", "Calamite", "Barbare", "Heros_TitanideDesDerniersJours")
-- Transcendant
hero("aureon_porteur_de_la_premiere_aube", "Auréon, Porteur de la Première Aube", "Transcendant", "Paladin", "Heros_AureonPorteurDeLaPremiereAube")
hero("elyria_qui_marche_hors_du_temps", "Elyria, qui Marche hors du Temps", "Transcendant", "Magicien", "Heros_ElyriaQuiMarcheHorsDuTemps")

local HeroConfig = {
	-- Nombre de raccourcis de la hotbar (touches 1 à 9 puis 0).
	HotbarSize = 10,
	-- Héros activés (tous invocables). Un nouveau joueur n'en possède aucun : le premier héros est
	-- obtenu pendant l'invocation tutorielle (SummonConfig.Starter).
	Heroes = table.freeze(Heroes),
}

return table.freeze(HeroConfig)
