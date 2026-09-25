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
}

export type Hero = {
	HeroId: string, -- type de héros (référence au catalogue)
	Level: number,
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

export type PlayerData = {
	DataVersion: number,
	Currencies: Currencies,
	Progression: Progression,
	-- Clé = identifiant unique de l'exemplaire possédé (plusieurs exemplaires d'un même HeroId possibles).
	Heroes: { [string]: Hero },
	-- Liste ordonnée d'identifiants d'exemplaires de Heroes.
	Team: { string },
	Kingdom: Kingdom,
	-- Clé = identifiant de quête.
	Quests: { [string]: QuestState },
	Settings: Settings,
}

return {}
