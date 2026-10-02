--!strict
-- Collection basique des héros possédés — issue #19, docs/UI_DESIGN_SYSTEM.md § 6 Cartes.
-- Présentation seulement : la liste vient de PlayerData.Heroes / Team (serveur) et du catalogue de
-- HeroService (#10) ; le contrôleur de #11 appelle cette vue.
--   Fenêtre « Collection », compteur de héros, grille de cartes standard (portrait 3D, nom), en
--   cascade. Badges : « Nouveau » (RoyalRed) ou « Équipé » (Gold + contour Selected). Plusieurs
--   exemplaires : « ×2 » en bas à droite. Collection vide : invitation à invoquer au portail.
--   Cadre neutre : pas de couleur de rareté tant que #10 ne l'a pas définie.
-- API : CollectionView.Show(heroes, options?) ; CollectionView.Hide().
--   heroes = { { Name: string, Model: Model?, ClassId: string?, Count: number?, New: boolean?, Equipped: boolean? } }
--   options = { OnClose: (() -> ())?, OnSelect: ((index: number) -> ())? }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local Icons = require(script.Parent.Parent.Icons)
local UIKit = require(script.Parent.Parent.UIKit)

local Colors = UITheme.Colors
local Typography = UITheme.Typography
local Spacing = UITheme.Spacing

local WINDOW = Vector2.new(820, 560)
local CARD = Vector2.new(132, 168)

export type HeroEntry = { Name: string, Model: Model?, ClassId: string?, Count: number?, New: boolean?, Equipped: boolean? }
export type Options = { OnClose: (() -> ())?, OnSelect: ((index: number) -> ())? }

local CollectionView = {}

local current: { screen: ScreenGui, panel: Frame, veil: GuiObject }? = nil

function CollectionView.Hide()
	local c = current
	if not c then
		return
	end
	current = nil
	UIKit.close(c.panel, c.veil, true, function()
		c.screen:Destroy()
	end)
end

function CollectionView.Show(heroes: { HeroEntry }, options: Options?)
	CollectionView.Hide()
	local opts: Options = options or {}
	local screen = UIKit.screen("Collection", 10)
	local veil = UIKit.overlay(screen)
	local function close()
		CollectionView.Hide()
		if opts.OnClose then
			opts.OnClose()
		end
	end
	veil.Activated:Connect(close)
	local panel, content = UIKit.panel(screen, { Size = WINDOW, Title = "Collection", OnClose = close })
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	current = { screen = screen, panel = panel, veil = veil }

	local total = 0
	for _, hero in heroes do
		total += hero.Count or 1
	end
	local header = UIKit.text(content, `{total} héros`, Typography.Size.Label, { Align = Enum.TextXAlignment.Left, Color = Colors.TextMuted })
	header.Position = UDim2.fromOffset(Spacing.S, Spacing.S)
	header.Size = UDim2.new(1, 0, 0, 24)

	if #heroes == 0 then
		local empty = UIKit.subPanel(content, UDim2.new(1, -2 * Spacing.XL, 0, 80))
		empty.AnchorPoint = Vector2.new(0.5, 0.5)
		empty.Position = UDim2.fromScale(0.5, 0.5)
		local text = UIKit.text(empty, "Aucun héros pour l'instant : invoque-en un au portail !", Typography.Size.Label)
		text.TextWrapped = true
		UIKit.open(panel, veil)
		return
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grille"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, 44)
	scroll.Size = UDim2.new(1, 0, 1, -44)
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Colors.WoodLight
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = content
	local padding = Instance.new("UIPadding")
	-- de la place au-dessus des cartes pour les badges à cheval sur le bord haut
	padding.PaddingTop = UDim.new(0, Spacing.L)
	padding.PaddingLeft = UDim.new(0, Spacing.S)
	padding.PaddingBottom = UDim.new(0, Spacing.L)
	padding.Parent = scroll
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(CARD.X, CARD.Y)
	grid.CellPadding = UDim2.fromOffset(Spacing.L, Spacing.XL)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	for index, hero in heroes do
		local holder = Instance.new("Frame")
		holder.Name = hero.Name
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = index
		holder.Parent = scroll
		local badge = if hero.New then "Nouveau" elseif hero.Equipped then "Équipé" else nil
		local card = UIKit.card(holder, {
			Size = CARD,
			Name = hero.Name,
			Model = hero.Model,
			Badge = badge,
			BadgeColor = if hero.New then Colors.RoyalRed else Colors.Gold,
			Selected = hero.Equipped,
		})
		if hero.ClassId then
			local chip = Instance.new("Frame")
			chip.BackgroundColor3 = Colors.Cream
			chip.AnchorPoint = Vector2.new(0, 1)
			chip.Position = UDim2.new(0, Spacing.S, 0.66, 0)
			chip.Size = UDim2.fromOffset(30, 30)
			chip.ZIndex = 3
			chip.Parent = card
			UIKit.corner(chip, UITheme.Radius.Pill)
			UIKit.stroke(chip, UITheme.Stroke.Thin)
			Icons.viewport(chip, hero.ClassId)
		end
		local count = hero.Count or 1
		if count > 1 then
			local amount = UIKit.text(card, `×{count}`, Typography.Size.Label)
			amount.AnchorPoint = Vector2.new(1, 1)
			amount.Position = UDim2.new(1, -Spacing.S, 0.66, -Spacing.XS)
			amount.Size = UDim2.fromOffset(48, 24)
			amount.TextXAlignment = Enum.TextXAlignment.Right
			amount.ZIndex = 3
		end
		if opts.OnSelect then
			local onSelect = opts.OnSelect
			local touch = Instance.new("TextButton")
			touch.BackgroundTransparency = 1
			touch.Text = ""
			touch.Size = UDim2.fromScale(1, 1)
			touch.ZIndex = 10
			touch.Parent = card
			touch.Activated:Connect(function()
				onSelect(index)
			end)
		end
		UIKit.popIn(card, 0.1 + math.min(index - 1, 12) * 0.05) -- cascade de 0,05 s par carte
	end
	UIKit.open(panel, veil)
end

return CollectionView
