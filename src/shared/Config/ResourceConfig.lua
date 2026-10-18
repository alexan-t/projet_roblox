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
resource("resource_008", "Sève Ambrée", "foret", "rbxassetid://102032571866006")
resource("resource_009", "Champignon des Sous-Bois", "foret", "rbxassetid://113718692737784")
resource("resource_010", "Bois du King Tréant", "foret", "rbxassetid://110650700122688")
-- Slimes
resource("resource_011", "Gelée d'Eau", "slime", "rbxassetid://121201009519928")
resource("resource_012", "Gelée de Lave", "slime", "rbxassetid://70436671448847")
resource("resource_013", "Gelée de Plante", "slime", "rbxassetid://85798838676829")
resource("resource_014", "Gelée de Champignon", "slime", "rbxassetid://101734434670397")
resource("resource_015", "Bulle de Slime", "slime", "rbxassetid://133212401421915")
resource("resource_016", "Fiole de Mucus", "slime", "rbxassetid://101947191841474")
resource("resource_017", "Perle de Gelée", "slime", "rbxassetid://112115913740754")
resource("resource_018", "Liane de Couronne", "slime", "rbxassetid://80833359295616")
resource("resource_019", "Cristal Flottant", "slime", "rbxassetid://84378247299023")
resource("resource_020", "Couronne Fondue", "slime")
-- Gobelins et orcs
resource("resource_021", "Lambeau de Tissu Rouge", "horde", "rbxassetid://86238190807240")
resource("resource_022", "Lanière de Cuir", "horde", "rbxassetid://124467689473100")
resource("resource_023", "Croc de Gobelin", "horde", "rbxassetid://130044684290868")
resource("resource_024", "Os Gravé", "horde", "rbxassetid://82566021198094")
resource("resource_025", "Plume de Guetteur", "horde", "rbxassetid://80948233125363")
resource("resource_026", "Rivets de Fer Usé", "horde", "rbxassetid://81824142166302")
resource("resource_027", "Fer de Lance Ébréché", "horde", "rbxassetid://90611132056356")
resource("resource_028", "Planche de Bouclier", "horde", "rbxassetid://87552586783738")
resource("resource_029", "Défense d'Orc", "horde", "rbxassetid://102084442095235")
resource("resource_030", "Corne du Roi Orc", "horde")
-- Pierres et minerais
resource("resource_031", "Galet de Rivière", "mine", "rbxassetid://124890748158418")
resource("resource_032", "Bloc de Pierre", "mine", "rbxassetid://125262800064343")
resource("resource_033", "Pierre Runique", "mine", "rbxassetid://101845461360071")
resource("resource_034", "Plaque d'Ardoise", "mine", "rbxassetid://112375498120224")
resource("resource_035", "Minerai de Fer", "mine", "rbxassetid://105316081720709")
resource("resource_036", "Pépite d'Or", "mine", "rbxassetid://130078997029847")
resource("resource_037", "Minerai de Cuivre", "mine", "rbxassetid://126822675435008")
resource("resource_038", "Morceau de Charbon", "mine", "rbxassetid://71582478481177")
resource("resource_039", "Sac de Sable Doré", "mine", "rbxassetid://112315969053738")
resource("resource_040", "Motte d'Argile", "mine", "rbxassetid://129020679153861")
-- Cristaux et magie
resource("resource_041", "Éclat de Cristal Cyan", "arcane", "rbxassetid://86535229030136")
resource("resource_042", "Grappe de Cristal Brut", "arcane", "rbxassetid://88264082868996")
resource("resource_043", "Poussière Runique", "arcane", "rbxassetid://80977543784086")
resource("resource_044", "Cœur de Tréant", "arcane", "rbxassetid://102068554185533")
resource("resource_045", "Braise Captive", "arcane", "rbxassetid://93037340060778")
resource("resource_046", "Rosée de Lune", "arcane", "rbxassetid://127339387884826")
resource("resource_047", "Essence Sylvestre", "arcane", "rbxassetid://128441665886090")
resource("resource_048", "Galet Spirale", "arcane", "rbxassetid://83070458979354")
resource("resource_049", "Encre Ancienne", "arcane", "rbxassetid://116209265150473")
resource("resource_050", "Orbe de Verre Trouble", "arcane", "rbxassetid://95090509797705")
-- Royaume et artisanat
resource("resource_051", "Pile de Planches", "royaume", "rbxassetid://86412813311630")
resource("resource_052", "Lingot de Fer", "royaume", "rbxassetid://136456405227147")
resource("resource_053", "Lingot d'Or", "royaume", "rbxassetid://120285479420139")
resource("resource_054", "Corde de Chanvre", "royaume", "rbxassetid://95173415042102")
resource("resource_055", "Rouleau de Toile", "royaume", "rbxassetid://102051336742293")
resource("resource_056", "Clous de Forge", "royaume", "rbxassetid://134105028055466")
resource("resource_057", "Tuiles d'Argile", "royaume", "rbxassetid://76235642508162")
resource("resource_058", "Parchemin Vierge", "royaume", "rbxassetid://131342119415574")
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
