--!strict
-- Héros jouables Alpha (voir docs/HEROES.md). Partagé : le client en lit les noms, la taille de la
-- hotbar et le modèle de combat à montrer ; le serveur reste seul juge de ce que le joueur possède.
--
-- Clé = HeroId réel (le même que l'attribut HeroId des modèles de ServerStorage.Assets.Heros) :
-- c'est lui qui est sauvegardé dans PlayerData.Heroes. HeroId réel ≠ profil de combat :
--   CombatProfile  = clé des stats temporaires de CombatConfig.Heroes (serveur) ;
--   CombatTemplate = mannequin temporaire de ReplicatedStorage.Assets.Combat (placement, combat,
--                    héros dans les mains).
-- Ces deux champs sont des détails Alpha provisoires ; seuls les héros listés ici sont jouables.

export type HeroInfo = {
	Name: string,
	PlaceholderIcon: string,
	Order: number,
	CombatProfile: string,
	CombatTemplate: string,
}

local HeroConfig = {
	-- Nombre de raccourcis de la hotbar (touches 1 à 9 puis 0).
	HotbarSize = 10,
	-- Héros activés. PlaceholderIcon : monogramme PROVISOIRE, pas une solution finale ;
	-- à remplacer par les icônes dessinées du design system (docs/UI_DESIGN_SYSTEM.md § 7).
	Heroes = table.freeze({
		ecuyer_du_rempart = table.freeze({
			Name = "Écuyer du Rempart",
			PlaceholderIcon = "EC",
			Order = 1,
			CombatProfile = "Epeiste",
			-- Modèle articulé (copie de Workspace.AtelierAnimation) : Marche, Attaque, Ultime animées.
			CombatTemplate = "Heros_EcuyerDuRempart",
		}),
		tireuse_des_faubourgs = table.freeze({
			Name = "Tireuse des Faubourgs",
			PlaceholderIcon = "TF",
			Order = 2,
			CombatProfile = "Tireur",
			CombatTemplate = "Heros_Tireur",
		}),
	}) :: { [string]: HeroInfo },
	-- Héros de départ : chaque HeroId listé est garanti au moins une fois (un nouveau joueur en reçoit
	-- exactement un exemplaire chacun).
	StarterHeroes = table.freeze({ "ecuyer_du_rempart" }),
}

return table.freeze(HeroConfig)
