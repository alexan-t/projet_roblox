--!strict
-- Invocation V2 : reproduction du ZIP final (docs/references/ui/invocation-v2).
-- Aucun tirage ici : toutes les cartes et tous les taux proviennent de HeroService.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(RS.Shared.Config.UITheme)
local Rarity = require(script.Parent.Parent.RarityStyle)
local Guides = require(script.Parent.Parent.GuideTargets)
local L = require(script.Parent.SummonLayout)
local UIKit, Card, C = L.UIKit, L.Card, L.Colors
local View = {}
local current: any = nil
local generation = 0

function View.Hide()
	generation += 1
	if current then
		current.connection:Disconnect()
		current.screen:Destroy()
		current = nil
	end
	Guides.close("Summon")
	Guides.close("SummonBanners")
end

-- Le scale de fenêtre complète celui d'UIKit ; le layout mobile change la composition.
local function mount(name: string, render: (Frame, boolean) -> ())
	View.Hide()
	local screen = UIKit.screen(name,12)
	local veil = UIKit.overlay(screen)
	veil.BackgroundTransparency = if name == "Revelation" then .18 else Theme.Transparency.Overlay
	local root = L.frame(screen,0,0,1000,610)
	root.Name = "ContenuInvocation"
	root.AnchorPoint,root.Position = Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local lastMobile: boolean? = nil
	local function fit()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1920,1080)
		local mobile = size.Y < 500 or size.X < 900
		local w,h = if mobile then 820 else 1000, if mobile then 354 else 610
		local uiScale = screen:FindFirstChildOfClass("UIScale")
		local outer = if uiScale then uiScale.Scale else 1
		scale.Scale = math.min((size.X-32)/w,(size.Y-64)/h,1.25) / outer
		root.Size = UDim2.fromOffset(w,h)
		if mobile ~= lastMobile then
			lastMobile = mobile
			for _, child in root:GetChildren() do if child ~= scale then child:Destroy() end end
			render(root,mobile)
		end
	end
	local conn = RunService.RenderStepped:Connect(fit)
	current = {screen=screen,connection=conn,root=root,veil=veil}
	fit()
	return root,veil
end

function View.Show(data: any, options: any)
	local opts = options or {}
	local pending = false
	local function close() View.Hide(); if opts.OnClose then opts.OnClose() end end
	local clockLabel: TextLabel? = nil
	local progress: Frame? = nil
	local buttons = {}
	local root,veil = mount("Invocation",function(root, mobile)
		buttons = {}
		local w,h = if mobile then 820 else 1000, if mobile then 354 else 610
		local panel,content = UIKit.window(root,{Size=Vector2.new(w,h),Title="Invocation",OnClose=close})
		content.Position,content.Size = UDim2.fromOffset(if mobile then 10 else 20,if mobile then 10 else 34), UDim2.new(1,if mobile then -20 else -40,1,if mobile then -20 else -54)
		local bw,bh = if mobile then 540 else 960, if mobile then 334 else 430
		local banner = L.frame(content,0,0,bw,bh,C.RoyalRed)
		banner.Name = "Banniere"
		banner.ClipsDescendants = true
		local gradient=Instance.new("UIGradient")
		gradient.Color=ColorSequence.new(C.RoyalRed,C.WoodDeep)
		gradient.Rotation=90
		gradient.Parent=banner
		banner.BackgroundColor3=Color3.new(1,1,1)
		UIKit.corner(banner,UDim.new(0,14))
		-- Rideaux géométriques du prototype (aucune texture rideau livrée).
		for _, x in {0,12,32,bw-46,bw-26,bw-12} do
			local stripe = L.frame(banner,x,0,if x%2==0 then 8 else 14,bh,C.WoodDeep)
			stripe.BackgroundTransparency = .35
		end
		local floorH = if mobile then 46 else 64
		L.frame(banner,0,bh-floorH,bw,floorH,C.WoodDark)
		local raysSize = if mobile then 480 else 700
		local rays = L.image(banner,"rays",(bw-raysSize)/2,bh-raysSize+(if mobile then 118 else 180),raysSize,raysSize)
		rays.ImageColor3,rays.ImageTransparency = C.GoldLight,.65
		local portalSize = if mobile then 280 else 400
		L.image(banner,"portal",(bw-portalSize)/2,bh-portalSize+(if mobile then 18 else 30),portalSize,portalSize)
		local border = L.image(banner,"banner_frame",0,0,bw,bh)
		border.ScaleType = Enum.ScaleType.Slice
		-- L'image @2x est réduite par Roblox à 1024x580 : coordonnées proportionnelles.
		border.SliceCenter = Rect.new(102,102,922,478)
		border.SliceScale = .12
		border.ZIndex = 2
		local title = if data.Free then "PREMIER HÉROS" else string.upper(data.Banner.Name)
		local heading=L.text(banner,title,if mobile then 16 else 190,if mobile then 12 else 18,if mobile then 350 else 580,if mobile then 30 else 52,if mobile then 24 else 42,C.GoldLight)
		local subtitle=L.text(banner,if data.Free then "Ton premier défenseur rejoint ton royaume" else data.Banner.Subtitle,16,if mobile then 42 else 68,if mobile then 350 else bw-32,24,if mobile then 12 else 15)
		if mobile then heading.TextXAlignment=Enum.TextXAlignment.Left;subtitle.TextXAlignment=Enum.TextXAlignment.Left end
		local featured = if data.Free then {data.Starter} else data.Banner.Featured
		for i,hero in featured do
			local main = i==1
			local cw = if mobile then (if main then 138 else 96) else (if main then 196 else 140)
			local x = if main then (bw-cw)/2 elseif i==2 then bw/2-(if mobile then 214 else 300) else bw/2+(if mobile then 118 else 164)
			local bottom = if mobile then (if main then 34 else 26) else (if main then 40 else 34)
			local card = Card.new(banner,hero,cw)
			card.Position = UDim2.fromOffset(x,bh-bottom-cw*266/200)
			card.ZIndex = if main then 5 else 4
			if main and not data.Free then
				local badge = UIKit.badge(card,"    VEDETTE",C.GoldDeep)
				badge.AnchorPoint,badge.Position = Vector2.new(.5,1),UDim2.new(.5,0,0,-6)
				badge.ZIndex = 6
				local star=L.image(badge,"star",2,2,20,20)
				star.ZIndex=7
				L.ribbon(card,"ribbon_taux","TAUX AUGMENTÉ",-2,cw*266/200-5,cw+4)
			elseif not data.Free then
				local badge = UIKit.badge(card,Rarity.name(hero.Rarity).." · taux ↑",C.WoodDeep)
				badge.Position = UDim2.new(.5,0,1,8)
				badge.AnchorPoint = Vector2.new(.5,0)
			end
		end
		if not data.Free then
			local tw,th = if mobile then 148 else 196, if mobile then 76 else 88
			local timer = UIKit.panel(banner,0,UDim.new(0,10),3)
			timer.BackgroundColor3 = C.Cream
			timer.Position,timer.Size = UDim2.fromOffset(bw-tw-16,14),UDim2.fromOffset(tw,th)
			timer.ZIndex = 9
			L.image(timer,"hourglass",8,16,if mobile then 28 else 38,if mobile then 28 else 38)
			L.text(timer,"Nouvelle bannière dans",46,5,tw-54,32,if mobile then 11 else 14,C.WoodDark)
			clockLabel = L.text(timer,"",46,36,tw-54,30,if mobile then 20 else 26,C.Ink)
			progress = L.frame(timer,10,th-12,0,6,C.GoldDeep)
		end
		local controls = L.frame(content,if mobile then 550 else 0,if mobile then 0 else 446,if mobile then 250 else 960,if mobile then 334 else 110)
		controls.Name = "Commandes"
		local wallet = UIKit.panel(controls,.35,UDim.new(0,12),3)
		wallet.Size = UDim2.fromOffset(if mobile then 128 else 210,if mobile then 50 else 58)
		L.ticket(wallet,if mobile then -8 else -12,-5,if mobile then 50 else 64)
		L.text(wallet,tostring(data.Tickets),if mobile then 36 else 52,0,80,32,if mobile then 26 else 32)
		L.text(wallet,"Tickets",if mobile then 36 else 52,if mobile then 26 else 32,80,18,12,C.TextMuted)
		Guides.register("Summon.Tickets",wallet)
		if not data.Free then
			local rates = L.button(controls,"% TAUX",if mobile then 138 else 0,if mobile then 0 else 68,if mobile then 112 else 210,if mobile then 54 else 42,"Secondary",function() if not root:FindFirstChild("Taux") then L.rates(root,data,mobile) end end)
			rates.holder.Name = "OuvrirTaux"
			rates.label.TextSize = 18
		end
		if data.Guarantee and not data.Free then L.guarantee(if mobile then controls else banner,if mobile then 0 else 28,if mobile then 56 else 20,mobile) end
		for index,qty in {1,10,100} do
			if data.Free and qty~=1 then continue end
			local cw = if mobile then 250 elseif qty==1 then 160 else 196
			local ch = if mobile then (if qty==1 then 58 else 62) elseif qty==1 then 96 else 108
			local x = if mobile then 0 else ({376,550,760})[index]
			local y = if mobile then ({124,194,268})[index] else 110-ch
			local enough = data.Free or data.Tickets >= qty*data.Cost
			local button = L.button(controls,"",x,y,cw,ch,if qty==1 then "Secondary" elseif qty==10 then "Primary" else "Danger",function()
				if pending then return end
				pending = true
				for _,b in buttons do b.setEnabled(false) end
				if opts.OnSummon then opts.OnSummon(qty) end
			end)
			button.holder.Name = "Invoquer"..qty
			button.setEnabled(enough)
			table.insert(buttons,button)
			L.text(button.face,if data.Free then "GRATUIT" else "×"..qty,if mobile then 8 else 0,if mobile then 4 else 4,if mobile then 120 else cw,if mobile then 42 else 58,if mobile then 30 else 42)
			L.ticket(button.face,if mobile then 170 else cw/2-26,if mobile then 14 else 62,24)
			L.text(button.face,if data.Free then "0" elseif enough then tostring(qty*data.Cost) else "Manque "..(qty*data.Cost-data.Tickets),if mobile then 195 else cw/2,if mobile then 12 else 62,if enough then 46 else 88,26,if enough then 18 else 12,if enough then C.TextLight else C.TicketLight)
			if qty==100 and enough and not data.Free then
				local ring = UIKit.stroke(button.face,2,C.GoldLight)
				ring.Transparency = .1
				L.image(button.face,"sparkle",8,8,16,16)
				L.image(button.face,"sparkle",cw-26,ch-32,12,12)
			end
			if qty==1 then Guides.register("Summon.Invoke",button.holder) end
		end
		Guides.register("Summon.Banners",banner)
	end)
	veil.Activated:Connect(close)
	Guides.open(if data.Free then "Summon" else "SummonBanners")
	local token = generation
	task.spawn(function()
		while current and generation==token do
			local remaining = math.max(0,math.ceil((data.EndsAt or 0)-workspace:GetServerTimeNow()))
			if clockLabel and clockLabel.Parent then
				clockLabel.Text = string.format("%d:%02d",math.floor(remaining/60),remaining%60)
				clockLabel.TextColor3 = if remaining<60 then C.RoyalRed else C.Ink
			end
			if progress and progress.Parent then
				local ratio = math.clamp(1-remaining/900,0,1)
				progress.Size = UDim2.new(ratio,-20*ratio,0,6)
			end
			if remaining==0 and not data.Free and not pending then
				pending=true
				for _,b in buttons do b.setEnabled(false) end
				if opts.OnRefresh then opts.OnRefresh() end
				break
			end
			task.wait(.25)
		end
	end)
end

function View.RevealBatch(batch: any, options: any)
	local Reveal = require(script.Parent.SummonReveal)
	Reveal.show(batch,options,mount,View.Hide)
end
function View.Reveal(hero: any, options: any)
	local shown=table.clone(hero)
	shown.Rarity=shown.Rarity or "Commun"
	shown.HeroId=shown.HeroId or shown.Name
	View.RevealBatch({Results={shown},Quantity=1,Tickets=0},options)
end
return View
