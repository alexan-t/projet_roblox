--!strict
-- Portail d'invocation du plot du joueur, côté client (voir docs/SUMMON.md).
--   • E près de SON portail (ProximityPrompt local sur le voile) : fenêtre « Invocation » avec les
--     bannières (SummonBannerConfig), leurs héros mis en avant (vrais modèles) et les chances par
--     rareté (RarityConfig).
--   • « Invoquer » : RequestSummon(bannerId). Le serveur décide tout (héros, rareté, ticket) ; le
--     client joue l'effet du portail selon la rareté (SummonEffectController), puis montre la carte du
--     héros (SummonView.Reveal). Pendant ce temps la caméra cadre le portail ; le héros invoqué reste
--     devant le portail et la caméra revient au joueur à « Continuer ».
-- Refus du serveur (pas de ticket, trop loin…) : message bref (ArenaStore.toast).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local SummonEffectController = require(script.Parent.SummonEffectController)

local SummonController = {}

local PORTAL_NAME = "PortailInvocation"
-- Le serveur accepte jusqu'à 18 studs (horizontal) du pivot du portail ; le prompt est sur le voile.
local PROMPT_DISTANCE = 14
local REVEAL_PAUSE = 0.9 -- s entre l'atterrissage du héros et sa carte
local CAMERA_DISTANCE = 22 -- studs devant le voile : plan fixe pendant l'invocation
local CAMERA_SIDE = 11 -- studs de côté : le joueur, posté face au portail, ne cache pas le héros

local prompt: ProximityPrompt? = nil
local requestRemote: RemoteFunction? = nil
local stateRemote: RemoteFunction? = nil
local busy = false -- fenêtre ouverte ou invocation en cours
local lastBanner: string? = nil

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
	p.Enabled = veil ~= nil and not busy
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

-- Plan fixe face au portail pendant l'invocation (le héros se pose devant le voile, vers la caméra) ;
-- renvoie la fonction qui rend la caméra au joueur.
local function frameCamera(portal: Model): () -> ()
	local camera = Workspace.CurrentCamera
	local veil = veilOf(portal)
	if not camera or not veil then
		return function() end
	end
	local forward = veil.CFrame.LookVector * Vector3.new(1, 0, 1)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.zAxis
	local side = Vector3.yAxis:Cross(forward)
	local target = veil.Position + forward * 5 - Vector3.new(0, 2.5, 0)
	local eye = veil.Position + forward * CAMERA_DISTANCE + side * CAMERA_SIDE + Vector3.new(0, 2, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(eye, target),
	}):Play()
	return function()
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function finish()
	busy = false
	refreshPrompt()
end

local function summon(bannerId: string?)
	local remote = requestRemote
	if not remote then
		finish()
		return
	end
	lastBanner = bannerId
	local ok, accepted, result = pcall(remote.InvokeServer, remote, bannerId)
	if not ok or accepted ~= true or typeof(result) ~= "table" then
		toast(if ok and typeof(result) == "string" then result else "Invocation impossible, réessaie")
		finish()
		return
	end
	local rarity = if typeof(result.Rarity) == "string" then result.Rarity else nil
	local template = Icons.heroModel(result.HeroId)
	local portal = portalOf()
	local shown: Model? = nil
	local release: () -> () = function() end
	if template and portal then
		release = frameCamera(portal)
		shown = SummonEffectController.Play(portal, template, { Name = result.Name, New = result.New, Rarity = rarity, Keep = 0 })
		task.wait(SummonEffectController.Duration(rarity) + REVEAL_PAUSE + RarityStyle.rank(rarity) * 0.1)
	end
	SummonView.Reveal({ Name = result.Name, Model = template, New = result.New, Rarity = rarity }, {
		OnContinue = function()
			if shown then
				shown:Destroy()
			end
			release()
			finish()
		end,
	})
end

local function open()
	if busy then
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
	SummonView.Show({
		Tickets = state.Tickets,
		Cost = state.Cost,
		Banners = bannerViews(),
		Rates = rates(),
		Selected = lastBanner,
	}, {
		OnSummon = function(bannerId: string?)
			task.spawn(summon, bannerId)
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
	local state = remotes:WaitForChild("GetSummonState", 30)
	if request and request:IsA("RemoteFunction") then
		requestRemote = request
	end
	if state and state:IsA("RemoteFunction") then
		stateRemote = state
	end
	-- Le plot (et son portail) peut être attribué après le démarrage, et changer au respawn.
	Players.LocalPlayer.CharacterAdded:Connect(refreshPrompt)
	while true do
		refreshPrompt()
		task.wait(1)
	end
end

return SummonController
