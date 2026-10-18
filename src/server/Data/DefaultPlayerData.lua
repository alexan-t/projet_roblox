--!strict
-- Données d'un nouveau joueur. Sert aussi de modèle à Profile:Reconcile() :
-- toute clé ajoutée ici apparaît automatiquement dans les profils existants.
-- Les montants de départ sont provisoires, à ajuster avec le game design.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local Migrations = require(script.Parent.Migrations)

local DefaultPlayerData: PlayerDataTypes.PlayerData = {
	DataVersion = Migrations.CURRENT_VERSION,
	Currencies = {
		Gold = 0,
		Gems = 0,
		SummonTickets = 0,
	},
	Progression = {
		CurrentZone = 1,
		HighestStage = 0,
		FirstClears = {},
		-- Mode Élite (#69) : vide pour tout profil, nouveau ou ancien (aucun clear Élite rétroactif).
		EliteFirstClears = {},
	},
	-- Aucun héros : le premier est obtenu pendant l'invocation tutorielle (quête SummonStarter).
	Heroes = {},
	Team = {},
	-- 10 raccourcis vides (HeroConfig.HotbarSize) ; HeroService les remplit.
	Hotbar = { "", "", "", "", "", "", "", "", "", "" },
	-- Résultats payants réussis (HeroService), starter exclu : 0 = premier résultat Épique ou mieux.
	Summons = {
		Total = 0,
	},
	Kingdom = {
		Level = 1,
		VisualState = 1,
	},
	Quests = {},
	Settings = {
		CombatSpeed = 1,
	},
	-- Guidage du tutoriel (TutorialService) : drapeaux « vu une fois » de TutorialConfig.Flags.
	Tutorial = {
		Seen = {},
	},
}

return DefaultPlayerData
