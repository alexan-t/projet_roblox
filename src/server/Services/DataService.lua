--!strict
-- Source de vérité des données joueur, basée sur ProfileStore (verrou de session + sauvegarde auto).
-- Join : ouverture de session -> migration -> Reconcile -> joueur prêt (attribut "DataLoaded").
-- Leave : fin de session et sauvegarde. Fermeture serveur : ProfileStore sauvegarde tout (BindToClose).
--
-- Pour les autres services (appeler depuis Start, jamais depuis Init) :
--   DataService:GetData(player)      -> données, ou nil si pas encore prêtes (ne bloque pas)
--   DataService:WaitForData(player)  -> bloque jusqu'au chargement ; nil si le joueur est parti
--   DataService:OnPlayerReady(fn)    -> fn(player, data) pour chaque joueur prêt, y compris ceux déjà chargés
-- Ne jamais garder de référence aux données après le départ du joueur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)
local DefaultPlayerData = require(script.Parent.Parent.Data.DefaultPlayerData)
local Migrations = require(script.Parent.Parent.Data.Migrations)

type PlayerData = PlayerDataTypes.PlayerData
type Profile = ProfileStore.Profile<PlayerData>
type ReadyCallback = (player: Player, data: PlayerData) -> ()

local SCOPE = "DataService"
-- Store séparé en Studio : les tests ne touchent jamais aux données des vrais joueurs.
local STORE_NAME = if RunService:IsStudio() then "PlayerData_Studio" else "PlayerData"

local KICK_LOAD_FAILED = "Impossible de charger tes données. Réessaie dans quelques instants."
local KICK_SESSION_ENDED = "Ta session a été ouverte sur un autre serveur. Reconnecte-toi."
local KICK_DATA_TOO_NEW = "Ce serveur n'est pas à jour. Rejoins une autre partie."

local DataService = {}

local store: ProfileStore.ProfileStore<PlayerData>
local profiles: { [Player]: Profile } = {}
local readyCallbacks: { ReadyCallback } = {}
-- Déclenché quand un joueur devient prêt ou quitte le jeu (réveille WaitForData).
local stateChanged = Instance.new("BindableEvent")

local function dataOf(profile: Profile): PlayerData
	return profile.Data :: any
end

local function loadProfile(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function(): boolean
			return player.Parent ~= Players
		end,
	} :: any)

	if not profile then
		-- Le joueur est parti pendant le chargement, ou ProfileStore n'a pas pu ouvrir la session.
		if player.Parent == Players then
			Log.warn(SCOPE, `Session impossible à ouvrir pour {player.Name}`)
			player:Kick(KICK_LOAD_FAILED)
		end
		return
	end

	local migration = Migrations.run(profile.Data :: any)
	if migration ~= "Ok" then
		-- Données laissées intactes : on rend la session sans rien modifier.
		Log.warn(SCOPE, `Données de {player.Name} non chargées (migration : {migration})`)
		profile:EndSession()
		player:Kick(if migration == "TooNew" then KICK_DATA_TOO_NEW else KICK_LOAD_FAILED)
		return
	end

	profile:AddUserId(player.UserId) -- conformité RGPD
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:SetAttribute("DataLoaded", nil)
			player:Kick(KICK_SESSION_ENDED)
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	player:SetAttribute("DataLoaded", true)
	Log.info(SCOPE, `Données chargées pour {player.Name} (session n°{profile.SessionLoadCount})`)

	local data = dataOf(profile)
	for _, callback in readyCallbacks do
		task.spawn(callback, player, data)
	end
	stateChanged:Fire()
end

function DataService:Init()
	store = ProfileStore.New(STORE_NAME, DefaultPlayerData :: any) :: any

	ProfileStore.OnError:Connect(function(message: string, storeName: string, profileKey: string)
		Log.warn(SCOPE, `ProfileStore {storeName}/{profileKey} : {message}`)
	end)
end

function DataService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
		stateChanged:Fire()
	end)

	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Log.debug(SCOPE, `Store "{STORE_NAME}" prêt`)
end

function DataService:GetData(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then dataOf(profile) else nil
end

function DataService:WaitForData(player: Player): PlayerData?
	while player.Parent == Players do
		local profile = profiles[player]
		if profile then
			return dataOf(profile)
		end
		stateChanged.Event:Wait()
	end
	return nil
end

function DataService:OnPlayerReady(callback: ReadyCallback)
	table.insert(readyCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, dataOf(profile))
	end
end

return DataService
