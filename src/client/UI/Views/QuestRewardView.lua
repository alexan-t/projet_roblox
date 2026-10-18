--!strict
-- Révélation des récompenses de quête (« Récupérer ») — reproduit le reveal de la maquette « Quêtes HUD ».
-- Présentation seulement : QuestService a DÉJÀ ajouté les récompenses (ClaimQuest) ; cette vue montre
-- celles qu'il a renvoyées. Rien ici ne donne de monnaie.
--   1. voile sombre, rayons dorés qui tournent lentement ;
--   2. chaque récompense jaillit (pop, 0,08 s d'écart) : icône « Glow » du pack (CurrencyVisualConfig) et
--      montant « +150 » à la couleur de la monnaie ; « Récompense ! » ; « Toucher pour continuer » ;
--   3. toucher / clic / Entrée : les monnaies 3D (CurrencyFx) s'envolent vers leur compteur du HUD, qui
--      rebondit à chaque arrivée ; une pastille verte résume le gain (« +150 Or · +1 Ticket ») ;
--   4. onDone() quand les monnaies sont arrivées (le HUD relit alors le serveur et fait défiler les montants).
-- Styles : UITheme (Pack.Quest) et UIKit. API : QuestRewardView.Play(rewards, onDone?, sounds?).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyVisualConfig = require(ReplicatedStorage.Shared.Config.CurrencyVisualConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local CurrencyFx = require(script.Parent.Parent.CurrencyFx)
local UIKit = require(script.Parent.Parent.UIKit)
local CurrencyView = require(script.Parent.CurrencyView)

local Colors = UITheme.Colors
local Size = UITheme.Typography.Size
local PACK = UITheme.Pack.Quest

export type Reward = { Kind: string, Amount: number }

local ACTION = "ContinuerRecompenseQuete"
local POP = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local STAGGER = 0.08 -- s entre deux récompenses (maquette)
local TITLE_SIZE = 40
local AMOUNT_SIZE = 30

local QuestRewardView = {}

-- Nombre de modèles 3D qui volent pour un gain : quelques pièces, pas une pluie illisible.
local function flyCount(kind: string, amount: number): number
	if kind == "Gold" then
		return math.clamp(math.ceil(amount / 25), 3, 8)
	elseif kind == "Gems" then
		return math.clamp(math.ceil(amount / 5), 2, 6)
	end
	return math.clamp(amount, 1, 3)
end
QuestRewardView.flyCount = flyCount

local function pop(object: GuiObject, delay: number)
	local scale = object:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = object
	task.delay(delay, function()
		if scale.Parent then
			UIKit.tween(scale, POP, { Scale = 1 })
		end
	end)
end

-- Résumé du gain en pastille verte, en haut (maquette : toast).
local function toast(screen: ScreenGui, text: string)
	local pill = Instance.new("Frame")
	pill.Name = "Resume"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 72)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 40)
	pill.BackgroundColor3 = Colors.Success
	pill.ZIndex = 60
	pill.Parent = screen
	UIKit.corner(pill, UITheme.Radius.Pill)
	UIKit.stroke(pill, UITheme.Stroke.Regular)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, UITheme.Spacing.XL)
	padding.PaddingRight = UDim.new(0, UITheme.Spacing.XL)
	padding.Parent = pill
	local label = UIKit.text(pill, text, 20)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.ZIndex = 61
	pop(pill, 0)
	task.delay(PACK.Toast, function()
		if pill.Parent then
			UIKit.tween(pill, UITheme.Animation.Fade, { BackgroundTransparency = 1 })
			UIKit.tween(label, UITheme.Animation.Fade, { TextTransparency = 1 })
			task.wait(UITheme.Animation.Fade.Time)
			pill:Destroy()
		end
	end)
end

function QuestRewardView.Play(rewards: { Reward }, onDone: (() -> ())?, sounds: ((name: string) -> ())?)
	local play = sounds or function(_name: string) end
	if #rewards == 0 then
		if onDone then
			onDone()
		end
		return
	end
	local screen = UIKit.screen("RecompenseQuete", 55)
	local veil = UIKit.overlay(screen)
	UIKit.tween(veil, UITheme.Animation.Fade, { BackgroundTransparency = UITheme.Transparency.Overlay - 0.05 })

	local center = Instance.new("Frame")
	center.Name = "Reveal"
	center.BackgroundTransparency = 1
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.46)
	center.Size = UDim2.fromOffset(PACK.RevealRays, PACK.RevealGlow + 60)
	center.ZIndex = 10
	center.Parent = screen
	local rays = UIKit.rays(center, PACK.RevealRays / 2, 18, Colors.GoldLight)
	rays.Position = UDim2.fromScale(0.5, 0.42)
	rays.ZIndex = 9
	pop(rays, 0)

	-- 2. les récompenses jaillissent, côte à côte
	local row = Instance.new("Frame")
	row.Name = "Recompenses"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, PACK.RevealGlow + 40)
	row.ZIndex = 20
	row.Parent = center
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 28)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local glows: { { image: ImageLabel, reward: Reward } } = {}
	local parts: { string } = {}
	for index, reward in rewards do
		local visual = CurrencyVisualConfig.visual(reward.Kind)
		local item = Instance.new("Frame")
		item.Name = reward.Kind
		item.BackgroundTransparency = 1
		item.LayoutOrder = index
		item.Size = UDim2.fromOffset(PACK.RevealGlow, PACK.RevealGlow + 40)
		item.Parent = row
		local image = Instance.new("ImageLabel")
		image.Name = "Glow"
		image.BackgroundTransparency = 1
		image.Image = if visual then visual.Glow else ""
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.fromOffset(PACK.RevealGlow, PACK.RevealGlow)
		image.ZIndex = 21
		image.Parent = item
		local amount = UIKit.text(item, `+{CurrencyView.format(reward.Amount)}`, AMOUNT_SIZE, { Color = if visual then visual.Color else Colors.TextLight })
		amount.Name = "Montant"
		amount.Position = UDim2.fromOffset(0, PACK.RevealGlow)
		amount.Size = UDim2.new(1, 0, 0, 40)
		amount.ZIndex = 22
		pop(item, (index - 1) * STAGGER)
		table.insert(glows, { image = image, reward = reward })
		table.insert(parts, `+{CurrencyView.format(reward.Amount)} {if visual then visual.Label else reward.Kind}`)
	end
	play("Recompense")

	local title = UIKit.text(screen, "Récompense !", TITLE_SIZE, Colors.GoldLight)
	title.Name = "Titre"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.5, 0, 0.46, PACK.RevealGlow / 2 + 70)
	title.Size = UDim2.fromOffset(600, TITLE_SIZE + 12)
	title.ZIndex = 30
	pop(title, 0.1)
	local hint = UIKit.text(screen, "Toucher pour continuer", Size.Body, { Color = Colors.TextMuted, Font = UITheme.Typography.Body, Stroke = false })
	hint.Name = "Continuer"
	hint.AnchorPoint = Vector2.new(0.5, 0.5)
	hint.Position = UDim2.new(0.5, 0, 0.46, PACK.RevealGlow / 2 + 112)
	hint.Size = UDim2.fromOffset(600, 24)
	hint.ZIndex = 30

	-- 3. continuer : les monnaies 3D volent vers le HUD, puis tout s'efface
	local finished = false
	local function continue()
		if finished then
			return
		end
		finished = true
		ContextActionService:UnbindAction(ACTION)
		local longest = 0
		for _, entry in glows do
			local kind = entry.reward.Kind
			local duration = CurrencyFx.SpawnCurrencyReward(kind, entry.image, CurrencyView.IconOf(kind), {
				Count = flyCount(kind, entry.reward.Amount),
				OnArrive = function()
					CurrencyView.Bump(kind)
					play("Recompense")
				end,
			})
			longest = math.max(longest, duration)
		end
		toast(screen, table.concat(parts, " · "))
		for _, object in { title, hint } :: { TextLabel } do
			UIKit.tween(object, UITheme.Animation.Fade, { TextTransparency = 1 })
		end
		for _, entry in glows do
			UIKit.tween(entry.image, UITheme.Animation.Fade, { ImageTransparency = 1 })
		end
		row.Visible = false
		rays:Destroy()
		UIKit.tween(veil, UITheme.Animation.Fade, { BackgroundTransparency = 1 })
		veil.Active = false
		task.delay(longest, function()
			if onDone then
				onDone()
			end
		end)
		task.delay(math.max(longest, PACK.Toast) + 0.4, function()
			screen:Destroy()
		end)
	end
	veil.Activated:Connect(continue)
	ContextActionService:BindActionAtPriority(ACTION, function(_name, state)
		if state == Enum.UserInputState.Begin then
			continue()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Return, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

return QuestRewardView
