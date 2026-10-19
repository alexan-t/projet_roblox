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
resource("resource_001", "Bûche de Chêne", "foret", "rbxassetid://87010843611833")
resource("resource_002", "Écorce de Tréant", "foret", "rbxassetid://112052406706817")
resource("resource_003", "Branche Noueuse", "foret", "rbxassetid://122195546422211")
resource("resource_004", "Feuille de Tréant", "foret", "rbxassetid://95795472126203")
resource("resource_005", "Touffe de Mousse", "foret", "rbxassetid://74819516017807")
resource("resource_006", "Gland Massif", "foret", "rbxassetid://77415638297660")
resource("resource_007", "Racine Tordue", "foret", "rbxassetid://93170949786339")
resource("resource_008", "Sève Ambrée", "foret", "rbxassetid://95378236631901")
resource("resource_009", "Champignon des Sous-Bois", "foret", "rbxassetid://89807734880810")
resource("resource_010", "Bois du King Tréant", "foret", "rbxassetid://122155451070320")
-- Slimes
resource("resource_011", "Gelée d'Eau", "slime", "rbxassetid://115103256651411")
resource("resource_012", "Gelée de Lave", "slime", "rbxassetid://133490478149803")
resource("resource_013", "Gelée de Plante", "slime", "rbxassetid://112980096337198")
resource("resource_014", "Gelée de Champignon", "slime", "rbxassetid://119296688503979")
resource("resource_015", "Bulle de Slime", "slime", "rbxassetid://92416272330753")
resource("resource_016", "Fiole de Mucus", "slime", "rbxassetid://140678871203459")
resource("resource_017", "Perle de Gelée", "slime", "rbxassetid://135739258958462")
resource("resource_018", "Liane de Couronne", "slime", "rbxassetid://136916582393746")
resource("resource_019", "Cristal Flottant", "slime", "rbxassetid://85051142757176")
resource("resource_020", "Couronne Fondue", "slime", "rbxassetid://88237557299620")
-- Gobelins et orcs
resource("resource_021", "Lambeau de Tissu Rouge", "horde", "rbxassetid://82653946935805")
resource("resource_022", "Lanière de Cuir", "horde", "rbxassetid://127458461513892")
resource("resource_023", "Croc de Gobelin", "horde", "rbxassetid://75080985484973")
resource("resource_024", "Os Gravé", "horde", "rbxassetid://114890957181541")
resource("resource_025", "Plume de Guetteur", "horde", "rbxassetid://110168088178928")
resource("resource_026", "Rivets de Fer Usé", "horde", "rbxassetid://72073953253067")
resource("resource_027", "Fer de Lance Ébréché", "horde", "rbxassetid://93683458782006")
resource("resource_028", "Planche de Bouclier", "horde", "rbxassetid://70922438867901")
resource("resource_029", "Défense d'Orc", "horde", "rbxassetid://87222605861413")
resource("resource_030", "Corne du Roi Orc", "horde", "rbxassetid://100096165201129")
-- Pierres et minerais
resource("resource_031", "Galet de Rivière", "mine", "rbxassetid://111705179846657")
resource("resource_032", "Bloc de Pierre", "mine", "rbxassetid://103584904096420")
resource("resource_033", "Pierre Runique", "mine", "rbxassetid://135985670826077")
resource("resource_034", "Plaque d'Ardoise", "mine", "rbxassetid://89919539137406")
resource("resource_035", "Minerai de Fer", "mine", "rbxassetid://72539344614118")
resource("resource_036", "Pépite d'Or", "mine", "rbxassetid://101753968431472")
resource("resource_037", "Minerai de Cuivre", "mine", "rbxassetid://84553181426386")
resource("resource_038", "Morceau de Charbon", "mine", "rbxassetid://96000412157071")
resource("resource_039", "Sac de Sable Doré", "mine", "rbxassetid://138454215029424")
resource("resource_040", "Motte d'Argile", "mine", "rbxassetid://85393419670325")
-- Cristaux et magie
resource("resource_041", "Éclat de Cristal Cyan", "arcane", "rbxassetid://103429003013641")
resource("resource_042", "Grappe de Cristal Brut", "arcane", "rbxassetid://107313519985654")
resource("resource_043", "Poussière Runique", "arcane", "rbxassetid://94124735305768")
resource("resource_044", "Cœur de Tréant", "arcane", "rbxassetid://74405538225530")
resource("resource_045", "Braise Captive", "arcane", "rbxassetid://88900379042904")
resource("resource_046", "Rosée de Lune", "arcane", "rbxassetid://76829542217869")
resource("resource_047", "Essence Sylvestre", "arcane", "rbxassetid://134647433604547")
resource("resource_048", "Galet Spirale", "arcane", "rbxassetid://139309089294687")
resource("resource_049", "Encre Ancienne", "arcane", "rbxassetid://71967695959496")
resource("resource_050", "Orbe de Verre Trouble", "arcane", "rbxassetid://137035749181886")
-- Royaume et artisanat
resource("resource_051", "Pile de Planches", "royaume", "rbxassetid://91188667039018")
resource("resource_052", "Lingot de Fer", "royaume", "rbxassetid://85420176284469")
resource("resource_053", "Lingot d'Or", "royaume", "rbxassetid://94216403345680")
resource("resource_054", "Corde de Chanvre", "royaume", "rbxassetid://111498263999201")
resource("resource_055", "Rouleau de Toile", "royaume", "rbxassetid://91758026736936")
resource("resource_056", "Clous de Forge", "royaume", "rbxassetid://80803288375776")
resource("resource_057", "Tuiles d'Argile", "royaume", "rbxassetid://89652219128645")
resource("resource_058", "Parchemin Vierge", "royaume", "rbxassetid://104759036945725")
resource("resource_059", "Bannière Royale Pliée", "royaume", "rbxassetid://136762464090298")
resource("resource_060", "Pierre d'Angle du Royaume", "royaume", "rbxassetid://99772063132437")

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
