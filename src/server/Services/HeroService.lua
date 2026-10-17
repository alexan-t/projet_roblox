--!strict
-- Héros possédés, hotbar et invocation (voir docs/HEROES.md) — issue #10.
-- HeroId = identifiant réel du héros (HeroConfig, ServerStorage.Assets.Heros), jamais une classe de
-- combat : le profil et le modèle de combat temporaires viennent de HeroConfig (GetCombatHero).
-- Remotes :
--   GetHeroes (RemoteFunction)     -> vue { Heroes, Hotbar } du joueur ;
--   HeroesChanged (RemoteEvent)    -> nouvelle vue après tout changement ;
--   HotbarAction (RemoteFunction)  -> Assign / Clear / Swap, revérifiés ;
--   RequestSummon (RemoteFunction) -> invocation ; le client n'envoie que l'Id de la bannière
--                                     (validé) : héros, rareté, coût et résultat sont décidés ici ;
--   HeroObtained (RemoteEvent)     -> { InstanceId, HeroId, Name, New, Rarity } au seul joueur concerné ;
--   GetSummonState (RemoteFunction) -> { Tickets, Cost, Starter } pour la fenêtre d'invocation (lecture
--                                     seule ; Starter = { Active, HeroId, Name, Rarity } : invocation
--                                     tutorielle disponible et héros présenté, sinon { Active = false }) ;
--   RequestStarterSummon (RemoteFunction) -> invocation tutorielle (onboarding) : aucun argument, le
--                                     serveur revérifie tout et donne SummonConfig.Starter.HeroId, gratuit,
--                                     une seule fois, pendant la quête SummonConfig.Starter.QuestId.
-- Un nouveau profil n'a aucun héros : le premier est obtenu pendant l'invocation tutorielle.
-- Niveaux et XP (#68) : par exemplaire (HeroInstanceId). GetCombatRoster fige, au lancement d'un combat,
-- les héros posés et leurs stats de niveau ; GrantCombatXP leur donne l'XP d'une victoire acceptée
-- (appelé par le combat, jamais par un client : aucune remote d'XP).
-- Au démarrage, les modèles des héros activés sont clonés de ServerStorage.Assets.Heros vers
-- ReplicatedStorage.Assets.Heros (révélation de l'invocation côté client).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Log = require(ReplicatedStorage.Shared.Utils.Log)
local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local SummonBannerConfig = require(ReplicatedStorage.Shared.Config.SummonBannerConfig)
local CombatConfig = require(script.Parent.Parent.Config.CombatConfig)
local SummonConfig = require(script.Parent.Parent.Config.SummonConfig)
local HeroProgressionConfig = require(script.Parent.Parent.Config.HeroProgressionConfig)
local HeroRules = require(script.Parent.Parent.Heroes.HeroRules)
local HeroProgressionRules = require(script.Parent.Parent.Heroes.HeroProgressionRules)
local SummonRules = require(script.Parent.Parent.Heroes.SummonRules)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local KingdomService = require(script.Parent.KingdomService)
local QuestService = require(script.Parent.QuestService)

local SCOPE = "HeroService"
local ASSETS_NAME = "Assets"
local HEROES_ASSETS_NAME = "Heros"

export type Obtained = { InstanceId: string, HeroId: string, Name: string, New: boolean, Rarity: string }
type ObtainedCallback = (player: Player, obtained: Obtained) -> ()

local HeroService = {}

local changedEvent: RemoteEvent? = nil
local obtainedEvent: RemoteEvent? = nil
local obtainedCallbacks: { ObtainedCallback } = {}
local lastAction: { [Player]: number } = {}
local summoning: { [Player]: boolean } = {}
local summonEnabled = true
local random = Random.new()
-- Pool de tirage (tous les héros de HeroConfig, par rareté), construit au démarrage.
local pool: SummonRules.Pool = SummonRules.buildPool(RarityConfig.Tiers, HeroConfig.Heroes)

local idSequence = 0
-- Règles + config de progression, pour les vues envoyées au client (Level, XP, XPToNext, MaxLevel).
local PROGRESSION = { rules = HeroProgressionRules, config = HeroProgressionConfig }

-- Identifiant d'exemplaire unique, horodaté (largeur fixe) : KingdomService range les héros dans
-- l'ordre d'obtention (anciens "H_<GUID>" d'abord, puis "H_T…" par date) ; le premier héros reste sur Heros_1.
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
		event:FireClient(player, HeroRules.view(data, PROGRESSION))
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

export type RosterEntry = {
	Slot: number,
	HeroInstanceId: string,
	HeroId: string,
	CombatProfile: string,
	CombatTemplate: string,
	Level: number,
	Stats: { [string]: any },
}

-- Roster figé d'un combat : pour chaque case de la formation serveur (case -> HeroInstanceId), l'exemplaire
-- réellement possédé, son profil de combat et ses stats de niveau (copies). Refus si un exemplaire n'est
-- plus jouable. Le client ne fournit rien ici : la formation est celle d'ArenaService.
function HeroService:GetCombatRoster(player: Player, formation: { [number]: string }): ({ [number]: RosterEntry }?, string?)
	local data = DataService:GetData(player)
	if not data then
		return nil, "données non chargées"
	end
	local roster: { [number]: RosterEntry } = {}
	for slot, instanceId in formation do
		local hero, reason = HeroRules.combatHero(data, instanceId, HeroConfig.Heroes, CombatConfig.Heroes)
		if not hero then
			return nil, reason
		end
		local level = HeroProgressionRules.normalize(data.Heroes[instanceId], HeroProgressionConfig)
		roster[slot] = {
			Slot = slot,
			HeroInstanceId = instanceId,
			HeroId = hero.HeroId,
			CombatProfile = hero.CombatProfile,
			CombatTemplate = hero.CombatTemplate,
			Level = level,
			Stats = HeroProgressionRules.combatStats(CombatConfig.Heroes[hero.CombatProfile], level, HeroProgressionConfig),
		}
	end
	return roster, nil
end

export type ProgressionView = {
	InstanceId: string,
	HeroId: string,
	XPGranted: number,
	LevelBefore: number,
	LevelAfter: number,
	XP: number,
	XPToNext: number,
	MaxLevel: number,
}

-- XP d'une victoire acceptée par ZoneService (appelée une seule fois par CombatService.finalize) :
-- chaque exemplaire de `participants` (HeroInstanceId figés au lancement), encore possédé, gagne
-- l'XP du stage dans son mode (HeroProgressionConfig.StageXP, ou EliteStageXP en Élite). Sans yield ;
-- puis HeroesChanged. Renvoie la vue de progression pour l'écran de fin (le client ne calcule jamais de niveau).
function HeroService:GrantCombatXP(player: Player, participants: { string }, zone: number, stage: number, mode: string?): { ProgressionView }
	local data = DataService:GetData(player)
	local views: { ProgressionView } = {}
	if not data then
		return views
	end
	local amount = HeroProgressionRules.stageXP(zone, stage, HeroProgressionConfig, mode)
	local seen: { [string]: boolean } = {}
	for _, instanceId in participants do
		local hero = if typeof(instanceId) == "string" and not seen[instanceId] then data.Heroes[instanceId] else nil
		if hero then
			seen[instanceId] = true
			local grant = HeroProgressionRules.grantXP(hero, amount, HeroProgressionConfig)
			table.insert(views, {
				InstanceId = instanceId,
				HeroId = hero.HeroId,
				XPGranted = grant.XPGranted,
				LevelBefore = grant.LevelBefore,
				LevelAfter = grant.LevelAfter,
				XP = grant.XP,
				XPToNext = grant.XPToNext,
				MaxLevel = HeroProgressionConfig.MaxLevel,
			})
		end
	end
	if #views > 0 then
		Log.info(SCOPE, `{player.Name} : +{amount} XP à {#views} héros (stage {zone}-{stage}{if mode == "Elite" then " Élite" else ""})`)
		push(player)
	end
	return views
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

-- Le joueur est-il en état d'invoquer à SON portail (données, personnage vivant, distance) ?
-- Renvoie ses données, ou nil et la raison.
local function atPortal(player: Player): (any, string?)
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
	return data, nil
end

-- Le joueur peut-il invoquer maintenant ? Renvoie ses données, ou nil et la raison.
function HeroService:CanSummon(player: Player): (any, string?)
	local data, reason = atPortal(player)
	if not data then
		return nil, reason
	end
	if not SummonRules.canPay(data, SummonConfig) then
		return nil, "pas de ticket d'invocation"
	end
	return data, nil
end

-- Invocation tutorielle disponible pour ces données : quête du tutoriel active (pas encore terminée)
-- et héros de départ jamais obtenu. Renvoie false et la raison sinon.
local function starterOpen(player: Player, data: any): (boolean, string?)
	local starter = SummonConfig.Starter
	local quest = QuestService:GetActiveQuest(player)
	if not quest or quest.Id ~= starter.QuestId or quest.Completed then
		return false, "invocation gratuite indisponible"
	end
	return SummonRules.canStarter(data, starter)
end

-- Le joueur peut-il faire l'invocation tutorielle maintenant ? Renvoie ses données, ou nil et la raison.
function HeroService:CanStarterSummon(player: Player): (any, string?)
	local data, reason = atPortal(player)
	if not data then
		return nil, reason
	end
	local open, why = starterOpen(player, data)
	if not open then
		return nil, why
	end
	return data, nil
end

-- Après une invocation réussie (données déjà modifiées) : royaume, collection, annonce au joueur et callbacks.
local function announce(player: Player, result: SummonRules.Result, origin: string): Obtained
	local info = HeroConfig.Heroes[result.HeroId]
	local obtained: Obtained = {
		InstanceId = result.InstanceId,
		HeroId = result.HeroId,
		Name = if info then info.Name else result.HeroId,
		New = result.New,
		Rarity = if info then info.Rarity else RarityConfig.Tiers[1].Id,
	}
	Log.info(SCOPE, `{player.Name} invoque {result.HeroId} [{obtained.Rarity}] ({origin}, {result.InstanceId}, nouveau = {tostring(result.New)}, royaume = {tostring(result.KingdomChanged)})`)
	KingdomService:Refresh(player)
	push(player)
	local event = obtainedEvent
	if event and player.Parent == Players then
		event:FireClient(player, obtained)
	end
	for _, callback in obtainedCallbacks do
		task.spawn(callback, player, table.clone(obtained))
	end
	return obtained
end

-- Invocation autoritaire. Section critique synchrone (aucun yield) entre la vérification du ticket
-- et les mutations : deux demandes simultanées avec un seul ticket donnent une seule réussite.
-- bannerId : Id de SummonBannerConfig (nil = bannière par défaut) ; tout autre valeur est refusée.
function HeroService:RequestSummon(player: Player, bannerId: any?): (Obtained?, string?)
	local banner = if bannerId == nil then SummonBannerConfig.ById[SummonBannerConfig.Default]
		elseif typeof(bannerId) == "string" then SummonBannerConfig.ById[bannerId]
		else nil
	if not banner then
		return nil, "bannière inconnue"
	end
	local data, reason = HeroService:CanSummon(player)
	if not data then
		return nil, reason
	end
	summoning[player] = true
	local ok, result, why = pcall(SummonRules.summon, data, SummonConfig, newId, function(n: number): number
		return random:NextInteger(1, n)
	end, pool, banner)
	summoning[player] = nil
	if not ok then
		Log.warn(SCOPE, `Invocation de {player.Name} en échec : {tostring(result)}`)
		return nil, "invocation impossible"
	end
	if not result then
		return nil, why
	end
	return announce(player, result, banner.Id), nil
end

-- Invocation tutorielle (onboarding) : le héros de départ, gratuit, garanti, une seule fois.
-- Mêmes vérifications que RequestSummon (données, plot, SON portail, distance, invocation en cours),
-- plus la quête du tutoriel active et le héros de départ jamais obtenu. Section critique synchrone :
-- exemplaire créé (hotbar 1re case libre), sans ticket, sans Summons.Total, sans évolution du royaume ;
-- puis royaume, HeroesChanged, HeroObtained et enfin l'événement de quête (SummonConfig.Starter.Event).
function HeroService:RequestStarterSummon(player: Player): (Obtained?, string?)
	local data, reason = HeroService:CanStarterSummon(player)
	if not data then
		return nil, reason
	end
	summoning[player] = true
	local ok, result, why = pcall(SummonRules.starter, data, SummonConfig.Starter, newId)
	summoning[player] = nil
	if not ok then
		Log.warn(SCOPE, `Invocation tutorielle de {player.Name} en échec : {tostring(result)}`)
		return nil, "invocation impossible"
	end
	if not result then
		return nil, why
	end
	local obtained = announce(player, result, "tutoriel")
	QuestService:HandleGameplayEvent(player, SummonConfig.Starter.Event)
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
	local problems = SummonRules.configProblems(SummonConfig, HeroConfig.Heroes, RarityConfig.Tiers, SummonBannerConfig.Banners)
	for heroId, info in HeroConfig.Heroes do
		if not CombatConfig.Heroes[info.CombatProfile] then
			table.insert(problems, `{heroId} : profil de combat inconnu {info.CombatProfile}`)
		end
	end
	for _, problem in HeroProgressionRules.configProblems(HeroProgressionConfig) do
		Log.warn(SCOPE, `HeroProgressionConfig invalide : {problem}`)
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
		return if data then HeroRules.view(data, PROGRESSION) else nil
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
		return ok, reason, if data then HeroRules.view(data, PROGRESSION) else nil
	end
	edit.Parent = remotes
	-- Seul l'Id de bannière est lu (validé) : HeroId, rareté, coût et résultat sont décidés par le serveur.
	local summon = Instance.new("RemoteFunction")
	summon.Name = "RequestSummon"
	summon.OnServerInvoke = function(player: Player, bannerId: any): (boolean, any)
		local result, reason = HeroService:RequestSummon(player, bannerId)
		if result then
			return true, result
		end
		return false, reason
	end
	summon.Parent = remotes
	-- Invocation tutorielle : aucun argument lu, tout est décidé et revérifié ici.
	local starter = Instance.new("RemoteFunction")
	starter.Name = "RequestStarterSummon"
	starter.OnServerInvoke = function(player: Player): (boolean, any)
		local result, reason = HeroService:RequestStarterSummon(player)
		if result then
			return true, result
		end
		return false, reason
	end
	starter.Parent = remotes
	-- Lecture seule pour la fenêtre d'invocation : tickets du joueur et coût d'une invocation.
	local state = Instance.new("RemoteFunction")
	state.Name = "GetSummonState"
	state.OnServerInvoke = function(player: Player): any
		local data = loaded(player)
		if not data then
			return nil
		end
		local starter: any = { Active = false }
		if starterOpen(player, data) then
			local heroId = SummonConfig.Starter.HeroId
			local info = HeroConfig.Heroes[heroId]
			starter = { Active = true, HeroId = heroId, Name = info.Name, Rarity = info.Rarity }
		end
		return { Tickets = data.Currencies.SummonTickets, Cost = SummonConfig.Cost, Starter = starter }
	end
	state.Parent = remotes
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		summoning[player] = nil
	end)

	replicateHeroAssets()

	-- Aucun héros donné au join : un nouveau profil reste vide jusqu'à l'invocation tutorielle.
	DataService:OnPlayerReady(function(player: Player, data: any)
		HeroRules.normalizeHotbar(data, HeroConfig.HotbarSize)
		push(player)
	end)
end

return HeroService
