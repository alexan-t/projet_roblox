--!strict
-- Révélation des récompenses de quête (« Récupérer ») : un moment court, unique et très visible.
-- Présentation seulement : QuestService a déjà ajouté les récompenses (ClaimQuest) ; cette vue montre
-- celles qu'il a renvoyées, puis les fait voler jusqu'au compteur du HUD des monnaies.
--   1. voile + « QUÊTE ACCOMPLIE ! » qui jaillit, rayons dorés qui tournent ;
--   2. chaque carte tombe du haut, rebondit, tremble, éclate (flash + confettis aux couleurs de la map) ;
--   3. elle se retourne et révèle l'objet (icône 3D, « x1 », nom), étoiles qui scintillent ;
--   4. « Récupérer ! » (clic / toucher / Entrée) : la carte file vers son compteur du HUD, qui s'anime.
-- Styles : UITheme et UIKit uniquement. API : QuestRewardView.Play(rewards, onDone?).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(script.Parent.Parent.Icons)
local UIKit = require(script.Parent.Parent.UIKit)

local Colors = UITheme.Colors
local Size = UITheme.Typography.Size
local Animation = UITheme.Animation

export type Reward = { Kind: string, Amount: number }

local KINDS: { [string]: { Icon: string, Label: string, Color: Color3, Hud: string } } = {
	Gold = { Icon = "Or", Label = "Or", Color = Colors.CurrencyGold, Hud = "Gold" },
	Gems = { Icon = "Gemmes", Label = "Gemmes", Color = Colors.CurrencyGems, Hud = "Gems" },
	SummonTicket = { Icon = "Ticket", Label = "Ticket d'invocation", Color = Colors.CurrencyTickets, Hud = "SummonTickets" },
}

-- Couleurs des confettis : matières et accents de la map (design system).
local CONFETTI = { Colors.Gold, Colors.GoldLight, Colors.RoyalRed, Colors.RoyalBlue, Colors.Grass, Colors.Crystal, Colors.Cream }

local CARD = Vector2.new(200, 250)
local ACTION = "RecupererRecompenseQuete"

local QuestRewardView = {}

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function scaleOf(object: GuiObject): UIScale
	local scale = object:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = object
	return scale
end

-- Confettis : petits rectangles qui jaillissent, tournent, retombent et s'effacent (nettoyés ensuite).
local function confetti(parent: GuiObject, count: number)
	local random = Random.new()
	for i = 1, count do
		local bit = Instance.new("Frame")
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		bit.Position = UDim2.fromScale(0.5, 0.5)
		bit.Size = UDim2.fromOffset(random:NextInteger(10, 18), random:NextInteger(6, 10))
		bit.BackgroundColor3 = CONFETTI[(i - 1) % #CONFETTI + 1]
		bit.BorderSizePixel = 0
		bit.Rotation = random:NextNumber(0, 360)
		bit.ZIndex = 30
		bit.Parent = parent
		UIKit.corner(bit, UITheme.Radius.Pill)
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(160, 380)
		local out = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance - 90)
		local fall = UDim2.new(0.5, math.cos(angle) * distance * 1.15, 0.5, math.sin(angle) * distance + random:NextNumber(140, 260))
		tween(bit, 0.45, { Position = out, Rotation = bit.Rotation + random:NextNumber(-360, 360) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.45, function()
			if bit.Parent then
				tween(bit, 0.9, { Position = fall, BackgroundTransparency = 1, Rotation = bit.Rotation + random:NextNumber(-540, 540) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
		task.delay(1.5, function()
			bit:Destroy()
		end)
	end
end

-- Étoiles dorées qui scintillent autour de la carte révélée.
local function twinkles(parent: GuiObject, count: number): { Tween }
	local tweens = {}
	local random = Random.new()
	for i = 1, count do
		local star = Instance.new("Frame")
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		local angle = (i / count) * math.pi * 2 + random:NextNumber(-0.3, 0.3)
		star.Position = UDim2.new(0.5, math.cos(angle) * random:NextNumber(130, 170), 0.5, math.sin(angle) * random:NextNumber(150, 190))
		star.Size = UDim2.fromOffset(14, 14)
		star.Rotation = 45
		star.BackgroundColor3 = Colors.GoldLight
		star.BorderSizePixel = 0
		star.BackgroundTransparency = 1
		star.ZIndex = 25
		star.Parent = parent
		UIKit.stroke(star, UITheme.Stroke.Thin)
		local t = TweenService:Create(star, TweenInfo.new(0.5 + random:NextNumber(0, 0.4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, random:NextNumber(0, 0.6)),
			{ BackgroundTransparency = 0, Size = UDim2.fromOffset(20, 20) })
		t:Play()
		table.insert(tweens, t)
	end
	return tweens
end

-- Carte face cachée (« ? » doré), qui tombe, rebondit, tremble, éclate puis se retourne.
local function card(parent: Instance, reward: Reward, x: number): (Frame, () -> ())
	local info = KINDS[reward.Kind] or KINDS.Gold
	local holder = Instance.new("Frame")
	holder.Name = "Carte_" .. reward.Kind
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	holder.Position = UDim2.new(0.5, x, -0.4, 0)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 20
	holder.Parent = parent

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Colors.WoodDeep
	face.ZIndex = 21
	face.Parent = holder
	UIKit.corner(face, UITheme.Radius.Large)
	UIKit.stroke(face, UITheme.Stroke.Thick, Colors.Gold)
	local mystery = UIKit.text(face, "?", 96, Colors.Gold)
	mystery.ZIndex = 22

	-- révélation : fond crème, icône 3D, quantité, nom
	local function reveal()
		mystery:Destroy()
		face.BackgroundColor3 = Colors.Cream
		local ring = face:FindFirstChildOfClass("UIStroke")
		if ring then
			ring.Color = info.Color
		end
		local art = Instance.new("Frame")
		art.BackgroundTransparency = 1
		art.Position = UDim2.fromScale(0.1, 0.06)
		art.Size = UDim2.fromScale(0.8, 0.56)
		art.ZIndex = 22
		art.Parent = face
		Icons.viewport(art, info.Icon)
		local amount = UIKit.text(face, `x{reward.Amount}`, Size.Hero, info.Color)
		amount.Position = UDim2.fromScale(0, 0.58)
		amount.Size = UDim2.fromScale(1, 0.22)
		amount.ZIndex = 23
		local name = UIKit.text(face, info.Label, Size.Label, { Color = Colors.InkSoft, Stroke = false })
		name.Position = UDim2.fromScale(0, 0.8)
		name.Size = UDim2.fromScale(1, 0.14)
		name.ZIndex = 23
		UIKit.pop(amount)
	end
	return holder, reveal
end

local function hudTarget(kind: string): GuiObject?
	local info = KINDS[kind]
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not info or not gui then
		return nil
	end
	for _, item in gui:GetDescendants() do
		if item:IsA("GuiObject") and item.Name == info.Hud and item.Parent and item.Parent.Name == "Monnaies" then
			return item
		end
	end
	return nil
end

-- Joue la révélation. onDone est appelé une fois la dernière carte arrivée dans le HUD.
function QuestRewardView.Play(rewards: { Reward }, onDone: (() -> ())?, sounds: ((name: string) -> ())?)
	local play = sounds or function(_name: string) end
	if #rewards == 0 then
		if onDone then
			onDone()
		end
		return
	end
	local screen = UIKit.screen("RecompenseQuete", 30)
	local scale = screen:FindFirstChildOfClass("UIScale")
	local veil = UIKit.overlay(screen)
	tween(veil, 0.25, { BackgroundTransparency = UITheme.Transparency.Overlay })

	-- 1. titre + rayons
	local center = Instance.new("Frame")
	center.BackgroundTransparency = 1
	center.Size = UDim2.fromScale(1, 1)
	center.ZIndex = 10
	center.Parent = screen
	local rays = UIKit.rays(center, 420, 14, Colors.GoldLight)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.ZIndex = 11
	scaleOf(rays).Scale = 0
	tween(scaleOf(rays), 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local title = UIKit.text(center, "QUÊTE ACCOMPLIE !", Size.Hero, Colors.Gold)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.16)
	title.Size = UDim2.fromOffset(900, Size.Hero + 20)
	title.ZIndex = 40
	local titleScale = scaleOf(title)
	titleScale.Scale = 0
	tween(titleScale, 0.35, { Scale = 1.15 }, Enum.EasingStyle.Back)
	task.delay(0.35, function()
		tween(titleScale, 0.2, { Scale = 1 })
	end)
	title.Rotation = -6
	tween(title, 0.5, { Rotation = 0 }, Enum.EasingStyle.Elastic)
	play("Victoire")

	-- 2. cartes : chute, rebond, tremblement, éclat, retournement
	local spacing = CARD.X + 40
	local cards: { { holder: Frame, kind: string } } = {}
	local stars: { Tween } = {}
	for index, reward in rewards do
		local x = (index - (#rewards + 1) / 2) * spacing
		local holder, reveal = card(center, reward, x)
		table.insert(cards, { holder = holder, kind = reward.Kind })
		local start = 0.35 + (index - 1) * 0.45
		task.delay(start, function()
			tween(holder, 0.55, { Position = UDim2.new(0.5, x, 0.55, 0) }, Enum.EasingStyle.Bounce)
			play("Impact")
			task.wait(0.6)
			-- tremblement : quelque chose est dedans !
			for i = 1, 4 do
				tween(holder, 0.06, { Rotation = if i % 2 == 0 then 8 else -8 })
				task.wait(0.07)
			end
			tween(holder, 0.06, { Rotation = 0 })
			task.wait(0.1)
			-- éclat : flash, confettis, retournement
			local flash = Instance.new("Frame")
			flash.AnchorPoint = Vector2.new(0.5, 0.5)
			flash.Position = UDim2.fromScale(0.5, 0.5)
			flash.Size = UDim2.fromScale(1.4, 1.4)
			flash.BackgroundColor3 = Colors.TextLight
			flash.BackgroundTransparency = 0.1
			flash.ZIndex = 29
			flash.Parent = holder
			UIKit.corner(flash, UITheme.Radius.Pill)
			tween(flash, 0.35, { BackgroundTransparency = 1, Size = UDim2.fromScale(2.4, 2.4) })
			task.delay(0.4, function()
				flash:Destroy()
			end)
			confetti(holder, 28)
			play("InvocationEclat")
			local holderScale = scaleOf(holder)
			tween(holderScale, 0.12, { Scale = 1.18 })
			-- retournement : la carte s'amincit, change de face, revient
			tween(holder, 0.14, { Size = UDim2.fromOffset(4, CARD.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.15)
			reveal()
			tween(holder, 0.2, { Size = UDim2.fromOffset(CARD.X, CARD.Y) }, Enum.EasingStyle.Back)
			tween(holderScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			play("Revelation")
			for _, t in twinkles(holder, 8) do
				table.insert(stars, t)
			end
		end)
	end

	-- 3. « Récupérer ! » une fois toutes les cartes révélées
	local revealDone = 0.35 + (#rewards - 1) * 0.45 + 1.55
	local finished = false
	local button: UIKit.Button? = nil
	local function collect()
		if finished then
			return
		end
		finished = true
		ContextActionService:UnbindAction(ACTION)
		if button then
			button.holder:Destroy()
		end
		for _, t in stars do
			t:Cancel()
		end
		local s = if scale then scale.Scale else 1
		local arrivals = 0
		for index, entry in cards do
			task.delay((index - 1) * 0.12, function()
				local target = hudTarget(entry.kind)
				local goal = UDim2.fromScale(0.5, 0.05)
				if target then
					local p = target.AbsolutePosition + target.AbsoluteSize / 2
					goal = UDim2.fromOffset(p.X / s, p.Y / s)
				end
				-- la carte rapetisse et file vers son compteur
				entry.holder.AnchorPoint = Vector2.new(0.5, 0.5)
				tween(entry.holder, 0.55, { Position = goal, Rotation = 20 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				tween(scaleOf(entry.holder), 0.55, { Scale = 0.15 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.wait(0.56)
				play("Recompense")
				if target then
					UIKit.pop(target)
				end
				entry.holder:Destroy()
				arrivals += 1
				if arrivals == #cards then
					tween(veil, 0.25, { BackgroundTransparency = 1 })
					tween(title, 0.25, { TextTransparency = 1 })
					tween(scaleOf(rays), 0.25, { Scale = 0 })
					task.delay(0.3, function()
						screen:Destroy()
					end)
					if onDone then
						onDone()
					end
				end
			end)
		end
	end
	task.delay(revealDone, function()
		if finished then
			return
		end
		local b = UIKit.button(center, "Récupérer !", "Primary", UDim2.fromOffset(260, 56 + UITheme.Shadow.ButtonLip), collect)
		b.holder.AnchorPoint = Vector2.new(0.5, 0.5)
		b.holder.Position = UDim2.fromScale(0.5, 0.77) -- sous la carte, au-dessus de la hotbar
		b.holder.ZIndex = 40
		b.label.TextSize = Size.Button
		UIKit.popIn(b.holder, 0, Animation.Scale.Pop)
		-- le bouton respire : on a envie de cliquer
		task.delay(0.4, function()
			if b.holder.Parent then
				TweenService:Create(scaleOf(b.holder), Animation.Pulse, { Scale = Animation.Scale.Hover + 0.04 }):Play()
			end
		end)
		button = b
		ContextActionService:BindActionAtPriority(ACTION, function(_name, state)
			if state == Enum.UserInputState.Begin then
				collect()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Return, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	end)
	veil.Activated:Connect(function()
		if button then
			collect() -- toucher n'importe où une fois le bouton là
		end
	end)
end

return QuestRewardView
