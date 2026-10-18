--!strict
-- Menu principal (HUD, à gauche, sous le suivi de quête) — voir docs/TUTORIAL_GUIDANCE.md § Menu.
-- Présentation seulement : MenuController décide de ce qu'ouvre chaque bouton, des badges et des
-- mises en avant. Les icônes sont les PNG du ZIP « Icones Menu », publiés tels quels
-- (Shared.Config.MenuIconConfig) : l'icône est l'élément principal, sans panneau derrière.
--   Grille de 2 colonnes (Boutique Sac / Index Guilde / Stats), nom en Fredoka sous chaque icône.
--   États :
--     survol     : léger gonflement (souris seulement, jamais seul indicateur) ;
--     enfoncé    : l'icône se tasse ;
--     sélectionné: pastille ronde bois sombre et contour doré sous l'icône (sa fenêtre est ouverte) ;
--     attention  : variante PNG avec « ! » (BadgeIcon), apparition en pop puis petit rebond espacé ;
--     mis en avant (tutoriel) : halo doré qui respire sous l'icône, l'icône gonfle doucement.
-- Chaque icône est la cible de guidage « Menu.<Id> » (GuideTargets) ; attribut GuideGlow = false : la
-- flèche UI ne dessine pas son cadre, le halo rond du menu le remplace.
-- Placement : MenuView.Fit(top, bottom) le place dans la bande libre (coordonnées absolues), le réduit si
-- elle est trop courte et l'agrandit un peu si elle est haute. Bande trop basse pour la grille (téléphone
-- en paysage) : les 5 icônes passent sur une seule ligne, plutôt que de devenir illisibles. Sa zone est la cible « Menu.Area »
-- (la sacoche s'ouvre juste à côté, la flèche UI se place à sa droite).
-- API : MenuView.Build(entries, onSelect) ; SetSelected(id?) ; SetAttention(id, on) ; SetHighlighted(id, on) ;
--   SetVisible(on) ; Fit(top, bottom) ; Width() (largeur à l'écran, px).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MenuIconConfig = require(ReplicatedStorage.Shared.Config.MenuIconConfig)
local UITheme = require(ReplicatedStorage.Shared.Config.UITheme)
local GuideTargets = require(script.Parent.Parent.GuideTargets)
local UIKit = require(script.Parent.Parent.UIKit)

local Colors = UITheme.Colors
local Spacing = UITheme.Spacing
local Animation = UITheme.Animation
local GUIDE = UITheme.World.Guide

local ICON = Spacing.MenuIcon
local LABEL = 20 -- hauteur du nom sous l'icône
local COLUMNS = 2
local GRID_MIN = 0.8 -- en dessous de cette réduction, la grille passe sur une seule ligne
local GAP = Spacing.S
local DISC = 0.86 -- diamètre de la pastille (sélection, halo) en part de l'icône
local ATTENTION_EVERY = 3 -- s entre deux petits rebonds d'une icône « attention »
local MIN_FIT = 0.55 -- réduction maximale quand la place manque
local MAX_FIT = 1.3 -- agrandissement maximal quand la bande est haute (petit écran de PC : icônes lisibles)

export type Entry = { Id: string, Label: string }

type ButtonUI = {
	id: string,
	holder: Frame,
	icon: ImageButton,
	press: UIScale,
	pulse: UIScale,
	disc: Frame,
	discStroke: UIStroke,
	selected: boolean,
	attention: boolean,
	highlighted: boolean,
}

local MenuView = {}

local buttons: { [string]: ButtonUI } = {}
local screen: ScreenGui? = nil
local column: Frame? = nil
local fit: UIScale? = nil
local grid: UIGridLayout? = nil
local count = 0
local pulseConnection: RBXScriptConnection? = nil

local function iconOf(id: string, attention: boolean): string
	local config = MenuIconConfig[id]
	if not config then
		return ""
	end
	-- pas de variante « ! » fournie : l'icône normale reste (on n'en invente pas)
	return if attention and config.BadgeIcon ~= "" then config.BadgeIcon else config.Icon
end

-- Pastille sous l'icône : bois sombre + contour doré (sélectionné), halo doré (mis en avant).
local function paint(button: ButtonUI)
	button.disc.Visible = button.selected or button.highlighted
	if button.highlighted then
		button.disc.BackgroundColor3 = GUIDE.Color
		button.discStroke.Color = GUIDE.Color
		button.discStroke.Thickness = UITheme.Stroke.Thick
	else
		button.disc.BackgroundColor3 = Colors.WoodDeep
		button.disc.BackgroundTransparency = UITheme.Transparency.HUD
		button.discStroke.Color = Colors.Selected
		button.discStroke.Thickness = UITheme.Stroke.Thick
		button.discStroke.Transparency = 0
	end
end

-- Respiration des boutons mis en avant : une seule connexion, coupée quand plus rien ne respire.
local function step()
	local any = false
	local wave = 0.5 + 0.5 * math.sin(os.clock() * 2 * math.pi / GUIDE.Period)
	for _, button in buttons do
		if button.highlighted then
			any = true
			button.disc.BackgroundTransparency = 0.75 - 0.3 * wave
			button.discStroke.Transparency = 0.5 * (1 - wave)
			button.pulse.Scale = 1 + (Animation.Scale.Highlight - 1) * wave
		end
	end
	if not any and pulseConnection then
		pulseConnection:Disconnect()
		pulseConnection = nil
	end
end

local function build(parent: Instance, entry: Entry, order: number, onSelect: (string) -> ()): ButtonUI
	local holder = Instance.new("Frame")
	holder.Name = entry.Id
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(ICON, ICON + LABEL)
	holder.LayoutOrder = order
	holder.Parent = parent
	local pulse = Instance.new("UIScale")
	pulse.Name = "Respiration"
	pulse.Parent = holder

	local disc = Instance.new("Frame")
	disc.Name = "Pastille"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromOffset(ICON / 2, ICON / 2)
	disc.Size = UDim2.fromOffset(ICON * DISC, ICON * DISC)
	disc.Visible = false
	disc.Parent = holder
	UIKit.corner(disc, UITheme.Radius.Pill)
	local discStroke = UIKit.stroke(disc, UITheme.Stroke.Thick, Colors.Selected)

	local icon = Instance.new("ImageButton")
	icon.Name = "Icone"
	icon.AutoButtonColor = false
	icon.BackgroundTransparency = 1
	icon.Image = iconOf(entry.Id, false)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(ICON, ICON)
	icon.ZIndex = 2
	icon:SetAttribute("GuideGlow", false)
	icon.Parent = holder
	local press = Instance.new("UIScale")
	press.Parent = icon

	local label = UIKit.text(holder, entry.Label, UITheme.Typography.Size.Label)
	label.Name = "Nom"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, 0)
	label.Size = UDim2.fromOffset(ICON + 2 * GAP, LABEL)
	label.ZIndex = 3

	local ui: ButtonUI = {
		id = entry.Id, holder = holder, icon = icon, press = press, pulse = pulse, disc = disc, discStroke = discStroke,
		selected = false, attention = false, highlighted = false,
	}
	icon.MouseEnter:Connect(function()
		TweenService:Create(press, Animation.Hover, { Scale = Animation.Scale.Hover }):Play()
	end)
	icon.MouseLeave:Connect(function()
		TweenService:Create(press, Animation.Hover, { Scale = 1 }):Play()
	end)
	icon.MouseButton1Down:Connect(function()
		TweenService:Create(press, Animation.Press, { Scale = Animation.Scale.Pressed }):Play()
	end)
	icon.MouseButton1Up:Connect(function()
		TweenService:Create(press, Animation.Hover, { Scale = 1 }):Play()
	end)
	icon.Activated:Connect(function()
		onSelect(entry.Id)
	end)
	GuideTargets.register(`Menu.{entry.Id}`, icon)
	return ui
end

-- Construit le menu (une seule fois : un nouvel appel remplace l'ancien écran et ses connexions).
function MenuView.Build(entries: { Entry }, onSelect: (string) -> ())
	if screen then
		screen:Destroy()
	end
	if pulseConnection then
		pulseConnection:Disconnect()
		pulseConnection = nil
	end
	table.clear(buttons)
	local s = UIKit.screen("MenuNavigation", 3)
	-- coordonnées sous la barre de Roblox, comme AbsolutePosition : Fit place le menu sans conversion
	s.IgnoreGuiInset = false
	screen = s
	count = #entries
	local frame = Instance.new("Frame")
	frame.Name = "Menu"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(Spacing.ScreenMargin, 0)
	frame.Parent = s
	column = frame
	GuideTargets.register("Menu.Area", frame)
	local scale = Instance.new("UIScale")
	scale.Name = "Ajustement"
	scale.Parent = frame
	fit = scale
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(ICON, ICON + LABEL)
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	grid = layout
	for index, entry in entries do
		buttons[entry.Id] = build(frame, entry, index, onSelect)
	end
	-- « attention » : petit rebond espacé (attire l'œil sans clignoter)
	task.spawn(function()
		while screen == s and s.Parent do
			task.wait(ATTENTION_EVERY)
			for _, button in buttons do
				if button.attention and not button.highlighted then
					UIKit.pop(button.icon)
				end
			end
		end
	end)
end

-- Taille (px, avant échelle) du menu sur `columns` colonnes.
local function sizeFor(columns: number): Vector2
	local rows = math.ceil(count / columns)
	return Vector2.new(columns * ICON + (columns - 1) * GAP, rows * (ICON + LABEL) + (rows - 1) * GAP)
end

-- Place le menu dans la bande verticale libre [top, bottom] (px, sous la barre de Roblox).
function MenuView.Fit(top: number, bottom: number)
	local s, frame, scale, layout = screen, column, fit, grid
	if not s or not frame or not scale or not layout then
		return
	end
	local base = s:FindFirstChildOfClass("UIScale")
	local screenScale = if base then base.Scale else 1
	local band = bottom - top
	local columns = COLUMNS
	if band / (sizeFor(COLUMNS).Y * screenScale) < GRID_MIN then
		columns = count -- une seule ligne
	end
	local size = sizeFor(columns)
	if layout.FillDirectionMaxCells ~= columns then
		layout.FillDirectionMaxCells = columns
	end
	if frame.Size.X.Offset ~= size.X or frame.Size.Y.Offset ~= size.Y then
		frame.Size = UDim2.fromOffset(size.X, size.Y)
	end
	local k = math.clamp(band / math.max(size.Y * screenScale, 1), MIN_FIT, MAX_FIT)
	if math.abs(scale.Scale - k) > 0.01 then
		scale.Scale = k
	end
	local y = top / screenScale
	if math.abs(frame.Position.Y.Offset - y) > 0.5 then
		frame.Position = UDim2.fromOffset(Spacing.ScreenMargin, y)
	end
end

-- Largeur du menu à l'écran (px), pour ouvrir la sacoche juste à côté.
function MenuView.Width(): number
	local frame = column
	return if frame then frame.AbsoluteSize.X else 0
end

function MenuView.SetVisible(on: boolean)
	local s = screen
	if s and s.Enabled ~= on then
		s.Enabled = on
	end
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

function MenuView.SetAttention(id: string, on: boolean)
	local button = buttons[id]
	if not button or button.attention == on then
		return
	end
	button.attention = on
	button.icon.Image = iconOf(id, on)
	if on then
		UIKit.popIn(button.icon, 0, Animation.Scale.Pop)
	end
end

function MenuView.SetHighlighted(id: string, on: boolean)
	local button = buttons[id]
	if not button or button.highlighted == on then
		return
	end
	button.highlighted = on
	if not on then
		button.pulse.Scale = 1
	end
	paint(button)
	if on and not pulseConnection then
		pulseConnection = RunService.RenderStepped:Connect(step)
	end
end

function MenuView.IsHighlighted(id: string): boolean
	local button = buttons[id]
	return button ~= nil and button.highlighted
end

return MenuView
