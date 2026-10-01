--!strict
-- Héros Alpha (voir docs/HEROES.md). Partagé : le client en lit les noms et la taille de la hotbar ;
-- le serveur reste seul juge de ce que le joueur possède.
-- HeroId = classe de combat (clés de CombatConfig.Heroes côté serveur).

export type HeroInfo = { Name: string, Icon: string, Order: number }

local HeroConfig = {
	-- Nombre de raccourcis de la hotbar (touches 1 à 9 puis 0).
	HotbarSize = 10,
	-- Affichage des héros connus. Icon : pictogramme provisoire, à remplacer par les icônes
	-- dessinées du design system (docs/UI_DESIGN_SYSTEM.md § 7).
	Heroes = table.freeze({
		Archer = table.freeze({ Name = "Archer", Icon = "🏹", Order = 1 }),
		Epeiste = table.freeze({ Name = "Épéiste", Icon = "⚔️", Order = 2 }),
		Barbare = table.freeze({ Name = "Barbare", Icon = "🪓", Order = 3 }),
		Paladin = table.freeze({ Name = "Paladin", Icon = "🛡️", Order = 4 }),
		Magicien = table.freeze({ Name = "Magicien", Icon = "🧙", Order = 5 }),
		Tireur = table.freeze({ Name = "Tireur", Icon = "🎯", Order = 6 }),
	}) :: { [string]: HeroInfo },
	-- Kit de départ : donné une fois à un joueur qui ne possède encore aucun héros.
	StarterHeroes = table.freeze({ "Archer", "Epeiste", "Barbare", "Paladin", "Magicien", "Tireur" }),
}

return table.freeze(HeroConfig)
