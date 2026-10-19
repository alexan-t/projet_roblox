--!strict
-- Catalogue des items 2D (voir docs/ITEMS.md). Partagé : la Sacoche, l'écran de récompenses et la
-- vitrine Studio en lisent le nom, la rareté, l'emplacement et l'icône. Aucun système d'items en jeu
-- pour l'instant (pas de stockage dans PlayerData, pas d'obtention, pas de statistiques).
--
-- Provenance : relevé sur la vitrine Workspace.Bestiaire.Inventaire du snapshot historique
-- studio/sandbox/partner_sandbox_v4.rbxl (attributs ItemId, Index, Rarete, SlotType et texte Nom des
-- cartes Item_NNN) ; aucun fichier de catalogue de production dans le dépôt. Référence des assets :
-- la vitrine de la DEV Studio actuelle (tools/studio-items-vitrine.luau). Identifiants par rareté
-- croissante, en paliers contigus. La rareté est celle du catalogue : ne pas l'inventer ni la
-- modifier, et pas de couleur de rareté sur les cartes (cadre neutre Ink, comme les héros).
--   Rarity   = Id de RarityConfig (repris de l'attribut « Rarete » de la vitrine) ;
--   SlotType = clé de SlotTypes (weapon, armor, ...) ;
--   Index    = numéro NNN de l'emplacement Item_NNN de la vitrine ;
--   Icon     = rbxassetid de l'icône livrée (même valeur que Icone.Image et l'attribut AssetId de
--              la carte de la vitrine), nil tant qu'elle n'est pas produite.

export type ItemInfo = {
	Id: string,
	Name: string,
	Rarity: string,
	SlotType: string,
	Index: number,
	Icon: string?,
}

-- Types d'emplacement d'équipement, dans l'ordre d'affichage.
local SlotTypes = {
	{ Id = "weapon", Name = "Arme" },
	{ Id = "helmet", Name = "Casque" },
	{ Id = "armor", Name = "Armure" },
	{ Id = "gloves", Name = "Gants" },
	{ Id = "boots", Name = "Bottes" },
	{ Id = "accessory", Name = "Accessoire" },
	{ Id = "relic", Name = "Relique" },
}
local SlotTypeNames: { [string]: string } = {}
for _, slotType in SlotTypes do
	table.freeze(slotType)
	SlotTypeNames[slotType.Id] = slotType.Name
end

local Items: { [string]: ItemInfo } = {}
local Ordered: { ItemInfo } = {}

local function item(itemId: string, name: string, rarity: string, slotType: string, icon: string?)
	local info: ItemInfo = {
		Id = itemId,
		Name = name,
		Rarity = rarity,
		SlotType = slotType,
		Index = #Ordered + 1,
		Icon = icon,
	}
	Items[itemId] = info
	table.insert(Ordered, info)
	table.freeze(info)
end

-- Ordre de la vitrine (Item_001 à Item_100, une rangée par rareté). Une icône livrée s'ajoute en
-- cinquième argument : item("item_037", "Épée du Soleil Creux", "Legendaire", "weapon", "rbxassetid://...").
-- Commun
item("item_001", "Épée du Rempart", "Commun", "weapon", "rbxassetid://74261555399252")
item("item_002", "Arc de Chêne Tendu", "Commun", "weapon", "rbxassetid://82180554646757")
item("item_003", "Bâton de Braise", "Commun", "weapon", "rbxassetid://79107407537979")
item("item_004", "Heaume du Veilleur", "Commun", "helmet", "rbxassetid://136038153971170")
-- Peu commun
item("item_005", "Lance du Guetteur", "PeuCommun", "weapon", "rbxassetid://128980202601406")
item("item_006", "Masse de Garnison", "PeuCommun", "weapon", "rbxassetid://115046206863732")
item("item_007", "Capuche du Chasseur Gris", "PeuCommun", "helmet", "rbxassetid://80123567663424")
item("item_008", "Cuirasse du Domaine", "PeuCommun", "armor", "rbxassetid://76047754509002")
item("item_009", "Bottes des Sentiers", "PeuCommun", "boots", "rbxassetid://94443403758795")
item("item_010", "Anneau de Pierre Claire", "PeuCommun", "accessory", "rbxassetid://87527646543342")
-- Rare
item("item_011", "Broche de Bannière", "Rare", "accessory", "rbxassetid://123997867056733")
item("item_012", "Pendentif du Campement", "Rare", "accessory", "rbxassetid://71489721349530")
item("item_013", "Fiole de Rosée", "Rare", "relic", "rbxassetid://132942245457507")
item("item_014", "Fragment de Cristal Royal", "Rare", "relic", "rbxassetid://105290204427623")
item("item_015", "Lame des Ronces", "Rare", "weapon", "rbxassetid://99022583774278")
item("item_016", "Marteau Brise Cloche", "Rare", "weapon", "rbxassetid://72430269800496")
item("item_017", "Arbalète des Pins Noirs", "Rare", "weapon", "rbxassetid://122508514386407")
item("item_018", "Faucille du Croissant", "Rare", "weapon", "rbxassetid://125132118428362")
item("item_019", "Bâton des Lucioles", "Rare", "weapon", "rbxassetid://106597637705743")
item("item_020", "Dagues du Miroir Fendu", "Rare", "weapon", "rbxassetid://118691704528728")
-- Épique
item("item_021", "Couronne de Lierre Doré", "Epique", "helmet", "rbxassetid://78588919716039")
item("item_022", "Masque du Veilleur de Givre", "Epique", "helmet", "rbxassetid://93977887034722")
item("item_023", "Casque du Fauconnier", "Epique", "helmet", "rbxassetid://82830277172993")
item("item_024", "Armure des Racines Vivantes", "Epique", "armor", "rbxassetid://81509405320170")
item("item_025", "Manteau des Cendres Bleues", "Epique", "armor", "rbxassetid://102816581117859")
item("item_026", "Robe de la Marée Fine", "Epique", "armor", "rbxassetid://115436960943991")
item("item_027", "Cuirasse du Clocher Sacré", "Epique", "armor", "rbxassetid://81915950723349")
item("item_028", "Bottes du Vent Bas", "Epique", "boots", "rbxassetid://122797849761853")
item("item_029", "Gantelets Runiques", "Epique", "gloves", "rbxassetid://95703853511452")
item("item_030", "Sablier du Pas Calme", "Epique", "accessory", "rbxassetid://77441420170568")
item("item_031", "Lanterne du Mage Errant", "Epique", "accessory", "rbxassetid://121527299870650")
item("item_032", "Plume du Faucon Ancien", "Epique", "accessory", "rbxassetid://95614719957042")
item("item_033", "Médaillon de Source Vive", "Epique", "accessory", "rbxassetid://133786107385012")
item("item_034", "Cœur de Tréant Poli", "Epique", "relic", "rbxassetid://80465518616765")
-- Légendaire
item("item_035", "Œil de Slime Royal", "Legendaire", "relic", "rbxassetid://86052151054209")
item("item_036", "Clochette du Premier Sanctuaire", "Legendaire", "relic", "rbxassetid://77519861135510")
item("item_037", "Épée du Soleil Creux", "Legendaire", "weapon", "rbxassetid://127976128496025")
item("item_038", "Lance des Sept Orages", "Legendaire", "weapon", "rbxassetid://98478425256153")
item("item_039", "Marteau Forgeâme", "Legendaire", "weapon", "rbxassetid://136264830584681")
item("item_040", "Arc Chasseur de Comètes", "Legendaire", "weapon", "rbxassetid://125422572815441")
item("item_041", "Lame du Serment Brisé", "Legendaire", "weapon", "rbxassetid://140558555668192")
item("item_042", "Cisaille des Portes Oubliées", "Legendaire", "weapon", "rbxassetid://98953335860146")
item("item_043", "Sceptre des Marées Lunaires", "Legendaire", "weapon", "rbxassetid://81643413088132")
item("item_044", "Hallebarde de l’Éclipse Blanche", "Legendaire", "weapon", "rbxassetid://85274593265515")
item("item_045", "Couronne Parasite", "Legendaire", "helmet", "rbxassetid://121410270279393")
item("item_046", "Heaume des Mille Clous", "Legendaire", "helmet", "rbxassetid://131538808675893")
item("item_047", "Voile de la Lune Fendue", "Legendaire", "helmet", "rbxassetid://84701328377988")
item("item_048", "Diadème du Firmament Doré", "Legendaire", "helmet", "rbxassetid://121906599533826")
item("item_049", "Masque aux Cent Yeux", "Legendaire", "helmet", "rbxassetid://96821302634572")
item("item_050", "Armure du Cœur Noir", "Legendaire", "armor", "rbxassetid://135670481346624")
item("item_051", "Manteau des Corbeaux Sans Ombre", "Legendaire", "armor", "rbxassetid://70932982901063")
item("item_052", "Cuirasse de l’Aube Infinie", "Legendaire", "armor", "rbxassetid://127884051120292")
-- Mythique
item("item_053", "Robe des Destins Tissés", "Mythique", "armor", "rbxassetid://100103223594911")
item("item_054", "Plastron du Trône Vide", "Mythique", "armor", "rbxassetid://77511314316741")
item("item_055", "Armure du Cataclysme Fissuré", "Mythique", "armor", "rbxassetid://128659206667345")
item("item_056", "Bottes du Temps Décalé", "Mythique", "boots", "rbxassetid://86733717930047")
item("item_057", "Gantelets de la Mer Renversée", "Mythique", "gloves", "rbxassetid://109959439192036")
item("item_058", "Bottes Astrales du Berger", "Mythique", "boots", "rbxassetid://96144946699289")
item("item_059", "Anneau de l’Œil Orbital", "Mythique", "accessory", "rbxassetid://134734605396415")
item("item_060", "Broche du Dragon Dormant", "Mythique", "accessory", "rbxassetid://117186036920351")
item("item_061", "Pendentif de Constellation Liée", "Mythique", "accessory", "rbxassetid://131086329706958")
item("item_062", "Sceau des Sept Verrous", "Mythique", "accessory", "rbxassetid://73401510071065")
item("item_063", "Médaillon du Temps Mort", "Mythique", "accessory", "rbxassetid://121420905620168")
item("item_064", "Nœud de Destin", "Mythique", "accessory", "rbxassetid://71639489124243")
item("item_065", "Épingle du Roi Racine", "Mythique", "accessory", "rbxassetid://135899554508755")
item("item_066", "Bocal de Tempête", "Mythique", "relic", "rbxassetid://74732760516098")
item("item_067", "Cœur de Golem Cloche", "Mythique", "relic", "rbxassetid://104911680957145")
item("item_068", "Larme du Léviathan", "Mythique", "relic", "rbxassetid://103191740579517")
item("item_069", "Éclat d’Île Céleste", "Mythique", "relic", "rbxassetid://102890007873644")
item("item_070", "Fragment de Lune Mordante", "Mythique", "relic", "rbxassetid://93226161807258")
-- Maudit
item("item_071", "Dent du Dragon des Étoiles", "Maudit", "relic", "rbxassetid://83942242561198")
item("item_072", "Sablier des Âges Brisés", "Maudit", "relic", "rbxassetid://75119798769179")
item("item_073", "Soleil Dévoré en Cage", "Maudit", "relic", "rbxassetid://118873243066318")
item("item_074", "Couronne de l’Aube Première", "Maudit", "helmet", "rbxassetid://130828450420713")
item("item_075", "Grimoire des Noms Effacés", "Maudit", "relic", "rbxassetid://87638575675851")
item("item_076", "Luth des Funérailles Joyeuses", "Maudit", "weapon", "rbxassetid://116530077613248")
item("item_077", "Lanternon du Veilleur Sans Visage", "Maudit", "accessory", "rbxassetid://110756945574000")
item("item_078", "Grèves des Pas Sans Ombre", "Maudit", "boots", "rbxassetid://79952482621259")
item("item_079", "Collier du Cœur Enfermé", "Maudit", "accessory", "rbxassetid://87006856267271")
item("item_080", "Écharpe des Corbeaux Murmurants", "Maudit", "armor", "rbxassetid://86506645750721")
item("item_081", "Flûte du Sable Vivant", "Maudit", "weapon", "rbxassetid://127424828395779")
item("item_082", "Miroir de la Treizième Aube", "Maudit", "relic", "rbxassetid://140310966070359")
-- Suprême
item("item_083", "Trône Miniature de l’Empereur Cendre", "Supreme", "relic", "rbxassetid://74008291985155")
item("item_084", "Tiare des Marées Inversées", "Supreme", "helmet", "rbxassetid://130497681390048")
item("item_085", "Canonique des Sept Sceaux", "Supreme", "armor", "rbxassetid://91188576237825")
item("item_086", "Espadon de la Cathédrale Noyée", "Supreme", "weapon", "rbxassetid://131190029947810")
item("item_087", "Aiguilles du Temps Retors", "Supreme", "weapon", "rbxassetid://128513830437789")
item("item_088", "Orbe des Îles Suspendues", "Supreme", "relic", "rbxassetid://110421157909265")
item("item_089", "Mantelet du Léviathan Blanc", "Supreme", "armor", "rbxassetid://120392717854214")
item("item_090", "Grimoire de l’Éclipse Murmurante", "Supreme", "relic", "rbxassetid://70658529998703")
-- Calamité
item("item_091", "Marteau du Dernier Impact", "Calamite", "weapon", "rbxassetid://71776510399811")
item("item_092", "Anneau du Soleil Écorché", "Calamite", "accessory", "rbxassetid://73921760318348")
item("item_093", "Couronne du Ciel Fendu", "Calamite", "helmet", "rbxassetid://78698539051651")
item("item_094", "Armure des Ruines Orbitales", "Calamite", "armor", "rbxassetid://109707026359600")
item("item_095", "Cloche du Jugement Creux", "Calamite", "relic", "rbxassetid://134530618180353")
item("item_096", "Lance Maréenne de l’Abysse Renversé", "Calamite", "weapon", "rbxassetid://101062911360994")
-- Transcendant
item("item_097", "Lame de la Première Aube", "Transcendant", "weapon", "rbxassetid://102620328440835")
item("item_098", "Sablier Hors du Monde", "Transcendant", "relic", "rbxassetid://103028452725598")
item("item_099", "Diadème des Dix Horizons", "Transcendant", "helmet", "rbxassetid://74510482592969")
item("item_100", "Cœur du Royaume Éveillé", "Transcendant", "relic", "rbxassetid://124657796334257")

local ItemConfig = {
	-- Items par ItemId (« item_037 »).
	Items = table.freeze(Items),
	-- Items dans l'ordre de la vitrine (Index 1 à 100).
	Ordered = table.freeze(Ordered),
	SlotTypes = table.freeze(SlotTypes),
	-- Id d'emplacement → libellé affiché (« weapon » → « Arme »).
	SlotTypeNames = table.freeze(SlotTypeNames),
}

-- Nom de la carte de la vitrine pour un item : « Item_037 ».
function ItemConfig.slotName(index: number): string
	return string.format("Item_%03d", index)
end

return table.freeze(ItemConfig)
