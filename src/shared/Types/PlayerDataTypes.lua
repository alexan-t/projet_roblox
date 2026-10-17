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
	Total: number, -- invocations réussies ; 0 = la prochaine est la première (tirage garanti)
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
}

return {}
