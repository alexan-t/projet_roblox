--!strict
-- Portail d'invocation du plot du joueur, côté client (voir docs/SUMMON.md).
--   • E près de SON portail (ProximityPrompt local sur le voile) : fenêtre « Invocation » avec les
--     bannières (SummonBannerConfig), leurs héros mis en avant (vrais modèles) et les chances par
--     rareté (RarityConfig).
--   • « Invoquer » : RequestSummon(bannerId). Le serveur décide tout (héros, rareté, ticket) ; le
--     client joue une cinématique (personnage caché, HUD masqué, caméra qui avance sur le portail
--     puis suit le héros jusqu'à sa place) avec l'effet selon la rareté (SummonEffectController),
--     puis montre la carte du héros (SummonView.Reveal). « Continuer » rend tout au joueur.
--   • Pas de spoil : la collection mise à jour (hotbar, sacoche) n'est montrée qu'à « Continuer »
--     (ArenaStore.holdHeroes / releaseHeroes).
--   • Invocation tutorielle (GetSummonState.Starter.Active, nouveau profil) : la même fenêtre avec la
--     bannière spéciale « Premier héros » (le héros décrit par le serveur, vrais modèles), les vraies
--     bannières grisées, sans taux, « Invoquer · Gratuit » ; puis RequestStarterSummon (aucun argument :
--     le serveur décide du héros). Même cinématique, même carte.
-- Refus du serveur (pas de ticket, trop loin…) : message bref (ArenaStore.toast).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
local SummonBannerConfig = require(ReplicatedStorage.Shared.Config.SummonBannerConfig)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local PlotView = require(script.Parent.Parent.Arena.PlotView)
local Icons = require(script.Parent.Parent.UI.Icons)
local RarityStyle = require(script.Parent.Parent.UI.RarityStyle)
local SummonView = require(script.Parent.Parent.UI.Views.SummonView)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local SummonEffectController = require(script.Parent.SummonEffectController)
local WorldPulse = require(script.Parent.Parent.UI.WorldPulse)

local SummonController = {}

local PORTAL_NAME = "PortailInvocation"
-- Le serveur accepte jusqu'à 18 studs (horizontal) du pivot du portail ; le prompt est sur le voile.
local PROMPT_DISTANCE = 14
local HOLD_ON_HERO = 0.7 -- s pour regarder le héros révélé avant sa carte (+0,1 s par rang de rareté)
local HINT_SECONDS = 8 -- s d'illumination du portail après un ticket gagné
local CAMERA_DISTANCE = 24 -- studs devant le voile : plan large de la cinématique
local CAMERA_SIDE = 8 -- studs de côté (plan de trois quarts)
local HIDE_STEP = "InvocationCachePersonnage"

local prompt: ProximityPrompt? = nil
local requestRemote: RemoteFunction? = nil
local starterRemote: RemoteFunction? = nil
local stateRemote: RemoteFunction? = nil
local busy = false -- fenêtre ouverte ou invocation en cours
local lastBanner: string? = nil
local presented: { [string]: boolean } = {} -- InstanceId déjà présentés (réponse + HeroObtained)

local function portalOf(): Model?
	local plot = PlotView.plot()
	local portal = plot and plot:FindFirstChild(PORTAL_NAME)
	return if portal and portal:IsA("Model") then portal else nil
end

-- Voile du portail (disque au centre de l'arche), sinon la première pièce du portail.
local function veilOf(portal: Model): BasePart?
	local structure = portal:FindFirstChild("Structure")
	local veil = if structure then structure:FindFirstChild("voile") else portal:FindFirstChild("voile", true)
	if veil and veil:IsA("BasePart") then
		return veil
	end
	return portal:FindFirstChildWhichIsA("BasePart", true)
end

local function refreshPrompt()
	local p = prompt
	if not p then
		return
	end
	local portal = portalOf()
	local veil = if portal then veilOf(portal) else nil
	if p.Parent ~= veil then
		p.Parent = veil
	end
	p.Enabled = veil ~= nil and not busy and ScreenState.free()
end

local function toast(text: string)
	ArenaStore.toast:Fire(text)
end

-- Bannières pour la vue : héros mis en avant du plus rare au moins rare, avec leur vrai modèle.
local function bannerViews(): { SummonView.BannerView }
	local views: { SummonView.BannerView } = {}
	for _, banner in SummonBannerConfig.Banners do
		local featured: { SummonView.FeaturedHero } = {}
		for _, heroId in banner.Featured do
			local info = HeroConfig.Heroes[heroId]
			if info then
				table.insert(featured, { Name = info.Name, Rarity = info.Rarity, Model = Icons.heroModel(heroId) })
			end
		end
		table.sort(featured, function(a, b)
			return RarityStyle.rank(a.Rarity) > RarityStyle.rank(b.Rarity)
		end)
		table.insert(views, { Id = banner.Id, Name = banner.Name, Subtitle = banner.Subtitle, Featured = featured })
	end
	return views
end

local function rates(): { SummonView.Rate }
	local list: { SummonView.Rate } = {}
	for _, tier in RarityConfig.Tiers do
		table.insert(list, { Id = tier.Id, Name = tier.Name, Percent = RarityConfig.percent(tier.Weight) })
	end
	return list
end

local function moveCamera(camera: Camera, eye: Vector3, target: Vector3, seconds: number, style: Enum.EasingStyle?)
	TweenService:Create(camera, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(eye, target),
	}):Play()
end

-- Cinématique d'invocation, locale au joueur. Le personnage est caché et immobilisé, le HUD masqué
-- (rien ne dévoile le héros avant sa carte) :
--   1. plan large sur le portail, qui avance lentement pendant la charge ;
--   2. à l'éclat, la caméra suit le héros jusqu'à sa place et le cadre en pied, face à lui.
-- Renvoie la fonction qui rend tout au joueur (caméra, personnage, HUD).
local function cinematic(portal: Model, template: Model, rarity: string?): () -> ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return function() end
	end
	local center, forward, landing = SummonEffectController.Layout(portal)
	local side = Vector3.yAxis:Cross(forward)
	local charge = SummonEffectController.Charge(rarity)
	local _, size = template:GetBoundingBox()
	local height = size.Y

	-- personnage caché (chaque image, après la caméra qui règle aussi la transparence) et immobile
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local walk, jump = if humanoid then humanoid.WalkSpeed else 16, if humanoid then humanoid.JumpHeight else 7.2
	if humanoid then
		humanoid.WalkSpeed, humanoid.JumpHeight = 0, 0
	end
	RunService:BindToRenderStep(HIDE_STEP, Enum.RenderPriority.Camera.Value + 1, function()
		if character then
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") then
					(part :: any).LocalTransparencyModifier = 1
				end
			end
		end
	end)
	-- HUD masqué (hotbar, pancartes, prompts) ; les écrans de l'invocation arrivent après
	local hidden: { ScreenGui } = {}
	for _, gui in Players.LocalPlayer.PlayerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled then
			gui.Enabled = false
			table.insert(hidden, gui)
		end
	end

	camera.CameraType = Enum.CameraType.Scriptable
	local wide = center + forward * CAMERA_DISTANCE + side * CAMERA_SIDE + Vector3.new(0, 4, 0)
	local near = center + forward * (CAMERA_DISTANCE * 0.7) + side * (CAMERA_SIDE * 0.5) + Vector3.new(0, 2, 0)
	moveCamera(camera, wide, center, 0.5)
	task.delay(0.5, function()
		moveCamera(camera, near, center - Vector3.new(0, 1, 0), math.max(charge - 0.5, 0.3), Enum.EasingStyle.Sine)
	end)
	task.delay(charge + 0.1, function()
		local focus = landing + Vector3.new(0, height * 0.55, 0)
		local eye = landing + forward * (height * 1.6 + 4) + side * 2.5 + Vector3.new(0, height * 0.65, 0)
		moveCamera(camera, eye, focus, 0.8)
	end)

	return function()
		RunService:UnbindFromRenderStep(HIDE_STEP)
		if character then
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") then
					(part :: any).LocalTransparencyModifier = 0
				end
			end
		end
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed, humanoid.JumpHeight = walk, jump
		end
		for _, gui in hidden do
			gui.Enabled = true
		end
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function finish()
	busy = false
	ScreenState.close("Summon")
	refreshPrompt()
end

-- Présente un héros obtenu : cinématique + effet du portail, puis sa carte quand l'effet a révélé le
-- héros (callback OnRevealed de l'effet, plus la pause pour le regarder). Appelée par la réponse de
-- RequestSummon ET par Remotes.HeroObtained : chaque exemplaire (InstanceId) n'est montré qu'une fois.
local function handleObtained(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.InstanceId) ~= "string" or presented[payload.InstanceId] then
		return
	end
	presented[payload.InstanceId] = true
	busy = true
	ScreenState.waitAndOpen("Summon") -- déjà ouvert si l'invocation vient de la fenêtre
	refreshPrompt()
	local rarity = if typeof(payload.Rarity) == "string" then payload.Rarity else nil
	local info = HeroConfig.Heroes[payload.HeroId]
	local template = Icons.heroModel(payload.HeroId) -- vrai modèle (ReplicatedStorage.Assets.Heros, HeroId)
	local portal = portalOf()
	local shown: Model? = nil
	local release: () -> () = function() end
	local function reveal()
		SummonView.Reveal({
			Name = if typeof(payload.Name) == "string" then payload.Name elseif info then info.Name else payload.HeroId,
			Model = template,
			ClassId = if info then info.CombatProfile else nil,
			New = payload.New,
			Rarity = rarity,
		}, {
			OnContinue = function()
				if shown then
					shown:Destroy()
				end
				release()
				ArenaStore.releaseHeroes() -- le héros apparaît dans la hotbar / la sacoche maintenant
				finish()
			end,
		})
	end
	if template and portal then
		release = cinematic(portal, template, rarity)
		shown = SummonEffectController.Play(portal, template, {
			Name = payload.Name,
			New = payload.New,
			Rarity = rarity,
			Keep = 0,
			OnRevealed = function()
				task.delay(HOLD_ON_HERO + RarityStyle.rank(rarity) * 0.1, reveal)
			end,
		})
	else
		reveal()
	end
end

-- free = invocation tutorielle (RequestStarterSummon, sans argument), sinon RequestSummon(bannerId).
local function summon(bannerId: string?, free: boolean?)
	local remote = if free then starterRemote else requestRemote
	if not remote then
		finish()
		return
	end
	lastBanner = bannerId
	-- La collection mise à jour (avec le héros) arrive avant la réponse : elle attend la carte.
	ArenaStore.holdHeroes()
	-- Seul l'Id de bannière part (choix d'interface, validé par le serveur) : ni HeroId, ni coût,
	-- ni ticket ne sont décidés ici. L'invocation tutorielle n'envoie rien du tout.
	local ok, accepted, result
	if free then
		ok, accepted, result = pcall(remote.InvokeServer, remote)
	else
		ok, accepted, result = pcall(remote.InvokeServer, remote, bannerId)
	end
	if not ok or accepted ~= true or typeof(result) ~= "table" then
		ArenaStore.releaseHeroes()
		toast(if ok and typeof(result) == "string" then result else "Invocation impossible, réessaie")
		finish()
		return
	end
	handleObtained(result) -- sans effet si HeroObtained l'a déjà présenté
end

-- Après un ticket gagné (écran de fin) : le portail du plot s'illumine un moment et une annonce
-- indique la suite. Rien n'est ouvert à la place du joueur.
function SummonController.HintPortal()
	local portal = portalOf()
	if not portal then
		return
	end
	-- même langage que le guidage du tutoriel : le portail respire (WorldPulse)
	local pulse = WorldPulse.start(portal, veilOf(portal))
	task.delay(HINT_SECONDS, pulse.stop)
	local screen = UIKit.screen("IndicationInvocation", 15)
	UIKit.announce(screen, "Nouveau ticket ! Invoque un héros au portail", { Color = UITheme.Colors.GoldLight, Hold = 3 })
	task.delay(5, function()
		screen:Destroy()
	end)
end

local function open()
	if busy or not ScreenState.open("Summon") then
		return
	end
	busy = true
	refreshPrompt()
	local remote = stateRemote
	local ok, response = false, nil
	if remote then
		ok, response = pcall(remote.InvokeServer, remote)
	end
	if not ok or typeof(response) ~= "table" then
		toast("Invocation indisponible, réessaie")
		finish()
		return
	end
	local state: any = response
	-- Invocation tutorielle : présentation seulement, le serveur revérifie tout et choisit le héros.
	local starter: any = if typeof(state.Starter) == "table" and state.Starter.Active == true then state.Starter else nil
	local free = starter ~= nil
	SummonView.Show({
		Tickets = state.Tickets,
		Cost = state.Cost,
		Banners = bannerViews(),
		Rates = rates(),
		Selected = lastBanner,
		Free = free,
		Starter = if starter then {
			Name = tostring(starter.Name),
			Rarity = tostring(starter.Rarity),
			Model = if typeof(starter.HeroId) == "string" then Icons.heroModel(starter.HeroId) else nil,
		} else nil,
	}, {
		OnSummon = function(bannerId: string?)
			task.spawn(summon, bannerId, free)
		end,
		OnClose = finish,
	})
end

function SummonController:Start()
	local p = Instance.new("ProximityPrompt")
	p.Name = "Invocation"
	p.ActionText = "Invoquer"
	p.ObjectText = "Portail"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = PROMPT_DISTANCE
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.Triggered:Connect(open)
	prompt = p

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild("RequestSummon", 30)
	local starter = remotes:WaitForChild("RequestStarterSummon", 30)
	if starter and starter:IsA("RemoteFunction") then
		starterRemote = starter
	end
	local state = remotes:WaitForChild("GetSummonState", 30)
	if request and request:IsA("RemoteFunction") then
		requestRemote = request
	end
	if state and state:IsA("RemoteFunction") then
		stateRemote = state
	end
	-- Le serveur envoie aussi HeroObtained : même traitement que la réponse, une seule présentation.
	local obtained = remotes:WaitForChild("HeroObtained", 30)
	if obtained and obtained:IsA("RemoteEvent") then
		obtained.OnClientEvent:Connect(function(payload: any)
			task.spawn(handleObtained, payload)
		end)
	end
	ScreenState.changed.Event:Connect(refreshPrompt)
	-- Le plot (et son portail) peut être attribué après le démarrage, et changer au respawn.
	Players.LocalPlayer.CharacterAdded:Connect(refreshPrompt)
	while true do
		refreshPrompt()
		task.wait(1)
	end
end

return SummonController
