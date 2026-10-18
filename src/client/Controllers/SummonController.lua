--!strict
-- Portail local, état serveur et présentation V2. Aucun RNG ni débit côté client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroConfig = require(ReplicatedStorage.Shared.Config.HeroConfig)
local SummonBannerConfig = require(ReplicatedStorage.Shared.Config.SummonBannerConfig)
local ArenaStore = require(script.Parent.Parent.Arena.ArenaStore)
local PlotView = require(script.Parent.Parent.Arena.PlotView)
local Icons = require(script.Parent.Parent.UI.Icons)
local SummonView = require(script.Parent.Parent.UI.Views.SummonView)
local ScreenState = require(script.Parent.Parent.UI.ScreenState)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local WorldPulse = require(script.Parent.Parent.UI.WorldPulse)

local SummonController = {}

local PORTAL_NAME = "PortailInvocation"
-- Le serveur accepte jusqu'à 18 studs (horizontal) du pivot du portail ; le prompt est sur le voile.
local PROMPT_DISTANCE = 14
local HINT_SECONDS = 8

local prompt: ProximityPrompt? = nil
local requestRemote: RemoteFunction? = nil
local starterRemote: RemoteFunction? = nil
local stateRemote: RemoteFunction? = nil
local busy = false -- fenêtre ouverte ou invocation en cours

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

-- L'état, les taux et les résultats viennent exclusivement du serveur.
local state: any = nil
local session = 0
local summon: (number) -> ()
local open: () -> ()
local function finish()
	session += 1
	SummonView.Hide()
	ArenaStore.releaseHeroes()
	busy = false
	ScreenState.close("Summon")
	refreshPrompt()
end
local function heroView(hero: any): any
	local copy = table.clone(hero)
	copy.Model = Icons.heroModel(hero.HeroId)
	return copy
end
local function bannerView(id: string): any
	local banner = SummonBannerConfig.ById[id]
	if not banner then return nil end
	local featured = {}
	for _,heroId in banner.Featured do
		local info = HeroConfig.Heroes[heroId]
		table.insert(featured, {HeroId=heroId,Name=info.Name,Rarity=info.Rarity,Model=Icons.heroModel(heroId)})
	end
	return {Id=id,Name=banner.Name,Subtitle=banner.Subtitle,Featured=featured}
end
local function present(batch: any, free: boolean)
	for i,hero in batch.Results do batch.Results[i] = heroView(hero) end
	SummonView.RevealBatch(batch,{
		OnContinue=finish,
		OnAgain=if free then nil else function()
			local token=session
			local remote=stateRemote
			if not remote then finish();return end
			local ok,fresh=pcall(remote.InvokeServer,remote)
			if token~=session or not busy then return end
			if not ok or typeof(fresh)~="table" then finish();return end
			state=fresh
			task.spawn(summon,batch.Quantity)
		end,
	})
end
summon = function(quantity: number)
	local token=session
	local snapshot=state
	if not snapshot then finish();return end
	local free=snapshot.Starter and snapshot.Starter.Active==true
	local remote=if free then starterRemote else requestRemote
	if not remote then finish();return end
	ArenaStore.holdHeroes()
	local ok,accepted,result
	if free then ok,accepted,result=pcall(remote.InvokeServer,remote)
	else
		ok,accepted,result=pcall(remote.InvokeServer,remote,{
			BannerId=snapshot.BannerId,Slot=snapshot.Slot,Quantity=quantity,ExpectedTotal=snapshot.ExpectedTotal,
		})
	end
	if token~=session then ArenaStore.releaseHeroes();return end
	if not ok or accepted~=true or typeof(result)~="table" then
		toast(if ok and typeof(result)=="string" then result else "Invocation impossible, rouvre le portail")
		finish();return
	end
	if free then result={Results={result},Quantity=1,Tickets=snapshot.Tickets} end
	present(result,free)
end
local refreshWindow: () -> ()
refreshWindow = function()
	local token=session
	local remote=stateRemote
	if not remote then finish();return end
	local ok,response=pcall(remote.InvokeServer,remote)
	if token~=session or not busy then return end
	if not ok or typeof(response)~="table" then toast("Invocation indisponible, réessaie");finish();return end
	state=response
	local data=table.clone(response)
	data.Banner=bannerView(response.BannerId)
	data.Free=response.Starter and response.Starter.Active==true
	if data.Free then data.Starter=heroView(response.Starter) end
	SummonView.Show(data,{
		OnSummon=function(quantity: number) task.spawn(summon,quantity) end,
		OnClose=finish,
		OnRefresh=function() task.spawn(refreshWindow) end,
	})
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

open = function()
	if busy or not ScreenState.open("Summon") then return end
	busy=true
	refreshPrompt()
	refreshWindow()
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
	-- HeroObtained reste destiné aux autres consommateurs ; la réponse est l'unique reveal.
	ScreenState.changed.Event:Connect(refreshPrompt)
	-- Le plot (et son portail) peut être attribué après le démarrage, et changer au respawn.
	Players.LocalPlayer.CharacterAdded:Connect(function() if busy then finish() else refreshPrompt() end end)
	while true do
		refreshPrompt()
		task.wait(1)
	end
end

return SummonController
