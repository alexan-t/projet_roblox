--!strict
-- Héros possédés, hotbar et invocation (voir docs/HEROES.md) — issue #10.
-- HeroId = identifiant réel du héros (HeroConfig, ServerStorage.Assets.Heros), jamais une classe de
-- combat : le profil et le modèle de combat temporaires viennent de HeroConfig (GetCombatHero).
-- Remotes :
--   GetHeroes (RemoteFunction)     -> vue { Heroes, Hotbar } du joueur ;
--   HeroesChanged (RemoteEvent)    -> nouvelle vue après tout changement ;
--   HotbarAction (RemoteFunction)  -> Assign / Clear / Swap, revérifiés ;
--   RequestSummon (RemoteFunction) -> invocation ; le client n'envoie rien : le serveur décide tout ;
--   HeroObtained (RemoteEvent)     -> { InstanceId, HeroId, Name, New } au seul joueur concerné.
-- Au démarrage, les modèles des héros activés sont clonés de ServerStorage.Assets.Heros vers
-- ReplicatedStorage.Assets.Heros (révélation de l'invocation côté client).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local CombatConfig = require(script.Parent.Parent.Config.CombatConfig)
local SummonConfig = require(script.Parent.Parent.Config.SummonConfig)
local HeroRules = require(script.Parent.Parent.Heroes.HeroRules)
local SummonRules = require(script.Parent.Parent.Heroes.SummonRules)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local KingdomService = require(script.Parent.KingdomService)

local SCOPE = "HeroService"
local ASSETS_NAME = "Assets"
local HEROES_ASSETS_NAME = "Heros"

export type Obtained = { InstanceId: string, HeroId: string, Name: string, New: boolean }
type ObtainedCallback = (player: Player, obtained: Obtained) -> ()

local HeroService = {}

local changedEvent: RemoteEvent? = nil
local obtainedEvent: RemoteEvent? = nil
local obtainedCallbacks: { ObtainedCallback } = {}
local lastAction: { [Player]: number } = {}
local summoning: { [Player]: boolean } = {}
local summonEnabled = true
local random = Random.new()

local idSequence = 0

-- Identifiant d'exemplaire unique, trié dans l'ordre d'obtention : préfixe horodaté de largeur fixe
-- (KingdomService range les héros dans l'ordre des identifiants : le starter reste sur Heros_1).
-- Les anciens identifiants "H_<GUID>" (chiffres / A-F) restent valides et se trient avant.
local function newId(): string
	idSequence = (idSequence + 1) % 10000
	return string.format("H_T%010d%04d_%s", os.time(), idSequence, HttpService:GenerateGUID(false))
end

local function loaded(player: Player): any
	if player.Parent ~= Players or player:GetAttribute("DataLoaded") ~= true then
		return nil
	end
	return DataService:GetData(player)
end

local function push(player: Player)
	local data = DataService:GetData(player)
	local event = changedEvent
	if data and event and player.Parent == Players then
		event:FireClient(player, HeroRules.view(data))
	end
end

function HeroService:HotbarAction(player: Player, action: any, first: any, second: any): (boolean, string?)
	local data = loaded(player)
	if not data then
		return false, "données non chargées"
	end
	return HeroRules.hotbarAction(data, HeroConfig.HotbarSize, action, first, second)
end

-- Exemplaire possédé et jouable : HeroId réel + profil et modèle de combat temporaires
-- ({ HeroId, CombatProfile, CombatTemplate }), sinon nil et la raison.
function HeroService:GetCombatHero(player: Player, instanceId: any): (HeroRules.CombatHero?, string?)
	local data = DataService:GetData(player)
	if not data then
		return nil, "données non chargées"
	end
	return HeroRules.combatHero(data, instanceId, HeroConfig.Heroes, CombatConfig.Heroes)
end

-- Ajoute un exemplaire d'un héros activé (hotbar si une case est libre, sinon collection).
-- Renvoie son identifiant, ou nil (données absentes, HeroId inconnu de HeroConfig).
function HeroService:AddHero(player: Player, heroId: string): string?
	local data = DataService:GetData(player)
	if not data or not HeroConfig.Heroes[heroId] then
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

-- Héros obtenu (invocation) : callback(player, { InstanceId, HeroId, Name, New }), après la
-- sauvegarde dans PlayerData et le Refresh du royaume.
function HeroService:OnHeroObtained(callback: ObtainedCallback)
	table.insert(obtainedCallbacks, callback)
end

-- Portail d'invocation du plot du joueur (jamais un portail global ni une Instance du client).
local function portalOf(player: Player): Instance?
	local plot = PlotService:GetPlot(player)
	local portal = plot and plot:FindFirstChild(SummonConfig.PortalName)
	return if portal and (portal:IsA("Model") or portal:IsA("BasePart")) then portal else nil
end

-- Le joueur peut-il invoquer maintenant ? Renvoie ses données, ou nil et la raison.
function HeroService:CanSummon(player: Player): (any, string?)
	if not summonEnabled then
		return nil, "invocation indisponible"
	end
	local data = loaded(player)
	if not data then
		return nil, "données non chargées"
	end
	if summoning[player] then
		return nil, "invocation déjà en cours"
	end
	local portal = portalOf(player)
	if not portal then
		return nil, "aucun portail"
	end
	local character: any = player.Character
	local root: any = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid: any = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil, "personnage indisponible"
	end
	local target = (portal :: any):GetPivot().Position
	local offset = root.Position - target
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > SummonConfig.MaxDistance then
		return nil, "approche-toi de ton portail"
	end
	if not SummonRules.canPay(data, SummonConfig) then
		return nil, "pas de ticket d'invocation"
	end
	return data, nil
end

-- Invocation autoritaire. Section critique synchrone (aucun yield) entre la vérification du ticket
-- et les mutations : deux demandes simultanées avec un seul ticket donnent une seule réussite.
function HeroService:RequestSummon(player: Player): (Obtained?, string?)
	local data, reason = HeroService:CanSummon(player)
	if not data then
		return nil, reason
	end
	summoning[player] = true
	local ok, result, why = pcall(SummonRules.summon, data, SummonConfig, newId, function(n: number): number
		return random:NextInteger(1, n)
	end)
	summoning[player] = nil
	if not ok then
		Log.warn(SCOPE, `Invocation de {player.Name} en échec : {tostring(result)}`)
		return nil, "invocation impossible"
	end
	if not result then
		return nil, why
	end
	local info = HeroConfig.Heroes[result.HeroId]
	local obtained: Obtained = {
		InstanceId = result.InstanceId,
		HeroId = result.HeroId,
		Name = if info then info.Name else result.HeroId,
		New = result.New,
	}
	Log.info(SCOPE, `{player.Name} invoque {result.HeroId} ({result.InstanceId}, nouveau = {tostring(result.New)}, royaume = {tostring(result.KingdomChanged)})`)
	KingdomService:Refresh(player)
	push(player)
	local event = obtainedEvent
	if event and player.Parent == Players then
		event:FireClient(player, obtained)
	end
	for _, callback in obtainedCallbacks do
		task.spawn(callback, player, table.clone(obtained))
	end
	return obtained, nil
end

-- Copie client des modèles des héros activés (lecture seule, sans script ni collision).
local function replicateHeroAssets()
	local assets = ServerStorage:FindFirstChild(ASSETS_NAME)
	local source = assets and assets:FindFirstChild(HEROES_ASSETS_NAME)
	if not source then
		Log.warn(SCOPE, "ServerStorage.Assets.Heros introuvable : aucun modèle de héros pour le client")
		return
	end
	local shared = ReplicatedStorage:FindFirstChild(ASSETS_NAME)
	if not shared then
		shared = Instance.new("Folder")
		shared.Name = ASSETS_NAME
		shared.Parent = ReplicatedStorage
	end
	assert(shared)
	local target = shared:FindFirstChild(HEROES_ASSETS_NAME)
	if not target then
		target = Instance.new("Folder")
		target.Name = HEROES_ASSETS_NAME
		target.Parent = shared
	end
	assert(target)
	local present: { [string]: boolean } = {}
	for _, model in target:GetChildren() do
		local heroId = model:GetAttribute("HeroId")
		if typeof(heroId) == "string" then present[heroId] = true end
	end
	for heroId in HeroConfig.Heroes do
		if present[heroId] then continue end
		local model: Model? = nil
		for _, candidate in source:GetChildren() do
			if candidate:IsA("Model") and candidate:GetAttribute("HeroId") == heroId then
				model = candidate
				break
			end
		end
		if not model then
			Log.warn(SCOPE, `Aucun modèle avec HeroId = {heroId} dans ServerStorage.Assets.Heros`)
			continue
		end
		local copy = model:Clone()
		for _, item in copy:GetDescendants() do
			if item:IsA("LuaSourceContainer") then
				item:Destroy()
			elseif item:IsA("BasePart") then
				item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
			end
		end
		copy:SetAttribute("HeroId", heroId)
		copy.Parent = target
	end
end

function HeroService:Init()
	local problems = SummonRules.configProblems(SummonConfig, HeroConfig.Heroes)
	for heroId, info in HeroConfig.Heroes do
		if not CombatConfig.Heroes[info.CombatProfile] then
			table.insert(problems, `{heroId} : profil de combat inconnu {info.CombatProfile}`)
		end
	end
	for _, heroId in HeroConfig.StarterHeroes do
		if not HeroConfig.Heroes[heroId] then
			table.insert(problems, `StarterHeroes : HeroId inconnu {heroId}`)
		end
	end
	for _, problem in problems do
		Log.warn(SCOPE, `Config invalide : {problem}`)
	end
	summonEnabled = #problems == 0
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
	local obtained = Instance.new("RemoteEvent")
	obtained.Name = "HeroObtained"
	obtained.Parent = remotes
	obtainedEvent = obtained
	local get = Instance.new("RemoteFunction")
	get.Name = "GetHeroes"
	get.OnServerInvoke = function(player: Player): any
		local data = DataService:GetData(player)
		return if data then HeroRules.view(data) else nil
	end
	get.Parent = remotes
	local edit = Instance.new("RemoteFunction")
	edit.Name = "HotbarAction"
	edit.OnServerInvoke = function(player: Player, action: any, first: any, second: any)
		local now = os.clock()
		if now - (lastAction[player] or -math.huge) < 0.1 then return false, "réessaie dans un instant" end
		lastAction[player] = now
		local ok, reason = self:HotbarAction(player, action, first, second)
		if ok then push(player) end
		local data = DataService:GetData(player)
		return ok, reason, if data then HeroRules.view(data) else nil
	end
	edit.Parent = remotes
	-- Aucun argument n'est lu : HeroId, coût et résultat sont décidés par le serveur.
	local summon = Instance.new("RemoteFunction")
	summon.Name = "RequestSummon"
	summon.OnServerInvoke = function(player: Player): (boolean, any)
		local result, reason = HeroService:RequestSummon(player)
		if result then
			return true, result
		end
		return false, reason
	end
	summon.Parent = remotes
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		summoning[player] = nil
	end)

	replicateHeroAssets()

	DataService:OnPlayerReady(function(player: Player, data: any)
		HeroRules.normalizeHotbar(data, HeroConfig.HotbarSize)
		local granted = HeroRules.grantStarter(data, HeroConfig.StarterHeroes, newId)
		if granted > 0 then
			Log.info(SCOPE, `Héros de départ donnés à {player.Name} ({granted})`)
			KingdomService:Refresh(player)
		end
		push(player)
	end)
end

return HeroService
