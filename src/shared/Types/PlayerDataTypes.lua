--!strict
-- Structure des données joueur sauvegardées (source de vérité : DataService côté serveur).
-- Règles ProfileStore : pas d'Instance, pas de Vector3/CFrame, pas de tableau à trous,
-- pas de table mixte (index numériques + clés texte).

export type Currencies = {
	Gold: number,
	Gems: number,
	SummonTickets: number,
}

export type Progression = {
	CurrentZone: number,
	HighestStage: number,
	-- Clé = identifiant du stage, valeur = true une fois terminé la première fois.
	FirstClears: { [string]: boolean },
	-- Mode Élite (#69) : même format, progression indépendante (ajoutée aux anciens profils par Reconcile).
	EliteFirstClears: { [string]: boolean },
}

export type Hero = {
	HeroId: string, -- HeroId réel (catalogue HeroConfig, modèles ServerStorage.Assets.Heros), jamais une classe de combat
	Level: number, -- 1..HeroProgressionConfig.MaxLevel, propre à CET exemplaire
	XP: number, -- progression DANS le niveau courant (pas d'XP cumulée) ; 0 au niveau maximum
}

export type Summons = {
	Total: number, -- résultats payants ; starter exclu ; 0 = garantie Épique ou mieux + version de requête
}

export type Kingdom = {
	Level: number,
	VisualState: number,
}

export type QuestState = {
	Progress: number,
	Claimed: boolean,
}

export type Settings = {
	CombatSpeed: number,
}

-- Drapeaux « vu une fois » du guidage (TutorialConfig.Flags) : clé = drapeau, valeur = true.
export type Tutorial = {
	Seen: { [string]: boolean },
}

-- Inventaire (#72). Equipment : une entrée par EXEMPLAIRE possédé (clé = ItemInstanceId « I_T… » généré par le
-- serveur, jamais fusionné) ; ItemId = catalogue ItemConfig, UpgradeLevel stocké dès V1 (aucun effet).
-- Resources : pile par ResourceId (ResourceConfig), entier >= 0, sans rareté. Clés fixes : ajoutées aux anciens
-- profils par Reconcile (aucune migration, DataVersion reste 4).
export type OwnedItem = {
	ItemId: string,
	UpgradeLevel: number,
}

export type Inventory = {
	Equipment: { [string]: OwnedItem },
	Resources: { [string]: number },
}

-- Équipement porté (#73) : SlotType (ItemConfig.SlotTypes) -> ItemInstanceId de Inventory.Equipment.
-- Slot absent ou "" = vide. Un exemplaire n'est porté que par un héros, dans un slot (EquipmentRules).
export type HeroSlots = { [string]: string }

export type PlayerData = {
	DataVersion: number,
	Currencies: Currencies,
	Progression: Progression,
	-- Clé = identifiant unique de l'exemplaire possédé (plusieurs exemplaires d'un même HeroId possibles).
	Heroes: { [string]: Hero },
	-- Liste ordonnée d'identifiants d'exemplaires de Heroes.
	Team: { string },
	-- Raccourcis 1..0 : exactement HeroConfig.HotbarSize identifiants d'exemplaires, "" = case vide
	-- (pas de tableau à trous dans ProfileStore).
	Hotbar: { string },
	Summons: Summons,
	Kingdom: Kingdom,
	-- Clé = identifiant de quête.
	Quests: { [string]: QuestState },
	Settings: Settings,
	-- Ajouté aux anciens profils par Reconcile (aucune migration) : vide = aucun guidage déjà vu.
	Tutorial: Tutorial,
	-- Ajouté aux anciens profils par Reconcile (aucune migration) : vide = rien possédé.
	Inventory: Inventory,
	-- Clé = HeroInstanceId (exemplaire de Heroes). Ajouté aux anciens profils par Reconcile (aucune migration).
	HeroEquipment: { [string]: HeroSlots },
}

return {}
