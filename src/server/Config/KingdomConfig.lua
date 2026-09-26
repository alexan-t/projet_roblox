--!strict
-- Contrat d'assets du royaume (voir docs/KINGDOM.md).
-- Uniquement des emplacements d'assets préparés dans Studio : aucun réglage artistique.
-- Changer un modèle ou ajouter un VisualState se fait dans Studio, sans toucher au code.

local KingdomConfig = {
	-- Depuis ServerStorage : un Model par état, avec l'attribut numérique VisualState.
	StatesFolder = table.freeze({ "Assets", "RoyaumeEtats" }),
	-- Depuis ServerStorage : un Model par héros, avec l'attribut texte HeroId.
	HeroesFolder = table.freeze({ "Assets", "Heros" }),
	-- Depuis le modèle du plot : BasePart sur laquelle le pivot du royaume est posé.
	PlotAnchor = table.freeze({ "Royaume", "EmplacementCentral" }),
	-- Depuis le modèle d'état cloné : dossier des BasePart où poser les héros (Heros_1, Heros_2...).
	HeroMarkers = table.freeze({ "Emplacements", "Heros" }),
}

return table.freeze(KingdomConfig)
