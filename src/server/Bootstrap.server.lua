--!strict
-- Point d'entrée serveur : charge chaque ModuleScript du dossier Services,
-- appelle Init() sur tous, puis Start() sur tous (voir Shared/Utils/Loader).
-- Pour ajouter un service : créer src/server/Services/<Nom>Service.lua
-- qui retourne une table avec Init() et/ou Start() (les deux sont optionnels).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Loader = require(Shared.Utils.Loader)
local Log = require(Shared.Utils.Log)

local SCOPE = "Bootstrap"

local servicesFolder = script.Parent:FindFirstChild("Services")
if not servicesFolder then
	Log.warn(SCOPE, "Dossier Services introuvable, aucun service chargé")
	return
end

local services = Loader.loadFolder(servicesFolder, SCOPE)
Loader.initAndStart(services, SCOPE)

Log.info(SCOPE, `Serveur démarré (v{GameConfig.Version}, {#services} service(s))`)
