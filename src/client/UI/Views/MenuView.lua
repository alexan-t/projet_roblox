--!strict
-- Menu de navigation (HUD, colonne à gauche) — voir docs/TUTORIAL_GUIDANCE.md, docs/UI_DESIGN_SYSTEM.md.
-- Présentation seulement : MenuController décide de ce qu'ouvre chaque bouton et des badges.
--   Un bouton « chunky » carré par entrée (face crème sur lèvre bois, contour Ink), une icône 3D maison
--   (UI/Icons : Boutique, Sac, Index, Guilde, Stats) qui déborde légèrement, le nom dessous en Fredoka.
--   États : normal ; survol (léger gonflement) ; enfoncé (la face descend sur sa lèvre) ; sélectionné
--   (face dorée, contour Selected : la fenêtre de ce bouton est ouverte) ; badge « ! » rouge royal qui
--   rebondit doucement (nouveau / à découvrir).
-- Chaque bouton est la cible de guidage « Menu.<Id> » (GuideTargets).
-- API : MenuView.Build(entries, onSelect) ; MenuView.SetSelected(id?) ; MenuView.SetBadge(id, visible).
--   entries = { { Id: string, Label: string, Icon: string } }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local GuideTargets = require(script.Parent.Parent.GuideTargets)
local Icons = require(script.Parent.Parent.Icons)
local UIKit = require(script.Parent.Parent.UIKit)

local Colors = UITheme.Colors
local Spacing = UITheme.Spacing
local Animation = UITheme.Animation

local SIZE = Spacing.MenuButton
local LABEL = 20 -- hauteur du nom sous le bouton
local LIP = UITheme.Shadow.ButtonLip
local BADGE = 26
local BADGE_EVERY = 2.2 -- s entre deux rebonds du badge

export type Entry = { Id: string, Label: string, Icon: string }

type ButtonUI = { holder: Frame, face: TextButton, gradient: UIGradient, stroke: UIStroke, scale: UIScale, badge: Frame, selected: boolean }

local MenuView = {}

local buttons: { [string]: ButtonUI } = {}
local screen: ScreenGui? = nil

local function paint(button: ButtonUI)
	local top, bottom = Colors.Cream, Colors.Sand
	if button.selected then
		top, bottom = Colors.GoldLight, Colors.GoldDeep
	end
	button.gradient.Color = ColorSequence.new(top, bottom)
	button.stroke.Color = if button.selected then Colors.Selected else UITheme.Stroke.Color
	button.stroke.Thickness = if button.selected then UITheme.Stroke.Thick else UITheme.Stroke.Regular
end

local function build(parent: Instance, entry: Entry, order: number, onSelect: (string) -> ()): ButtonUI
	local holder = Instance.new("Frame")
	holder.Name = entry.Id
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(SIZE, SIZE + LIP + LABEL)
	holder.LayoutOrder = order
	holder.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	local lip = Instance.new("Frame")
	lip.Name = "Levre"
	lip.BackgroundColor3 = Colors.WoodDark
	lip.Position = UDim2.fromOffset(0, LIP)
	lip.Size = UDim2.fromOffset(SIZE, SIZE)
	lip.Parent = holder
	UIKit.corner(lip, UITheme.Radius.Large)
	UIKit.stroke(lip, UITheme.Stroke.Regular)

	local face = Instance.new("TextButton")
	face.Name = "Bouton"
	face.AutoButtonColor = false
	face.Text = ""
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.Size = UDim2.fromOffset(SIZE, SIZE)
	face.Parent = holder
	UIKit.corner(face, UITheme.Radius.Large)
	local stroke = UIKit.stroke(face, UITheme.Stroke.Regular)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = face
	-- reflet clair en haut de la face (volume « jouet », pas de dégradé glossy)
	local shine = Instance.new("Frame")
	shine.Name = "Reflet"
	shine.BackgroundColor3 = Colors.TextLight
	shine.BackgroundTransparency = 0.55
	shine.Position = UDim2.fromOffset(Spacing.S, Spacing.XS + 1)
	shine.Size = UDim2.new(1, -2 * Spacing.S, 0, 8)
	shine.Parent = face
	UIKit.corner(shine, UITheme.Radius.Pill)

	local icon = Instance.new("Frame")
	icon.Name = "Icone"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0.5, -2)
	icon.Size = UDim2.fromOffset(SIZE + 8, SIZE + 8) -- déborde un peu du bouton (effet chunky)
	icon.ZIndex = 2
	icon.Parent = face
	Icons.viewport(icon, entry.Icon).ZIndex = 2

	local label = UIKit.text(holder, entry.Label, UITheme.Typography.Size.Label)
	label.Name = "Nom"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, 2)
	label.Size = UDim2.fromOffset(SIZE + 24, LABEL + 2)
	label.ZIndex = 3

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -6, 0, 6)
	badge.Size = UDim2.fromOffset(BADGE, BADGE)
	badge.BackgroundColor3 = Colors.RoyalRed
	badge.Visible = false
	badge.ZIndex = 4
	badge.Parent = holder
	UIKit.corner(badge, UITheme.Radius.Pill)
	UIKit.stroke(badge, UITheme.Stroke.Thin)
	local mark = UIKit.text(badge, "!", UITheme.Typography.Size.Label)
	mark.ZIndex = 5

	local ui: ButtonUI = { holder = holder, face = face, gradient = gradient, stroke = stroke, scale = scale, badge = badge, selected = false }
	paint(ui)
	face.MouseEnter:Connect(function()
		TweenService:Create(scale, Animation.Hover, { Scale = Animation.Scale.Hover }):Play()
	end)
	face.MouseLeave:Connect(function()
		TweenService:Create(scale, Animation.Hover, { Scale = 1 }):Play()
		TweenService:Create(face, Animation.Press, { Position = UDim2.fromOffset(0, 0) }):Play()
	end)
	face.MouseButton1Down:Connect(function()
		TweenService:Create(face, Animation.Press, { Position = UDim2.fromOffset(0, LIP) }):Play()
	end)
	face.MouseButton1Up:Connect(function()
		TweenService:Create(face, Animation.Press, { Position = UDim2.fromOffset(0, 0) }):Play()
	end)
	face.Activated:Connect(function()
		onSelect(entry.Id)
	end)
	GuideTargets.register(`Menu.{entry.Id}`, face)
	return ui
end

function MenuView.Build(entries: { Entry }, onSelect: (string) -> ())
	if screen then
		screen:Destroy()
	end
	table.clear(buttons)
	local s = UIKit.screen("MenuNavigation", 3)
	screen = s
	local column = Instance.new("Frame")
	column.Name = "Menu"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, Spacing.ScreenMargin + Spacing.S, 0.5, 40) -- sous le suivi de quête
	column.Size = UDim2.fromOffset(SIZE, #entries * (SIZE + LIP + LABEL + Spacing.S))
	column.Parent = s
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, Spacing.S)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = column
	for index, entry in entries do
		buttons[entry.Id] = build(column, entry, index, onSelect)
	end
	-- badges : petit rebond régulier (attire l'œil sans clignoter)
	task.spawn(function()
		while screen == s and s.Parent do
			task.wait(BADGE_EVERY)
			for _, button in buttons do
				if button.badge.Visible then
					UIKit.pop(button.badge)
				end
			end
		end
	end)
end

function MenuView.SetSelected(id: string?)
	for buttonId, button in buttons do
		local on = buttonId == id
		if button.selected ~= on then
			button.selected = on
			paint(button)
		end
	end
end

function MenuView.SetBadge(id: string, visible: boolean)
	local button = buttons[id]
	if button and button.badge.Visible ~= visible then
		button.badge.Visible = visible
		if visible then
			UIKit.popIn(button.badge, 0, 1.25)
		end
	end
end

return MenuView
