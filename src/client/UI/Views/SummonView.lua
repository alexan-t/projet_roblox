--!strict
-- Interface d'invocation et reveal du héros obtenu — issue #19, docs/UI_DESIGN_SYSTEM.md § 6.
-- Présentation seulement : HeroService (#10) décide du tirage et débite le ticket ; le contrôleur de
-- #11 appelle cette vue. L'effet 3D au portail est SummonEffectController (#17).
--   Interface : fenêtre « Invocation », gros ticket 3D, « Tickets : 3 », coût, bouton principal
--   « Invoquer » (désactivé sans ticket, avec une aide pour en gagner).
--   Reveal : voile, rayons dorés, la carte du héros se retourne (largeur 0 → pleine), portrait 3D
--   en pied, nom en Heading, badge « Nouveau » (premier exemplaire), bouton « Continuer ».
-- API : SummonView.Show(data, options) ; SummonView.Reveal(hero, options) ; SummonView.Hide().
--   Reveal cède la main le temps du retournement (≈ 0,3 s) : l'appeler dans un task.spawn au besoin.
--   data = { Tickets: number, Cost: number? (1 par défaut) }
--   options (Show) = { OnSummon: (() -> ())?, OnClose: (() -> ())? }
--   hero = { Name: string, Model: Model?, ClassId: string?, New: boolean? }
--   options (Reveal) = { OnContinue: (() -> ())? }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(script.Parent.Parent.Icons)
local UIKit = require(script.Parent.Parent.UIKit)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Spacing = UITheme.Spacing
local Animation = UITheme.Animation

local WINDOW = Vector2.new(440, 340)
local REVEAL_CARD = Vector2.new(260, 340)
local FLIP = 0.3 -- s : la carte se retourne

export type Data = { Tickets: number, Cost: number? }
export type ShowOptions = { OnSummon: (() -> ())?, OnClose: (() -> ())? }
export type Hero = { Name: string, Model: Model?, ClassId: string?, New: boolean? }
export type RevealOptions = { OnContinue: (() -> ())? }

local SummonView = {}

local current: { screen: ScreenGui, panel: GuiObject, veil: GuiObject }? = nil

function SummonView.Hide()
	local c = current
	if not c then
		return
	end
	current = nil
	UIKit.close(c.panel, c.veil, true, function()
		c.screen:Destroy()
	end)
end

function SummonView.Show(data: Data, options: ShowOptions?)
	SummonView.Hide()
	local opts: ShowOptions = options or {}
	local cost = data.Cost or 1
	local screen = UIKit.screen("Invocation", 10)
	local veil = UIKit.overlay(screen)
	local function close()
		SummonView.Hide()
		if opts.OnClose then
			opts.OnClose()
		end
	end
	veil.Activated:Connect(close)
	local panel, content = UIKit.panel(screen, { Size = WINDOW, Title = "Invocation", OnClose = close })
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	current = { screen = screen, panel = panel, veil = veil }

	local ticket = Instance.new("Frame")
	ticket.Name = "Ticket"
	ticket.BackgroundTransparency = 1
	ticket.AnchorPoint = Vector2.new(0.5, 0)
	ticket.Position = UDim2.new(0.5, 0, 0, Spacing.S)
	ticket.Size = UDim2.fromOffset(120, 100)
	ticket.Parent = content
	Icons.viewport(ticket, "Ticket")

	local enough = data.Tickets >= cost
	local count = UIKit.text(content, `Tickets : {data.Tickets}`, Typography.Size.Heading, { Color = if enough then Colors.TextLight else Colors.Warning })
	count.Position = UDim2.fromOffset(0, 112)
	count.Size = UDim2.new(1, 0, 0, 30)
	local price = UIKit.text(content, if cost > 1 then `Coût : {cost} tickets` else "Coût : 1 ticket", Typography.Size.Label, { Color = Colors.TextMuted })
	price.Position = UDim2.fromOffset(0, 144)
	price.Size = UDim2.new(1, 0, 0, 22)

	local summon = UIKit.button(content, {
		Text = "Invoquer",
		Style = if enough and opts.OnSummon then "Primary" else "Disabled",
		Size = Vector2.new(240, 56),
		OnClick = function()
			if enough and opts.OnSummon then
				local onSummon = opts.OnSummon
				SummonView.Hide()
				onSummon()
			end
		end,
	})
	summon.Holder.AnchorPoint = Vector2.new(0.5, 1)
	summon.Holder.Position = UDim2.new(0.5, 0, 1, -(if enough then 0 else 26))
	if not enough then
		local hint = UIKit.text(content, "Gagne des tickets en combattant", Typography.Size.Caption, { Color = Colors.TextMuted })
		hint.AnchorPoint = Vector2.new(0.5, 1)
		hint.Position = UDim2.fromScale(0.5, 1)
		hint.Size = UDim2.new(1, 0, 0, 20)
	end
	UIKit.open(panel, veil)
end

-- Reveal : à afficher quand l'effet 3D du portail a révélé le héros (≈ 2,3 s après l'invocation).
function SummonView.Reveal(hero: Hero, options: RevealOptions?)
	SummonView.Hide()
	local opts: RevealOptions = options or {}
	local screen = UIKit.screen("Revelation", 12)
	local veil = UIKit.overlay(screen)
	local root = Instance.new("Frame")
	root.Name = "Contenu"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(REVEAL_CARD.X + 200, REVEAL_CARD.Y + 160)
	root.Parent = screen
	current = { screen = screen, panel = root, veil = veil }
	UIKit.open(root, veil)

	local center = UDim2.new(0.5, 0, 0, REVEAL_CARD.Y / 2 + Spacing.L)
	local rays = UIKit.rays(root, REVEAL_CARD.Y * 0.85)
	rays.Position = center
	UIKit.popIn(rays, 0.05, 1)

	-- la carte se retourne : sa largeur passe de 0 à pleine, dos bois puis face crème
	local holder = Instance.new("Frame")
	holder.Name = "Carte"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = center
	holder.Size = UDim2.fromOffset(0, REVEAL_CARD.Y)
	holder.ClipsDescendants = false
	holder.Parent = root
	local back = Instance.new("Frame")
	back.Name = "Dos"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Colors.Wood
	back.Parent = holder
	UIKit.corner(back, UITheme.Radius.Medium)
	UIKit.stroke(back, UITheme.Stroke.Thick)
	local half = TweenInfo.new(FLIP / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UIKit.tween(holder, half, { Size = UDim2.fromOffset(REVEAL_CARD.X, REVEAL_CARD.Y) }).Completed:Wait()
	UIKit.tween(holder, half, { Size = UDim2.fromOffset(0, REVEAL_CARD.Y) }).Completed:Wait()
	back:Destroy()
	local card = UIKit.card(holder, { Size = REVEAL_CARD, Selected = true })
	card.Size = UDim2.fromScale(1, 1)
	local art = card:FindFirstChild("Illustration") :: Frame
	art.Size = UDim2.new(1, -2 * Spacing.S, 0.78, -Spacing.S)
	if hero.Model then
		UIKit.portrait(art, hero.Model, true)
	end
	if hero.ClassId then
		local chip = Instance.new("Frame")
		chip.BackgroundColor3 = Colors.Cream
		chip.AnchorPoint = Vector2.new(0, 1)
		chip.Position = UDim2.new(0, Spacing.S, 0.78, 0)
		chip.Size = UDim2.fromOffset(44, 44)
		chip.ZIndex = 3
		chip.Parent = card
		UIKit.corner(chip, UITheme.Radius.Pill)
		UIKit.stroke(chip, UITheme.Stroke.Thin)
		Icons.viewport(chip, hero.ClassId)
	end
	local name = UIKit.text(card, hero.Name, Typography.Size.Heading, { Color = Colors.InkSoft, Stroke = false })
	name.Position = UDim2.new(0, Spacing.S, 0.78, Spacing.XS)
	name.Size = UDim2.new(1, -2 * Spacing.S, 0.22, -Spacing.S)
	name.TextWrapped = true
	UIKit.tween(holder, TweenInfo.new(FLIP / 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(REVEAL_CARD.X, REVEAL_CARD.Y) })
	if hero.New ~= false then
		local badge = UIKit.badge(card, "Nouveau", Colors.RoyalRed)
		badge.Size = UDim2.fromOffset(120, 30)
		UIKit.popIn(badge, FLIP / 2 + 0.1)
	end

	local title = UIKit.text(root, "Nouveau héros !", Typography.Size.Title, { Color = Colors.GoldLight })
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, REVEAL_CARD.Y + Spacing.XL + Spacing.S)
	title.Size = UDim2.new(1, 0, 0, 40)
	UIKit.popIn(title, FLIP / 2)
	if hero.New == false then
		title.Text = "Héros obtenu !"
	end

	local continue = UIKit.button(root, {
		Text = "Continuer",
		Style = "Primary",
		Size = Vector2.new(220, 56),
		OnClick = function()
			SummonView.Hide()
			if opts.OnContinue then
				task.delay(Animation.Close.Time, opts.OnContinue)
			end
		end,
	})
	continue.Holder.AnchorPoint = Vector2.new(0.5, 1)
	continue.Holder.Position = UDim2.fromScale(0.5, 1)
	UIKit.popIn(continue.Holder, FLIP / 2 + 0.25, 1.06)
end

return SummonView
