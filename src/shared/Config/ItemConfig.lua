--!strict
-- Catalogue des items 2D (voir docs/ITEMS.md). Partagé : la Sacoche, l'écran de récompenses et la
-- vitrine Studio en lisent le nom, la rareté, l'emplacement et l'icône. Aucun système d'items en jeu
-- pour l'instant (pas de stockage dans PlayerData, pas d'obtention, pas de statistiques).
--
-- Source : vitrine Workspace.Bestiaire.Inventaire (attributs ItemId, Index, Rarete, SlotType et
-- texte Nom des cartes Item_NNN, pré-remplis depuis items_equipment.json). Identifiants par rareté
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
item("item_001", "Épée du Rempart", "Commun", "weapon")
item("item_002", "Arc de Chêne Tendu", "Commun", "weapon")
item("item_003", "Bâton de Braise", "Commun", "weapon")
item("item_004", "Heaume du Veilleur", "Commun", "helmet")
-- Peu commun
item("item_005", "Lance du Guetteur", "PeuCommun", "weapon")
item("item_006", "Masse de Garnison", "PeuCommun", "weapon")
item("item_007", "Capuche du Chasseur Gris", "PeuCommun", "helmet")
item("item_008", "Cuirasse du Domaine", "PeuCommun", "armor")
item("item_009", "Bottes des Sentiers", "PeuCommun", "boots")
item("item_010", "Anneau de Pierre Claire", "PeuCommun", "accessory")
-- Rare
item("item_011", "Broche de Bannière", "Rare", "accessory")
item("item_012", "Pendentif du Campement", "Rare", "accessory")
item("item_013", "Fiole de Rosée", "Rare", "relic")
item("item_014", "Fragment de Cristal Royal", "Rare", "relic")
item("item_015", "Lame des Ronces", "Rare", "weapon")
item("item_016", "Marteau Brise Cloche", "Rare", "weapon")
item("item_017", "Arbalète des Pins Noirs", "Rare", "weapon")
item("item_018", "Faucille du Croissant", "Rare", "weapon")
item("item_019", "Bâton des Lucioles", "Rare", "weapon")
item("item_020", "Dagues du Miroir Fendu", "Rare", "weapon")
-- Épique
item("item_021", "Couronne de Lierre Doré", "Epique", "helmet")
item("item_022", "Masque du Veilleur de Givre", "Epique", "helmet")
item("item_023", "Casque du Fauconnier", "Epique", "helmet")
item("item_024", "Armure des Racines Vivantes", "Epique", "armor")
item("item_025", "Manteau des Cendres Bleues", "Epique", "armor")
item("item_026", "Robe de la Marée Fine", "Epique", "armor")
item("item_027", "Cuirasse du Clocher Sacré", "Epique", "armor")
item("item_028", "Bottes du Vent Bas", "Epique", "boots")
item("item_029", "Gantelets Runiques", "Epique", "gloves")
item("item_030", "Sablier du Pas Calme", "Epique", "accessory")
item("item_031", "Lanterne du Mage Errant", "Epique", "accessory")
item("item_032", "Plume du Faucon Ancien", "Epique", "accessory")
item("item_033", "Médaillon de Source Vive", "Epique", "accessory")
item("item_034", "Cœur de Tréant Poli", "Epique", "relic")
-- Légendaire
item("item_035", "Œil de Slime Royal", "Legendaire", "relic")
item("item_036", "Clochette du Premier Sanctuaire", "Legendaire", "relic")
item("item_037", "Épée du Soleil Creux", "Legendaire", "weapon")
item("item_038", "Lance des Sept Orages", "Legendaire", "weapon")
item("item_039", "Marteau Forgeâme", "Legendaire", "weapon")
item("item_040", "Arc Chasseur de Comètes", "Legendaire", "weapon")
item("item_041", "Lame du Serment Brisé", "Legendaire", "weapon")
item("item_042", "Cisaille des Portes Oubliées", "Legendaire", "weapon")
item("item_043", "Sceptre des Marées Lunaires", "Legendaire", "weapon")
item("item_044", "Hallebarde de l’Éclipse Blanche", "Legendaire", "weapon")
item("item_045", "Couronne Parasite", "Legendaire", "helmet")
item("item_046", "Heaume des Mille Clous", "Legendaire", "helmet")
item("item_047", "Voile de la Lune Fendue", "Legendaire", "helmet")
item("item_048", "Diadème du Firmament Doré", "Legendaire", "helmet")
item("item_049", "Masque aux Cent Yeux", "Legendaire", "helmet")
item("item_050", "Armure du Cœur Noir", "Legendaire", "armor")
item("item_051", "Manteau des Corbeaux Sans Ombre", "Legendaire", "armor")
item("item_052", "Cuirasse de l’Aube Infinie", "Legendaire", "armor")
-- Mythique
item("item_053", "Robe des Destins Tissés", "Mythique", "armor")
item("item_054", "Plastron du Trône Vide", "Mythique", "armor")
item("item_055", "Armure du Cataclysme Fissuré", "Mythique", "armor")
item("item_056", "Bottes du Temps Décalé", "Mythique", "boots")
item("item_057", "Gantelets de la Mer Renversée", "Mythique", "gloves")
item("item_058", "Bottes Astrales du Berger", "Mythique", "boots")
item("item_059", "Anneau de l’Œil Orbital", "Mythique", "accessory")
item("item_060", "Broche du Dragon Dormant", "Mythique", "accessory")
item("item_061", "Pendentif de Constellation Liée", "Mythique", "accessory")
item("item_062", "Sceau des Sept Verrous", "Mythique", "accessory")
item("item_063", "Médaillon du Temps Mort", "Mythique", "accessory")
item("item_064", "Nœud de Destin", "Mythique", "accessory")
item("item_065", "Épingle du Roi Racine", "Mythique", "accessory")
item("item_066", "Bocal de Tempête", "Mythique", "relic")
item("item_067", "Cœur de Golem Cloche", "Mythique", "relic")
item("item_068", "Larme du Léviathan", "Mythique", "relic")
item("item_069", "Éclat d’Île Céleste", "Mythique", "relic")
item("item_070", "Fragment de Lune Mordante", "Mythique", "relic")
-- Maudit
item("item_071", "Dent du Dragon des Étoiles", "Maudit", "relic")
item("item_072", "Sablier des Âges Brisés", "Maudit", "relic")
item("item_073", "Soleil Dévoré en Cage", "Maudit", "relic")
item("item_074", "Couronne de l’Aube Première", "Maudit", "helmet")
item("item_075", "Grimoire des Noms Effacés", "Maudit", "relic")
item("item_076", "Luth des Funérailles Joyeuses", "Maudit", "weapon")
item("item_077", "Lanternon du Veilleur Sans Visage", "Maudit", "accessory")
item("item_078", "Grèves des Pas Sans Ombre", "Maudit", "boots")
item("item_079", "Collier du Cœur Enfermé", "Maudit", "accessory")
item("item_080", "Écharpe des Corbeaux Murmurants", "Maudit", "armor")
item("item_081", "Flûte du Sable Vivant", "Maudit", "weapon")
item("item_082", "Miroir de la Treizième Aube", "Maudit", "relic")
-- Suprême
item("item_083", "Trône Miniature de l’Empereur Cendre", "Supreme", "relic")
item("item_084", "Tiare des Marées Inversées", "Supreme", "helmet")
item("item_085", "Canonique des Sept Sceaux", "Supreme", "armor")
item("item_086", "Espadon de la Cathédrale Noyée", "Supreme", "weapon")
item("item_087", "Aiguilles du Temps Retors", "Supreme", "weapon")
item("item_088", "Orbe des Îles Suspendues", "Supreme", "relic")
item("item_089", "Mantelet du Léviathan Blanc", "Supreme", "armor")
item("item_090", "Grimoire de l’Éclipse Murmurante", "Supreme", "relic")
-- Calamité
item("item_091", "Marteau du Dernier Impact", "Calamite", "weapon")
item("item_092", "Anneau du Soleil Écorché", "Calamite", "accessory")
item("item_093", "Couronne du Ciel Fendu", "Calamite", "helmet")
item("item_094", "Armure des Ruines Orbitales", "Calamite", "armor")
item("item_095", "Cloche du Jugement Creux", "Calamite", "relic")
item("item_096", "Lance Maréenne de l’Abysse Renversé", "Calamite", "weapon")
-- Transcendant
item("item_097", "Lame de la Première Aube", "Transcendant", "weapon")
item("item_098", "Sablier Hors du Monde", "Transcendant", "relic")
item("item_099", "Diadème des Dix Horizons", "Transcendant", "helmet")
item("item_100", "Cœur du Royaume Éveillé", "Transcendant", "relic")

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
