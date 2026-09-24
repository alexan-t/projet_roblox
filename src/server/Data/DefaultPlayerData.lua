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
	},
	Heroes = {},
	Team = {},
	Kingdom = {
		Level = 1,
		VisualState = 1,
	},
	Quests = {},
	Settings = {
		CombatSpeed = 1,
	},
}

return DefaultPlayerData
