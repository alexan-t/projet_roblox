--!strict
-- Contrat de map des plots (voir docs/PLOTS.md). Une seule convention, alignée sur la map de la DEV.

local PlotConfig = {
	-- Depuis Workspace : dossier (Folder) dont les modèles enfants directs sont les plots.
	PlotsFolder = table.freeze({ "Lobby", "Plots" }),
	-- Enfant direct de chaque plot : BasePart ancrée (pas une SpawnLocation) où le personnage est posé.
	SpawnName = "PointApparition",
}

return table.freeze(PlotConfig)
