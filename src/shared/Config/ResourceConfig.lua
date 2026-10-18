--!strict
-- Catalogue des ressources 2D (voir docs/RESOURCES.md). Partagé : l'onglet Ressources de la
-- Sacoche, l'écran de récompenses et la vitrine Studio en lisent le nom, la famille et l'icône.
-- Aucun système de ressources en jeu pour l'instant (pas de stockage dans PlayerData, pas
-- d'obtention, pas de recette).
--
-- Source : automation/catalogues/resources.json (une tâche par ressource, avec l'idée de l'icône).
-- Identifiants par famille, en paliers contigus de 10. Les ressources n'ont **aucune rareté** :
-- cadre neutre Ink sur les cartes, comme les héros hors invocation.
--   Family = clé de Families (foret, slime, ...) ;
--   Index  = numéro NNN de l'emplacement Ressource_NNN de la vitrine ;
--   Icon   = rbxassetid de l'icône livrée (même valeur que Icone.Image et l'attribut AssetId de
--            la carte de la vitrine), nil tant qu'elle n'est pas produite.

export type ResourceInfo = {
	Id: string,
	Name: string,
	Family: string,
	Index: number,
	Icon: string?,
}

-- Familles, dans l'ordre de la vitrine (une rangée par famille).
local Families = {
	{ Id = "foret", Name = "Forêt et tréants" },
	{ Id = "slime", Name = "Slimes" },
	{ Id = "horde", Name = "Gobelins et orcs" },
	{ Id = "mine", Name = "Pierres et minerais" },
	{ Id = "arcane", Name = "Cristaux et magie" },
	{ Id = "royaume", Name = "Royaume et artisanat" },
}
local FamilyNames: { [string]: string } = {}
for _, family in Families do
	table.freeze(family)
	FamilyNames[family.Id] = family.Name
end

local Resources: { [string]: ResourceInfo } = {}
local Ordered: { ResourceInfo } = {}

local function resource(resourceId: string, name: string, family: string, icon: string?)
	local info: ResourceInfo = {
		Id = resourceId,
		Name = name,
		Family = family,
		Index = #Ordered + 1,
		Icon = icon,
	}
	Resources[resourceId] = info
	table.insert(Ordered, info)
	table.freeze(info)
end

-- Ordre de la vitrine (Ressource_001 à Ressource_060). Une icône livrée s'ajoute en quatrième
-- argument : resource("resource_036", "Pépite d'Or", "mine", "rbxassetid://...").
-- Forêt et tréants
resource("resource_001", "Bûche de Chêne", "foret", "rbxassetid://123355664297943")
resource("resource_002", "Écorce de Tréant", "foret", "rbxassetid://72789972478807")
resource("resource_003", "Branche Noueuse", "foret", "rbxassetid://132800021487287")
resource("resource_004", "Feuille de Tréant", "foret", "rbxassetid://117914456964972")
resource("resource_005", "Touffe de Mousse", "foret", "rbxassetid://98250548441668")
resource("resource_006", "Gland Massif", "foret", "rbxassetid://70674732956680")
resource("resource_007", "Racine Tordue", "foret", "rbxassetid://83797606175709")
resource("resource_008", "Sève Ambrée", "foret")
resource("resource_009", "Champignon des Sous-Bois", "foret", "rbxassetid://113718692737784")
resource("resource_010", "Bois du King Tréant", "foret", "rbxassetid://110650700122688")
-- Slimes
resource("resource_011", "Gelée d'Eau", "slime")
resource("resource_012", "Gelée de Lave", "slime")
resource("resource_013", "Gelée de Plante", "slime")
resource("resource_014", "Gelée de Champignon", "slime")
resource("resource_015", "Bulle de Slime", "slime")
resource("resource_016", "Fiole de Mucus", "slime")
resource("resource_017", "Perle de Gelée", "slime")
resource("resource_018", "Liane de Couronne", "slime")
resource("resource_019", "Cristal Flottant", "slime")
resource("resource_020", "Couronne Fondue", "slime")
-- Gobelins et orcs
resource("resource_021", "Lambeau de Tissu Rouge", "horde")
resource("resource_022", "Lanière de Cuir", "horde")
resource("resource_023", "Croc de Gobelin", "horde")
resource("resource_024", "Os Gravé", "horde")
resource("resource_025", "Plume de Guetteur", "horde")
resource("resource_026", "Rivets de Fer Usé", "horde")
resource("resource_027", "Fer de Lance Ébréché", "horde")
resource("resource_028", "Planche de Bouclier", "horde")
resource("resource_029", "Défense d'Orc", "horde")
resource("resource_030", "Corne du Roi Orc", "horde")
-- Pierres et minerais
resource("resource_031", "Galet de Rivière", "mine")
resource("resource_032", "Bloc de Pierre", "mine")
resource("resource_033", "Pierre Runique", "mine")
resource("resource_034", "Plaque d'Ardoise", "mine")
resource("resource_035", "Minerai de Fer", "mine")
resource("resource_036", "Pépite d'Or", "mine")
resource("resource_037", "Minerai de Cuivre", "mine")
resource("resource_038", "Morceau de Charbon", "mine")
resource("resource_039", "Sac de Sable Doré", "mine")
resource("resource_040", "Motte d'Argile", "mine")
-- Cristaux et magie
resource("resource_041", "Éclat de Cristal Cyan", "arcane")
resource("resource_042", "Grappe de Cristal Brut", "arcane")
resource("resource_043", "Poussière Runique", "arcane")
resource("resource_044", "Cœur de Tréant", "arcane")
resource("resource_045", "Braise Captive", "arcane")
resource("resource_046", "Rosée de Lune", "arcane")
resource("resource_047", "Essence Sylvestre", "arcane")
resource("resource_048", "Galet Spirale", "arcane")
resource("resource_049", "Encre Ancienne", "arcane")
resource("resource_050", "Orbe de Verre Trouble", "arcane")
-- Royaume et artisanat
resource("resource_051", "Pile de Planches", "royaume")
resource("resource_052", "Lingot de Fer", "royaume")
resource("resource_053", "Lingot d'Or", "royaume")
resource("resource_054", "Corde de Chanvre", "royaume")
resource("resource_055", "Rouleau de Toile", "royaume")
resource("resource_056", "Clous de Forge", "royaume")
resource("resource_057", "Tuiles d'Argile", "royaume")
resource("resource_058", "Parchemin Vierge", "royaume")
resource("resource_059", "Bannière Royale Pliée", "royaume")
resource("resource_060", "Pierre d'Angle du Royaume", "royaume")

local ResourceConfig = {
	-- Ressources par ResourceId (« resource_036 »).
	Resources = table.freeze(Resources),
	-- Ressources dans l'ordre de la vitrine (Index 1 à 60).
	Ordered = table.freeze(Ordered),
	Families = table.freeze(Families),
	-- Id de famille → libellé affiché (« mine » → « Pierres et minerais »).
	FamilyNames = table.freeze(FamilyNames),
}

-- Nom de la carte de la vitrine pour une ressource : « Ressource_036 ».
function ResourceConfig.slotName(index: number): string
	return string.format("Ressource_%03d", index)
end

return table.freeze(ResourceConfig)
