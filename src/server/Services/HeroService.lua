--!strict
-- Héros possédés et hotbar (voir docs/HEROES.md). Partie Alpha de HeroService (#10) :
-- kit de départ, ajout automatique à la hotbar, vérification de possession pour l'arène.
-- Pas encore d'invocation, de niveaux ni d'édition manuelle de la hotbar.
-- Le client lit sa collection (Remotes.GetHeroes) et reçoit les changements (Remotes.HeroesChanged).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local CombatConfig = require(script.Parent.Parent.Config.CombatConfig)
local HeroRules = require(script.Parent.Parent.Heroes.HeroRules)
local DataService = require(script.Parent.DataService)
local KingdomService = require(script.Parent.KingdomService)

local SCOPE = "HeroService"

local HeroService = {}

local changedEvent: RemoteEvent? = nil

local function newId(): string
	return "H_" .. HttpService:GenerateGUID(false)
end

local function push(player: Player)
	local data = DataService:GetData(player)
	local event = changedEvent
	if data and event and player.Parent == Players then
		event:FireClient(player, HeroRules.view(data))
	end
end

-- HeroId d'un exemplaire possédé par le joueur et utilisable au combat, sinon nil et la raison.
function HeroService:GetCombatHero(player: Player, instanceId: any): (string?, string?)
	local data = DataService:GetData(player)
	if not data then
		return nil, "données non chargées"
	end
	return HeroRules.ownedHeroId(data, instanceId, CombatConfig.Heroes)
end

-- Ajoute un exemplaire (hotbar si une case est libre, sinon collection). Renvoie son identifiant.
function HeroService:AddHero(player: Player, heroId: string): string?
	local data = DataService:GetData(player)
	if not data then
		return nil
	end
	local id = newId()
	HeroRules.addHero(data, id, heroId)
	KingdomService:Refresh(player)
	push(player)
	return id
end

function HeroService:RemoveHero(player: Player, instanceId: string): boolean
	local data = DataService:GetData(player)
	if not data or not HeroRules.removeHero(data, instanceId) then
		return false
	end
	KingdomService:Refresh(player)
	push(player)
	return true
end

function HeroService:Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end
	assert(remotes)
	local event = Instance.new("RemoteEvent")
	event.Name = "HeroesChanged"
	event.Parent = remotes
	changedEvent = event
	local get = Instance.new("RemoteFunction")
	get.Name = "GetHeroes"
	get.OnServerInvoke = function(player: Player): any
		local data = DataService:GetData(player)
		return if data then HeroRules.view(data) else nil
	end
	get.Parent = remotes

	DataService:OnPlayerReady(function(player: Player, data: any)
		HeroRules.normalizeHotbar(data, HeroConfig.HotbarSize)
		local granted = HeroRules.grantStarter(data, HeroConfig.StarterHeroes, newId)
		if granted > 0 then
			Log.info(SCOPE, `Kit de départ donné à {player.Name} ({granted} héros)`)
			KingdomService:Refresh(player)
		end
		push(player)
	end)
end

return HeroService
